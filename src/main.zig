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
const Worker = @import("components/worker.zig").Worker;
const handle_message = @import("components/worker.zig").handle_message;
const Sink = @import("components/sink.zig").Sink;
const initiate_sink = @import("components/sink.zig").initiate_sink;
const Source = @import("components/source.zig").Source;

const BUFFER_SIZE = 1000000;
const Block = [4 * c.N_B]u8;

fn cleanup(comptime T: type, input_queue: *Queue(Message(T)), worker_threads: []std.Thread, result_queue: *Queue(Message(T)), sink_thread: std.Thread) !void {
    for (worker_threads) |_| {
        try input_queue.push(Message(T).init_eof());
    }
    for (worker_threads) |worker_thread| {
        std.Thread.join(worker_thread);
    }

    try result_queue.push(Message(T).init_eof());
    std.Thread.join(sink_thread);
}

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    const workers_num = 4;
    var input_queue = Queue(Message(Block)).init(5, allocator);
    var result_queue = Queue(Message(Block)).init(5, allocator);

    var worker_threads: [workers_num]std.Thread = undefined;

    for (0..workers_num) |i| {
        var worker = Worker(Block, Block).init(&input_queue, &result_queue, handle_message);
        const thread = try initiate_worker(Block, Block, &worker);
        worker_threads[i] = thread;
    }

    var sink = try Sink(Block).init(&result_queue, BUFFER_SIZE, allocator);
    const sink_thread = try initiate_sink(Block, &sink, true, "data/output.txt");

    var source = Source(Block).init(&input_queue, BUFFER_SIZE, allocator);
    try source.run_from_file(true, "data/input.txt");

    try cleanup(Block, &input_queue, &worker_threads, &result_queue, sink_thread);
}

test {
    _ = @import("matrix.zig");
}
