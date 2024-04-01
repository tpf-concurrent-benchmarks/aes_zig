const std = @import("std");
const AESBlockCipher = @import("aes_block_cipher.zig").AESBlockCipher;

const ChunkReader = @import("chunk_reader.zig").ChunkReader;
const ChunkWriter = @import("chunk_writer.zig").ChunkWriter;
const ParallelMap = @import("pmap.zig").ParallelMap;
const c = @import("constants.zig");

const N_B = c.N_B;
const SLICES = 32;
const BLOCKS_PER_SLICE = 32;
const BUFFER_SIZE = SLICES * BLOCKS_PER_SLICE;

fn cipher_blocks(ctx: AESBlockCipher, blocks: [BLOCKS_PER_SLICE]Block) [BLOCKS_PER_SLICE]Block {
    var result: [BLOCKS_PER_SLICE]Block = undefined;

    for (blocks, 0..) |block, i| {
        result[i] = ctx.cipher_block(block);
    }
    return result;
}

fn inv_cipher_blocks(ctx: AESBlockCipher, blocks: [BLOCKS_PER_SLICE]Block) [BLOCKS_PER_SLICE]Block {
    var result: [BLOCKS_PER_SLICE]Block = undefined;

    for (blocks, 0..) |block, i| {
        result[i] = ctx.inv_cipher_block(block);
    }
    return result;
}

const Block = [4 * c.N_B]u8;

