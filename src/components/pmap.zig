pub const std = @import("std");
pub const Thread = std.Thread;
pub const Queue = @import("queue.zig").Queue;
pub const Message = @import("message.zig").Message;
pub const initiate_worker = @import("worker.zig").initiate_worker;
pub const Worker = @import("worker.zig").Worker;
pub const MinHeap = @import("min_heap.zig").MinHeap;

pub const c = @import("../constants.zig");

pub fn ParallelMap(comptime R: type, comptime S: type, comptime T: type, comptime f: *const fn (T, R) S) type {
    return struct {
        pub const Self = @This();
        pub const MessageInput = Message(R);
        pub const MessageOutput = Message(S);

        threads: []Thread,
        workers: []Worker(R, S, T),
        input_queue: *Queue(Message(R)),
        output_queue: *Queue(Message(S)),
        allocator: std.mem.Allocator,

        heap: MinHeap(Message(S)),

        pub fn init(n_threads: usize, ctx: T, allocator: std.mem.Allocator) !Self {
            var threads = try allocator.alloc(Thread, n_threads);
            var workers = try allocator.alloc(Worker(R, S, T), n_threads);

            var input_queue = try allocator.create(Queue(Message(R)));
            var output_queue = try allocator.create(Queue(Message(S)));

            input_queue.init_ptr(50, allocator);
            output_queue.init_ptr(50, allocator);

            for (0..n_threads) |i| {
                workers[i] = Worker(R, S, T).init(input_queue, output_queue, ctx, f);
                threads[i] = try initiate_worker(R, S, T, &workers[i]);
            }

            return Self{
                .threads = threads,
                .workers = workers,
                .input_queue = input_queue,
                .output_queue = output_queue,
                .allocator = allocator,
                .heap = try MinHeap(Message(S)).init(c.MAX_HEAP_SIZE, MessageOutput.order, allocator),
            };
        }

        pub fn destroy(self: *Self) !void {
            for (0..self.threads.len) |_| {
                try self.input_queue.push(MessageInput.init_eof());
            }
            for (self.threads) |thread| {
                thread.join();
            }
            self.input_queue.destroy();
            self.output_queue.destroy();
            self.allocator.destroy(self.input_queue);
            self.allocator.destroy(self.output_queue);
            self.allocator.free(self.threads);
            self.allocator.free(self.workers);
        }

        fn send_messages(self: *Self, input: []const R) !void {
            var next_pos: u64 = 0;
            for (input) |item| {
                const message = MessageInput.init(item, next_pos);
                next_pos += 1;
                try self.input_queue.push(message);
            }
        }

        fn receive_results(self: *Self, expected_results: usize, results: []S) !void {
            var next_item: u64 = 0;

            while (true) {
                const message = self.output_queue.pop();
                if (message.is_eof()) {
                    break;
                }

                if (message.pos > next_item) {
                    self.heap.push(message);
                    continue;
                }

                if (message.pos < next_item) {
                    @panic("Received block out of order");
                }

                results[next_item] = message.data;
                next_item += 1;

                while (self.heap.len() > 0 and self.heap.peek().pos == next_item) {
                    const message_i = self.heap.pop();
                    results[next_item] = message_i.data;
                    next_item += 1;
                }
                if (next_item == expected_results) {
                    break;
                }
            }
        }

        pub fn map(self: *Self, input: []const R, results: []S) !void {
            try self.send_messages(input);
            try self.receive_results(input.len, results);
        }
    };
}

pub fn parallelMap(comptime R: type, comptime T: type, comptime f: *const fn (T, R) R) @TypeOf(ParallelMap(R, R, T, f)) {
    return ParallelMap(R, R, T, f);
}