const std = @import("std");
const matrix = @import("matrix.zig");
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

const initiate_worker = @import("components/worker.zig").initiate_worker;
const initiate_sink = @import("components/sink.zig").initiate_sink;
const initiate_source = @import("components/source.zig").initiate_source;

const BUFFER_SIZE = 1000000;

pub fn main() !void {
    const workers_num = 4;
    var input_queue = Queue(Message).init(5, std.heap.page_allocator);
    var result_queue = Queue(Message).init(5, std.heap.page_allocator);

    for (0..workers_num) |_| {
        _ = try initiate_worker(&input_queue, &result_queue);
    }

    _ = try initiate_sink(&result_queue);

    try initiate_source(&input_queue);
}

test {
    _ = @import("matrix.zig");
}