pub const AESCipher = struct {
    buffer: [][16]u8,
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,
    pmap_encrypt: ParallelMap([BLOCKS_PER_SLICE]Block, [BLOCKS_PER_SLICE]Block, AESBlockCipher, cipher_blocks),
    pmap_decrypt: ParallelMap([BLOCKS_PER_SLICE]Block, [BLOCKS_PER_SLICE]Block, AESBlockCipher, inv_cipher_blocks),

    const Self = @This();

    pub fn init(cipher_key: u128, n_threads: usize, allocator: std.mem.Allocator) !Self {
        var arena = std.heap.ArenaAllocator.init(allocator);
        const aes_cipher = AESBlockCipher.new_u128(cipher_key);
        var arena_allocator = arena.allocator();
        const buffer = arena_allocator.alloc(Block, BUFFER_SIZE) catch return error.OutOfMemory;
        return Self{
            .buffer = buffer,
            .arena = arena,
            .allocator = arena_allocator,
            .pmap_encrypt = try ParallelMap([BLOCKS_PER_SLICE]Block, [BLOCKS_PER_SLICE]Block, AESBlockCipher, cipher_blocks).init(n_threads, aes_cipher, allocator),
            .pmap_decrypt = try ParallelMap([BLOCKS_PER_SLICE]Block, [BLOCKS_PER_SLICE]Block, AESBlockCipher, inv_cipher_blocks).init(n_threads, aes_cipher, allocator),
        };
    }

    pub fn destroy(self: *Self) !void {
        self.arena.deinit();
        try self.pmap_encrypt.destroy();
        try self.pmap_decrypt.destroy();
    }

    inline fn get_slices_filled(chunks_filled: usize) usize {
        return if (chunks_filled % BLOCKS_PER_SLICE == 0) chunks_filled / BLOCKS_PER_SLICE else chunks_filled / BLOCKS_PER_SLICE + 1;
    }

    inline fn get_blocks_filled_last_slice(chunks_filled: usize) usize {
        return if (chunks_filled % BLOCKS_PER_SLICE == 0) BLOCKS_PER_SLICE else chunks_filled % BLOCKS_PER_SLICE;
    }

    fn fill_blocks(self: Self, blocks: *[SLICES][BLOCKS_PER_SLICE]Block, slices_filled: usize, blocks_filled_last_slice: usize) void {
        for (0..slices_filled - 1) |i| {
            for (0..BLOCKS_PER_SLICE) |j| {
                blocks[i][j] = self.buffer[i * BLOCKS_PER_SLICE + j];
            }
        }

        for (0..blocks_filled_last_slice) |j| {
            blocks[slices_filled - 1][j] = self.buffer[(slices_filled - 1) * BLOCKS_PER_SLICE + j];
        }

        // If the last chunk is not full, fill it with the last block
        if (blocks_filled_last_slice < BLOCKS_PER_SLICE) {
            const last_block = blocks[slices_filled - 1][blocks_filled_last_slice - 1];
            for (blocks_filled_last_slice..BLOCKS_PER_SLICE) |i| {
                blocks[slices_filled - 1][i] = last_block;
            }
        }
    }

    fn write_slices(comptime T: type, chunk_writer: *ChunkWriter(T), slices: [][BLOCKS_PER_SLICE]Block, slices_filled: usize, blocks_filled_last_slice: usize) !void {
        for (slices[0 .. slices_filled - 1]) |slice| {
            try chunk_writer.write_chunks(slice[0..BLOCKS_PER_SLICE]);
        }

        try chunk_writer.write_chunks(slices[slices_filled - 1][0..blocks_filled_last_slice]);
    }

    pub fn cipher(self: *Self, input: anytype, output: anytype) !void {
        var chunk_reader = ChunkReader(@TypeOf(input)).init(true, input);
        var chunk_writer = ChunkWriter(@TypeOf(output)).init(false, output);
        var input_blocks: [SLICES][BLOCKS_PER_SLICE]Block = undefined;
        var results: [SLICES][BLOCKS_PER_SLICE]Block = undefined;

        while (true) {
            const chunks_filled = try chunk_reader.read_chunks(BUFFER_SIZE, self.buffer);
            if (chunks_filled == 0) {
                break;
            }

            const slices_filled = Self.get_slices_filled(chunks_filled);
            const blocks_filled_last_slice = Self.get_blocks_filled_last_slice(chunks_filled);

            self.fill_blocks(&input_blocks, slices_filled, blocks_filled_last_slice);

            try self.pmap_encrypt.map(input_blocks[0..slices_filled], results[0..]);
            try Self.write_slices(@TypeOf(output), &chunk_writer, results[0..slices_filled], slices_filled, blocks_filled_last_slice);
        }
        return chunk_writer.flush();
    }

    pub fn decipher(self: *Self, input: anytype, output: anytype) !void {
        var chunk_reader = ChunkReader(@TypeOf(input)).init(false, input);
        var chunk_writer = ChunkWriter(@TypeOf(output)).init(true, output);
        var output_blocks: [SLICES][BLOCKS_PER_SLICE]Block = undefined;
        var results: [SLICES][BLOCKS_PER_SLICE]Block = undefined;

        while (true) {
            const chunks_filled = try chunk_reader.read_chunks(BUFFER_SIZE, self.buffer);
            if (chunks_filled == 0) {
                break;
            }

            const slices_filled = Self.get_slices_filled(chunks_filled);
            const blocks_filled_last_slice = Self.get_blocks_filled_last_slice(chunks_filled);

            self.fill_blocks(&output_blocks, slices_filled, blocks_filled_last_slice);

            try self.pmap_decrypt.map(output_blocks[0..slices_filled], results[0..]);

            try Self.write_slices(@TypeOf(output), &chunk_writer, results[0..slices_filled], slices_filled, blocks_filled_last_slice);
        }
        return chunk_writer.flush();
    }

    pub fn cipher_file(self: *Self, input_path: []const u8, output_path: []const u8) !void {
        const input_file = try std.fs.cwd().openFile(input_path, .{});
        defer input_file.close();

        const output_file = try std.fs.cwd().createFile(output_path, .{});
        defer output_file.close();

        return self.cipher(input_file.reader(), output_file.writer());
    }

    pub fn decipher_file(self: *Self, input_path: []const u8, output_path: []const u8) !void {
        const input_file = try std.fs.cwd().openFile(input_path, .{});
        defer input_file.close();

        const output_file = try std.fs.cwd().createFile(output_path, .{});
        defer output_file.close();

        return self.decipher(input_file.reader(), output_file.writer());
    }
};
