const std = @import("std");
const matrix = @import("matrix.zig");
const AESCipher = @import("aes_cipher.zig").AESCipher;

pub fn main() !void {
    const input = "data/input.txt";
    const ciphered = "data/ciphered.txt";
    const deciphered = "data/deciphered.txt";

    const key: u128 = 0x123456789;

    var cipher = try AESCipher.init(key, std.heap.page_allocator);
    defer cipher.deinit();

    try cipher.cipher(input, ciphered);
    try cipher.decipher(ciphered, deciphered);
}

test {
    _ = @import("matrix.zig");
}
