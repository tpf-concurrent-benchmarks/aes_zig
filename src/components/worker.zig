const std = @import("std");
const Queue = @import("queue.zig").Queue;
const Message = @import("message.zig").Message;
const c = @import("../constants.zig");

fn handle_message(block: [4 * c.N_B]u8) [4 * c.N_B]u8 {
    //std.debug.print("{any}\n", .{block});
    return block;
}

fn worker_loop(input_queue: *Queue(Message), result_queue: *Queue(Message)) !void {
    while (true) {
        var message: Message = input_queue.pop();

        if (message.isEof()) {
            break;
        }

        const result = handle_message(message.block);
        message.block = result;
        try result_queue.push(message);
    }
}

pub fn initiate_worker(input_queue: *Queue(Message), result_queue: *Queue(Message)) !std.Thread {
    return std.Thread.spawn(.{}, worker_loop, .{ input_queue, result_queue });
}
