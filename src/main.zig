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

const initiate_worker = @import("components/worker.zig").initiate_worker;
const initiate_sink = @import("components/sink.zig").initiate_sink;

fn create_block(num: usize) [4 * c.N_B]u8 {
    var block: [4 * c.N_B]u8 = undefined;

    var i: u6 = 0;
    var shift: u6 = 0;
    while (i < 5) : (i += 1) {
        block[i] = @truncate(num >> shift);
        shift += 8;
    }

    return block;
}

pub fn main() !void {
    const workers_num = 4;
    var input_queue = Queue(Message).init(5, std.heap.page_allocator);
    var result_queue = Queue(Message).init(5, std.heap.page_allocator);

    for (0..workers_num) |_| {
        _ = try initiate_worker(&input_queue, &result_queue);
    }

    _ = try initiate_sink(&result_queue);

    const amount = 1000;
    for (0..amount) |i| {
        const block = create_block(i);
        const message = Message.init(block, i);
        try input_queue.push(message);
    }
}

test {
    _ = @import("matrix.zig");
}
