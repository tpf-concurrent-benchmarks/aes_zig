const std = @import("std");
const Order = std.math.Order;
const c = @import("../constants.zig");
const MinHeap = @import("min_heap.zig").MinHeap;

const maxU64: u64 = 0xFFFFFFFFFFFFFFFF;

pub const Message = struct {
    block: [4 * c.N_B]u8,
    pos: u64,

    pub fn init(block: [4 * c.N_B]u8, pos: u64) Message {
        return Message{ .block = block, .pos = pos };
    }

    pub fn messageComparison(a: Message, b: Message) Order {
        return std.math.order(a.pos, b.pos);
    }

    pub fn isEof(self: Message) bool {
        return self.pos == maxU64;
    }
};

pub const MessageHeap = MinHeap(Message);

pub const EOF = Message{ .block = [_]u8{0} ** (4 * c.N_B), .pos = maxU64 };
