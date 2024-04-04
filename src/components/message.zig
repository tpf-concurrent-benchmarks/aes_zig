const std = @import("std");
const Order = std.math.Order;
const c = @import("../constants.zig");
const MinHeap = @import("min_heap.zig").MinHeap;

const maxU64: u64 = 0xFFFFFFFFFFFFFFFF;

pub fn Message(comptime T: type) type {
    return struct {
        data: T,
        pos: u64,

        const Self = @This();

        pub fn init(data: T, pos: u64) Self {
            return Self{ .data = data, .pos = pos };
        }

        pub fn order(self: Self, other: Message(T)) Order {
            return std.math.order(self.pos, other.pos);
        }

        pub fn is_eof(self: Self) bool {
            return self.pos == maxU64;
        }

        pub fn init_eof() Self {
            return Message(T){ .data = undefined, .pos = maxU64 };
        }
    };
}

pub fn DataWithFn(comptime Ctx: type, comptime R: type, comptime S: type) type {
    return struct {
        data: R,
        func: *const fn (*const Ctx, R) S,
        context: *const Ctx,

        const Self = @This();

        pub fn init(data: R, func: *const fn (*const Ctx, R) S, context: *const Ctx) Self {
            return Self{ .data = data, .func = func, .context = context };
        }

        pub fn call(self: Self) S {
            return self.func(self.context, self.data);
        }
    };
}