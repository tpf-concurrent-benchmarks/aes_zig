const std = @import("std");
const Queue = @import("queue.zig").Queue;
const Message = @import("message.zig").Message;
const DataWithFn = @import("message.zig").DataWithFn;
const c = @import("../constants.zig");

const Block = [4 * c.N_B]u8;

pub fn Worker(comptime R: type, comptime S: type, comptime T: type) type {
    return struct {
        input_queue: *Queue(Message(DataWithFn(T, R, S))),
        result_queue: *Queue(Message(S)),

        const Self = @This();

        pub fn init(input_queue: *Queue(Message(DataWithFn(T, R, S))), result_queue: *Queue(Message(S))) Self {
            return Self{
                .input_queue = input_queue,
                .result_queue = result_queue,
            };
        }

        pub fn run(self: *Self) !void {
            while (true) {
                var message = self.input_queue.pop();

                if (message.is_eof()) {
                    break;
                }

                const result = message.data.call();

                const result_msg = Message(S).init(result, message.pos);
                try self.result_queue.push(result_msg);
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
