const std = @import("std");
const Queue = @import("queue.zig").Queue;
const Message = @import("message.zig").Message;
const c = @import("../constants.zig");

const Block = [4 * c.N_B]u8;

pub fn handle_message(block: Block) Block {
    //std.debug.print("{any}\n", .{block});
    return block;
}

pub fn Worker(comptime R: type, comptime S: type) type {
    return struct {
        input_queue: *Queue(Message(R)),
        result_queue: *Queue(Message(S)),
        work_fn: *const fn (R) S,

        const Self = @This();

        pub fn init(input_queue: *Queue(Message(R)), result_queue: *Queue(Message(S)), work_fn: *const fn (R) S) Self {
            return Self {
                .input_queue = input_queue,
                .result_queue = result_queue,
                .work_fn = work_fn,
            };
        }

        pub fn run(self: *Self) !void {
            while (true) {
                var message = self.input_queue.pop();

                if (message.is_eof()) {
                    break;
                }

                const result = (self.work_fn)(message.data);
                message.data = result;
                try self.result_queue.push(message);
            }
        }
    };
}

pub fn worker_loop(comptime R: type, comptime S: type, worker: *Worker(R, S)) !void {
    return worker.run();
}

pub fn initiate_worker(comptime R: type, comptime S: type, worker: *Worker(R, S)) !std.Thread {
    return std.Thread.spawn(.{}, worker_loop, .{ R, S, worker });
}


























