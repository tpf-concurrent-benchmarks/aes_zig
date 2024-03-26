const std = @import("std");
const aes_block_cipher = @import("aes_block_cipher.zig");

const cr = @import("chunk_reader.zig");
const cw = @import("chunk_writer.zig");
const constants = @import("constants.zig");

const N_B = constants.N_B;
const BUFFER_SIZE = 1000000;

pub const AESCipher = struct {
    block_cipher: aes_block_cipher.AESBlockCipher,
    buffer: [][16]u8,
    arena: std.heap.ArenaAllocator,
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(cipher_key: u128, allocator: std.mem.Allocator) !Self {
        var block_cipher = aes_block_cipher.AESBlockCipher.new_u128(cipher_key);
        var arena = std.heap.ArenaAllocator.init(allocator);
        var arena_allocator = arena.allocator();
        const buffer = arena_allocator.alloc([4 * N_B]u8, BUFFER_SIZE) catch return error.OutOfMemory;
        return Self{
            .block_cipher = block_cipher,
            .buffer = buffer,
            .arena = arena,
            .allocator = arena_allocator,
        };
    }

    pub fn deinit(self: *Self) void {
        self.arena.deinit();
    }

    fn cipher_blocks(self: *Self, comptime max_chunks: usize, chunks: []const [4 * N_B]u8) ![][4 * N_B]u8 {
        var result: [max_chunks][4 * N_B]u8 = undefined;

        for (chunks, 0..) |chunk, i| {
            const ciphered_block = self.block_cipher.cipher_block(&chunk);
            result[i] = ciphered_block;
        }

        return result[0..chunks.len];
    }

    fn decipher_blocks(self: *Self, comptime max_chunks: usize, chunks: []const [4 * N_B]u8) ![][4 * N_B]u8 {
        var result: [max_chunks][4 * N_B]u8 = undefined;

        for (chunks, 0..) |chunk, i| {
            const deciphered_block = self.block_cipher.inv_cipher_block(&chunk);
            result[i] = deciphered_block;
        }

        return result[0..chunks.len];
    }

    pub fn file_cipher(self: *Self, input: anytype, output: anytype) !void {
        var buffered_reader = std.io.bufferedReader(input);

        var br = buffered_reader.reader();

        var chunk_reader = cr.ChunkReader.init(true);
        var chunk_writer = cw.ChunkWriter.init(false);

        while (true) {
            const chunks_filled = try chunk_reader.read_chunks(br, BUFFER_SIZE, self.buffer);
            if (chunks_filled == 0) {
                break;
            }
            var ciphered_chunks = try self.cipher_blocks(BUFFER_SIZE, self.buffer[0..chunks_filled]);

            try chunk_writer.write_chunks(output, ciphered_chunks[0..chunks_filled]);
        }
    }

    pub fn cipher(self: *Self, input_filename: []const u8, output_filename: []const u8) !void {
        const input_file = try std.fs.cwd().openFile(input_filename, .{});
        defer input_file.close();

        const output_file = try std.fs.cwd().createFile(output_filename, .{});
        defer output_file.close();

        try self.file_cipher(input_file.reader(), output_file.writer());
    }

    pub fn file_decipher(self: *Self, input: anytype, output: anytype) !void {
        var buffered_reader = std.io.bufferedReader(input);

        var br = buffered_reader.reader();

        var chunk_reader = cr.ChunkReader.init(false);
        var chunk_writer = cw.ChunkWriter.init(true);

        while (true) {
            const chunks_filled = try chunk_reader.read_chunks(br, BUFFER_SIZE, self.buffer);
            if (chunks_filled == 0) {
                break;
            }
            var deciphered_chunks = try self.decipher_blocks(BUFFER_SIZE, self.buffer[0..chunks_filled]);

            try chunk_writer.write_chunks(output, deciphered_chunks[0..chunks_filled]);
        }
    }

    pub fn decipher(self: *Self, input_filename: []const u8, output_filename: []const u8) !void {
        const input_file = try std.fs.cwd().openFile(input_filename, .{});
        defer input_file.close();

        const output_file = try std.fs.cwd().createFile(output_filename, .{});
        defer output_file.close();

        try self.file_decipher(input_file.reader(), output_file.writer());
    }
};
