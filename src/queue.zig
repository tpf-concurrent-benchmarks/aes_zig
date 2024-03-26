const std = @import("std");
const Allocator = std.mem.Allocator;

pub fn Queue(comptime T: type) type {
    return struct {
        const Self = @This();
        const TailQueueType = std.TailQueue(T);

        unsafe_queue: TailQueueType,
        allocator: Allocator,
        not_empty: std.Thread.Semaphore,
        not_full: std.Thread.Semaphore,

        pub fn init(max_size: usize, allocator: Allocator) Self {
            var not_empty = std.Thread.Semaphore{};
            var not_full = std.Thread.Semaphore{
                .permits = max_size,
            };
            const unsafe_queue = TailQueueType{};
            return Self{
				.unsafe_queue = unsafe_queue,
                .allocator = allocator,
                .not_empty = not_empty,
                .not_full = not_full,
            };
        }

        fn append(self: *Self, value: T) !void {
			var new_node = try self.allocator.create(TailQueueType.Node);
			new_node.data = value;

			self.unsafe_queue.append(new_node);
        }

		fn remove(self: *Self) T {
			if (self.unsafe_queue.pop()) |node| {
				defer self.allocator.destroy(node);
				return node.data;
			}
			std.debug.panic("Queue is empty", .{});
		}

        pub fn push(self: *Self, value: T) !void {
            self.not_full.wait();
            try self.append(value);
            self.not_empty.post();
        }

        pub fn pop(self: *Self) T {
            self.not_empty.wait();
            const value = self.remove();
            self.not_full.post();
            return value;
        }
    };
}
