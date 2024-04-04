pub const std = @import("std");
pub const Thread = std.Thread;
pub const Queue = @import("queue.zig").Queue;
pub const Message = @import("message.zig").Message;
pub const EmptyMessage = @import("message.zig").EmptyMessage;
pub const DataWithFn = @import("message.zig").DataWithFn;
pub const initiate_worker = @import("worker.zig").initiate_worker;
pub const Worker = @import("worker.zig").Worker;
pub const MinHeap = @import("min_heap.zig").MinHeap;

pub const c = @import("../constants.zig");

pub fn ParallelMap(comptime R: type, comptime S: type, comptime Ctx: type) type {
    return struct {
        pub const Self = @This();
        const Data = DataWithFn(Ctx, R, S);
        pub const MessageInput = Message(Data);
        pub const MessageOutput = EmptyMessage;

        threads: []Thread,
        workers: []Worker(R, S, Ctx),
        input_queue: *Queue(MessageInput),
        output_queue: *Queue(MessageOutput),
        allocator: std.mem.Allocator,
        batch_size: usize,

        heap: MinHeap(MessageOutput),

        pub fn init(n_threads: usize, batch_size: usize, allocator: std.mem.Allocator) !Self {
            var threads = try allocator.alloc(Thread, n_threads);
            var workers = try allocator.alloc(Worker(R, S, Ctx), n_threads);

            var input_queue = try allocator.create(Queue(MessageInput));
            var output_queue = try allocator.create(Queue(MessageOutput));

            input_queue.init_ptr(50, allocator);
            output_queue.init_ptr(50, allocator);

            for (0..n_threads) |i| {
                workers[i] = Worker(R, S, Ctx).init(input_queue, output_queue);
                threads[i] = try initiate_worker(R, S, Ctx, &workers[i]);
            }

            return Self{
                .threads = threads,
                .workers = workers,
                .input_queue = input_queue,
                .output_queue = output_queue,
                .allocator = allocator,
                .batch_size = batch_size,
                .heap = try MinHeap(MessageOutput).init(c.MAX_HEAP_SIZE, MessageOutput.order, allocator),
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

        /// Returns the amount of created batches
        fn send_messages(self: *Self, ctx: *const Ctx, func: *const fn(*const Ctx, R) S, input: []const R, results: []S) !usize {
            var next_pos: u64 = 0;
            var input_pos: usize = 0;

            while (true) {
                const actual_batch_size = @min(self.batch_size, input.len - input_pos);
                const input_slice = input[input_pos..input_pos+actual_batch_size];
                const results_slice = results[input_pos..input_pos+actual_batch_size];
                const message = MessageInput.init(Data.init(input_slice, func, ctx, results_slice), next_pos);
                input_pos += actual_batch_size;
                next_pos += 1;
                try self.input_queue.push(message);
                if (input_pos >= input.len) {
                    break;
                }
            }
            return next_pos;
        }

        fn send_messages_stateless(self: *Self, func: *const fn(R) S, input: []const R, results: []S) !void {
            var next_pos: u64 = 0;
            var input_pos: usize = 0;

            while (true) {
                const actual_batch_size = @min(self.batch_size, input.len - input_pos);
                const input_slice = input[input_pos..input_pos+actual_batch_size];
                const results_slice = results[input_pos..input_pos+actual_batch_size];
                const message = MessageInput.init(Data.init_stateless(input_slice, func, results_slice), next_pos);
                input_pos += actual_batch_size;
                next_pos += 1;
                try self.input_queue.push(message);
                if (input_pos >= input.len) {
                    break;
                }
            }
        }

        fn receive_results(self: *Self, expected_batches: usize, results: []S) !void {
            std.debug.assert(results.len >= expected_batches);

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

                next_item += 1;

                while (self.heap.len() > 0 and self.heap.peek().pos == next_item) {
                    _ = self.heap.pop();
                    next_item += 1;
                }
                if (next_item == expected_batches) {
                    break;
                }
            }
        }

        pub fn map(self: *Self, ctx: *const Ctx, func: *const fn(*const Ctx, R) S, input: []const R, results: []S) !void {
            std.debug.assert(results.len >= input.len);

            const n_batches = try self.send_messages(ctx, func, input, results);
            try self.receive_results(n_batches, results);
        }

        /// Allocates the results array
        /// Invoker owns the array, and must free it
        pub fn map_alloc(self: *Self, ctx: *const Ctx, func: *const fn(*const Ctx, R) S, input: []const R) ![]S {
            var results = try self.allocator.alloc(S, input.len);
            try self.map(ctx, func, input, results);
            return results;
        }

        pub fn map_stateless(self: *Self, func: *const fn(R) S, input: []const R, results: []S) !void {
            std.debug.assert(results.len >= input.len);
            std.debug.assert(Ctx == u0);

            const n_batches = try self.send_messages_stateless(func, input, results);
            try self.receive_results(n_batches, results);
        }

        /// Allocates the results array
        /// Invoker owns the array, and must free it
        pub fn map_stateless_alloc(self: *Self, func: *const fn(R) S, input: []const R) ![]S {
            std.debug.assert(Ctx == u0);

            var results = try self.allocator.alloc(S, input.len);
            try self.map_stateless(func, input, results);
            return results;
        }
    };
}

pub fn similarMap(comptime R: type, comptime T: type) type {
    return ParallelMap(R, R, T);
}

pub fn statelessMap(comptime R: type, comptime S: type) type {
    return ParallelMap(R, S, u0);
}

pub fn statelessSimilarMap(comptime R: type) type {
    return ParallelMap(R, R, u0);
}