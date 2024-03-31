const std = @import("std");
const Queue = @import("queue.zig").Queue;
const Message = @import("message.zig").Message;
const c = @import("../constants.zig");

const Block = [4 * c.N_B]u8;

pub fn Worker(comptime R: type, comptime S: type, comptime T: type) type {
    return struct {
        input_queue: *Queue(Message(R)),
        result_queue: *Queue(Message(S)),
        work_fn: *const fn(T, R) S,
        ctx: T,

        const Self = @This();

        pub fn init(input_queue: *Queue(Message(R)), result_queue: *Queue(Message(S)), ctx: T, comptime work_fn: *const fn(T, R) S) Self {
            return Self{
                .input_queue = input_queue,
                .result_queue = result_queue,
                .work_fn = work_fn,
                .ctx = ctx
            };
        }

        pub fn run(self: *Self) !void {
            while (true) {
                var message = self.input_queue.pop();

                if (message.is_eof()) {
                    break;
                }

                const result = self.work_fn(self.ctx, message.data);

                message.data = result;
                try self.result_queue.push(message);
            }
        }
    };
}

pub fn worker_loop(comptime R: type, comptime S: type, comptime T: type, worker: *Worker(R, S, T)) !void {
    return worker.run();
}

pub fn initiate_worker(comptime R: type, comptime S: type, comptime T: type, worker: *Worker(R, S, T)) !std.Thread {
    return std.Thread.spawn(.{}, worker_loop, .{ R, S, T, worker });
}
