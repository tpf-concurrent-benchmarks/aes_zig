const std = @import("std");
const Config = @import("config.zig").Config;
const AESCipher = @import("aes_cipher.zig").AESCipher;

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const config = try Config.init_from_env(allocator);
    defer config.deinit();

    var cipher = try AESCipher.init(0x2b7e151628aed2a6abf7158809cf4f3c, config.n_threads, allocator);
    defer cipher.destroy() catch @panic("Failed to destroy cipher");

    for (0..config.repeat) |i| {
        std.debug.print("Iteration {}\n", .{i + 1});

        try do_iteration(&cipher, config);
    }
}

fn do_iteration(cipher: *AESCipher, config: Config) !void {
    if (config.input_file != null and config.encrypted_file != null) {
        try cipher.cipher_file(config.input_file.?, config.encrypted_file.?);
    }
    if (config.encrypted_file != null and config.decrypted_file != null) {
        try cipher.decipher_file(config.encrypted_file.?, config.decrypted_file.?);
    }
}

test {
    _ = @import("block_cipher/aes_block_cipher.zig");
    _ = @import("utils/chunk_reader.zig");
    _ = @import("utils/chunk_writer.zig");
}
