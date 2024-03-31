const std = @import("std");
const matrix = @import("matrix.zig");
const AESBlockCipher = @import("aes_block_cipher.zig").AESBlockCipher;
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

fn encrypt_file() !void {
    var gpa_1 = std.heap.GeneralPurposeAllocator(.{}){};
    var gpa_2 = std.heap.GeneralPurposeAllocator(.{.thread_safe=false}){};
    var gpa_3 = std.heap.GeneralPurposeAllocator(.{.thread_safe=false}){};

    const allocator_1 = gpa_1.allocator();
    const allocator_2 = gpa_2.allocator();
    const allocator_3 = gpa_3.allocator();

    const workers_num = 4;
    var input_queue = Queue(Message(Block)).init(50, allocator_1);
    var result_queue = Queue(Message(Block)).init(50, allocator_1);

    var worker_threads: [workers_num]std.Thread = undefined;

    for (0..workers_num) |i| {
        var worker = Worker(Block, Block).init(&input_queue, &result_queue, true);
        const thread = try initiate_worker(Block, Block, &worker);
        worker_threads[i] = thread;
    }

    var sink = try Sink(Block).init(&result_queue, BUFFER_SIZE, allocator_2);
    const sink_thread = try initiate_sink(Block, &sink, false, "data/output.txt");

    var source = Source(Block).init(&input_queue, BUFFER_SIZE, allocator_3);
    try source.run_from_file(true, "data/lorem_ipsum_4.txt");

    try cleanup(Block, &input_queue, &worker_threads, &result_queue, sink_thread);
}

fn decrypt_file() !void {
    var gpa_1 = std.heap.GeneralPurposeAllocator(.{}){};
    var gpa_2 = std.heap.GeneralPurposeAllocator(.{.thread_safe=false}){};
    var gpa_3 = std.heap.GeneralPurposeAllocator(.{.thread_safe=false}){};

    const allocator_1 = gpa_1.allocator();
    const allocator_2 = gpa_2.allocator();
    const allocator_3 = gpa_3.allocator();

    const workers_num = 4;
    var input_queue = Queue(Message(Block)).init(50, allocator_1);
    var result_queue = Queue(Message(Block)).init(50, allocator_1);

    var worker_threads: [workers_num]std.Thread = undefined;

    for (0..workers_num) |i| {
        var worker = Worker(Block, Block).init(&input_queue, &result_queue, false);
        const thread = try initiate_worker(Block, Block, &worker);
        worker_threads[i] = thread;
    }

    var sink = try Sink(Block).init(&result_queue, BUFFER_SIZE, allocator_2);
    const sink_thread = try initiate_sink(Block, &sink, true, "data/decrypted.txt");

    var source = Source(Block).init(&input_queue, BUFFER_SIZE, allocator_3);
    try source.run_from_file(false, "data/output.txt");

    try cleanup(Block, &input_queue, &worker_threads, &result_queue, sink_thread);
}

pub fn main() !void {
    try encrypt_file();
    try decrypt_file();
    std.debug.print("Done\n", .{});
}

test {
    _ = @import("matrix.zig");
}
