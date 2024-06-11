const std = @import("std");
const Config = @import("config.zig").Config;
const AESCipher = @import("aes_cipher.zig").AESCipher;
const StatsDClient = @import("statsd_client.zig").StatsDClient;

const Allocator = std.mem.Allocator;

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const config = try Config.init_from_env(allocator);
    defer config.deinit();
    const statsd_client = try StatsDClient.init(.{ .host = config.graphite_host, .port = config.graphite_port, .prefix = config.metrics_prefix, .allocator = allocator });
    defer statsd_client.deinit();

    const start_time = std.time.milliTimestamp();

    var cipher = try AESCipher.init(0x2b7e151628aed2a6abf7158809cf4f3c, config.n_threads, allocator);
    defer cipher.destroy() catch @panic("Failed to destroy cipher");

    for (0..config.repeat) |i| {
        std.debug.print("Iteration {}\n", .{i + 1});

        try do_iteration(&cipher, config);
    }
    const end_time = std.time.milliTimestamp();
    const completion_time = @as(f64, @floatFromInt(end_time - start_time)) / 1000;
    std.debug.print("Elapsed time: {}s\n", .{completion_time});
    try statsd_client.gauge("completion_time", completion_time);
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
