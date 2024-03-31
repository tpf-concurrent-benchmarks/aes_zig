const std = @import("std");
const AESBlockCipher = @import("aes_block_cipher.zig").AESBlockCipher;

const ChunkReader = @import("chunk_reader.zig").ChunkReader;
const ChunkWriter = @import("chunk_writer.zig").ChunkWriter;
const ParallelMap = @import("pmap.zig").ParallelMap;
const c = @import("constants.zig");

const N_B = c.N_B;
const BUFFER_SIZE = 32;

const Block = [4 * c.N_B]u8;

pub const AESCipher = struct {
	block_cipher: AESBlockCipher,
	buffer: [][16]u8,
	arena: std.heap.ArenaAllocator,
	allocator: std.mem.Allocator,
	pmap_encrypt: ParallelMap(Block, Block, AESBlockCipher, AESBlockCipher.cipher_block),
	pmap_decrypt: ParallelMap(Block, Block, AESBlockCipher, AESBlockCipher.inv_cipher_block),


	const Self = @This();

	pub fn init(cipher_key: u128, n_threads: usize, allocator: std.mem.Allocator) !Self {
		var block_cipher = AESBlockCipher.new_u128(cipher_key);
		var arena = std.heap.ArenaAllocator.init(allocator);
		var arena_allocator = arena.allocator();
		const buffer = arena_allocator.alloc([4 * N_B]u8, BUFFER_SIZE) catch return error.OutOfMemory;
		return Self{
		.block_cipher = block_cipher,
		.buffer = buffer,
		.arena = arena,
		.allocator = arena_allocator,
		.pmap_encrypt = try ParallelMap(Block, Block, AESBlockCipher, AESBlockCipher.cipher_block).init(n_threads, block_cipher, allocator),
		.pmap_decrypt = try ParallelMap(Block, Block, AESBlockCipher, AESBlockCipher.inv_cipher_block).init(n_threads, block_cipher, allocator),
		};
	}

	pub fn deinit(self: *Self) void {
		self.arena.deinit();
		self.pmap_encrypt.deinit();
		self.pmap_decrypt.deinit();
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

	pub fn cipher(self: *Self, input: anytype, output: anytype) !void {
		var chunk_reader = ChunkReader(@TypeOf(input)).init(true, input);
		var chunk_writer = ChunkWriter(@TypeOf(output)).init(false, output);

		while (true) {
			const chunks_filled = try chunk_reader.read_chunks(BUFFER_SIZE, self.buffer);
			if (chunks_filled == 0) {
				break;
			}
			// var ciphered_chunks = try self.cipher_blocks(BUFFER_SIZE, self.buffer[0..chunks_filled]);
			var ciphered_chunks = try self.pmap_encrypt.map(BUFFER_SIZE, self.buffer);

			try chunk_writer.write_chunks(ciphered_chunks[0..chunks_filled]);
		}
		return chunk_writer.deinit();
	}

	pub fn decipher(self: *Self, input: anytype, output: anytype) !void {
		var chunk_reader = ChunkReader(@TypeOf(input)).init(false, input);
		var chunk_writer = ChunkWriter(@TypeOf(output)).init(true, output);

		while (true) {
			const chunks_filled = try chunk_reader.read_chunks(BUFFER_SIZE, self.buffer);
			if (chunks_filled == 0) {
				break;
			}

			// var deciphered_chunks = try self.decipher_blocks(BUFFER_SIZE, self.buffer[0..chunks_filled]);
			var deciphered_chunks = try self.pmap_decrypt.map(BUFFER_SIZE, self.buffer);

			try chunk_writer.write_chunks(deciphered_chunks[0..chunks_filled]);
		}
		return chunk_writer.deinit();
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
