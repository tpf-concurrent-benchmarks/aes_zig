const std = @import("std");
const Queue = @import("queue.zig").Queue;
const Message = @import("message.zig").Message;
const c = @import("../constants.zig");

fn sink_loop(result_queue: *Queue(Message)) void {
    while (true) {
        const message = result_queue.pop();
        std.debug.print("{any}\n", .{message.block});
    }
}

pub fn initiate_sink(result_queue: *Queue(Message)) !std.Thread {
    return std.Thread.spawn(.{}, sink_loop, .{result_queue});
}
