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

        pub fn init_null(pos: u64) Self {
            std.debug.assert(T == u0);
            return Self{ .data = undefined, .pos = pos };
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

pub const EmptyMessage = Message(u0);

pub fn DataWithFn(comptime Ctx: type, comptime R: type, comptime S: type) type {
    return struct {
        data: []const R,
        func: ?*const fn (*const Ctx, R) S,
        func2: ?*const fn (R) S,
        context: ?*const Ctx,
        destination: []S,

        const Self = @This();

        pub fn init(data: []const R, func: *const fn (*const Ctx, R) S, context: *const Ctx, destination: []S) Self {
            return Self{ .data = data, .func = func, .func2 = null, .context = context, .destination = destination };
        }

        pub fn init_stateless(data: []const R, func: *const fn (R) S, destination: []S) Self {
            return Self{ .data = data, .func = null, .func2 = func, .context = null, .destination = destination };
        }

        fn call_one(self: Self, value: *const R) S {
            if (self.func) |func| {
                return func(self.context.?, value.*);
            } else if (self.func2) |func| {
                return func(value.*);
            } else {
                unreachable;
            }
        }

        pub fn call(self: Self) void {
            std.debug.assert(self.destination.len >= self.data.len);

            for (self.data, 0..) |item, i| {
                self.destination[i] = self.call_one(&item);
            }
        }
    };
}