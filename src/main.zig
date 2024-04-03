const std = @import("std");
const AESCipher = @import("aes_cipher.zig").AESCipher;

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    var cipher = try AESCipher.init(0x2b7e151628aed2a6abf7158809cf4f3c, 4, allocator);
    defer cipher.destroy() catch @panic("Failed to destroy cipher");

    try cipher.cipher_file("data/input.txt", "data/output.txt");

    try cipher.decipher_file("data/output.txt", "data/deciphered.txt");
}

test {
    _ = @import("matrix.zig");
}
