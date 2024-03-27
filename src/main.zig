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
const EOF = @import("components/message.zig").EOF;

const initiate_worker = @import("components/worker.zig").initiate_worker;
const initiate_sink = @import("components/sink.zig").initiate_sink;
const initiate_source = @import("components/source.zig").initiate_source;

const BUFFER_SIZE = 1000000;

fn cleanup(input_queue: *Queue(Message), worker_threads: []std.Thread, result_queue: *Queue(Message), sink_thread: std.Thread) !void {
    for (worker_threads) |_| {
        try input_queue.push(EOF);
    }
    for (worker_threads) |worker_thread| {
        std.Thread.join(worker_thread);
    }

    try result_queue.push(EOF);
    std.Thread.join(sink_thread);
}

pub fn main() !void {
    const workers_num = 4;
    var input_queue = Queue(Message).init(5, std.heap.page_allocator);
    var result_queue = Queue(Message).init(5, std.heap.page_allocator);

    var worker_threads: [workers_num]std.Thread = undefined;

    for (0..workers_num) |i| {
        const thread = try initiate_worker(&input_queue, &result_queue);
        worker_threads[i] = thread;
    }

    const sink_thread = try initiate_sink(&result_queue);

    try initiate_source(&input_queue);

    try cleanup(&input_queue, &worker_threads, &result_queue, sink_thread);
}

test {
    _ = @import("matrix.zig");
}
