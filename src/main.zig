const std = @import("std");
const matrix = @import("matrix.zig");
const AESBlockCipher = @import("aes_block_cipher.zig").AESBlockCipher;
const AESCipher = @import("aes_cipher.zig").AESCipher;
const Queue = @import("components/queue.zig").Queue;
const Message = @import("components/message.zig").Message;
const c = @import("constants.zig");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;
const warn = std.debug.warn;
const Order = std.math.Order;
const testing = std.testing;
const expect = testing.expect;
const expectEqual = testing.expectEqual;
const expectError = testing.expectError;
const ChunkReader = @import("chunk_reader.zig").ChunkReader;
const ChunkWriter = @import("chunk_writer.zig").ChunkWriter;

const ParallelMap = @import("pmap.zig").ParallelMap;

const BUFFER_SIZE = 20000000;
const Block = [4 * c.N_B]u8;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var cipher = try AESCipher.init(0x123456789, 4, allocator);

    try cipher.cipher_file("data/lorem_ipsum_4.txt", "data/output.txt");

    try cipher.decipher_file("data/output.txt", "data/deciphered.txt");
}

test {
    _ = @import("matrix.zig");
}
