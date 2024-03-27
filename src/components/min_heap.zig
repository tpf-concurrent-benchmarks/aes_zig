const std = @import("std");
const Order = std.math.Order;

pub fn MinHeap(comptime T: type) type {
    return struct {
        compare_fn: *const fn (a: T, b: T) Order,
        data: []T,
        max_size: usize,
        size: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(comptime max_size: usize, comptime compare_fn: *const fn (a: T, b: T) Order, allocator: std.mem.Allocator) !Self {
            const data = try allocator.alloc(T, max_size);
            return Self{
                .compare_fn = compare_fn,
                .data = data,
                .max_size = max_size,
                .size = 0,
                .allocator = allocator,
            };
        }

        pub fn len(self: *Self) usize {
            return self.size;
        }

        fn swap(self: *Self, i: usize, j: usize) void {
            const tmp = self.data[i];
            self.data[i] = self.data[j];
            self.data[j] = tmp;
        }

        fn down(self: *Self, i: usize, n: usize) void {
            var i_var = i;
            while (true) {
                const l = 2 * i_var + 1;
                if (l >= n or l < 0) {
                    break;
                }
                var j = l;
                if (l + 1 < n and self.compare_fn(self.data[l], self.data[l + 1]) != Order.lt) {
                    j = l + 1;
                }
                if (self.compare_fn(self.data[j], self.data[i_var]) != Order.lt) {
                    break;
                }
                self.swap(i_var, j);
                i_var = j;
            }
        }

        fn heapify(self: *Self) void {
            if (self.len() < 2) {
                return;
            }

            var i = self.len() / 2;
            while (i >= 1) {
                self.down(i - 1, self.len());
                i -= 1;
            }
        }

        pub fn push(self: *Self, value: T) void {
            if (self.len() == self.max_size) {
                std.debug.panic("Heap is full", .{});
            }
            self.data[self.len()] = value;
            self.size += 1;
            self.heapify();
        }

        pub fn pop(self: *Self) T {
            const n = self.len() - 1;
            self.swap(0, n);
            self.down(0, n);
            const x = self.data[n];
            self.size -= 1;
            return x;
        }

        pub fn peek(self: *Self) T {
            return self.data[0];
        }

        pub fn deinit(self: *Self) void {
            self.allocator.free(self.data);
        }
    };
}
