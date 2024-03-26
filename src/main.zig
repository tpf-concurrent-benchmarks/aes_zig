const std = @import("std");
const matrix = @import("matrix.zig");
const AESCipher = @import("aes_cipher.zig").AESCipher;
const Queue = @import("queue.zig").Queue;

const RNG = struct {
    prev: u128,

    pub fn init(seed: u32) RNG {
        return RNG{ .prev = seed };
    }

    pub fn next(self: *RNG) u32 {
        // self.prev = (69069 * self.prev + 1) % 4294967295;
        // return @truncate(self.prev);
        self.prev = self.prev + 1;
        return @truncate(self.prev);
    }
};

fn producer(queue: *Queue(u32), number: u32) !void {
    var rng = RNG.init(number);

    for (0..100) |_| {
        var value = rng.next();
        try queue.push(value);
    }
}

fn consumer(queue: *Queue(u32)) void {
    for (0..100) |_| {
        var value = queue.pop();
        std.debug.print("{d}\n", .{value});
    }
}

pub fn main() !void {
    var queue = Queue(u32).init(5, std.heap.page_allocator);

    var producer_threads: [4]std.Thread = undefined;
    var consumer_threads: [4]std.Thread = undefined;

    for (0..4) |i| {
        const producer_thread = try std.Thread.spawn(.{}, producer, .{ &queue, @as(u32, @truncate(1000 * i)) });
        const consumer_thread = try std.Thread.spawn(.{}, consumer, .{&queue});

        producer_threads[i] = producer_thread;
        consumer_threads[i] = consumer_thread;
    }

    for (producer_threads, consumer_threads) |producer_thread, consumer_thread| {
        std.Thread.join(producer_thread);
        std.Thread.join(consumer_thread);
    }
}

test {
    _ = @import("matrix.zig");
}
