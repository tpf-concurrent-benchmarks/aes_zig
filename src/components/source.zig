const std = @import("std");
const c = @import("../constants.zig");
const Queue = @import("queue.zig").Queue;
const ChunkReader = @import("../chunk_reader.zig").ChunkReader;
const Message = @import("message.zig").Message;

pub fn Source(comptime T: type) type {
    return struct {
        queue: *Queue(Message(T)),
        buffer_size: usize,
        allocator: std.mem.Allocator,

        const Self = @This();

        pub fn init(queue: *Queue(Message(T)), buffer_size: usize, allocator: std.mem.Allocator) Self {
            return Self{
                .queue = queue,
                .buffer_size = buffer_size,
                .allocator = allocator,
            };
        }

        pub fn run_from_reader(self: *Self, with_padding: bool, input: anytype) !void {
            var chunk_reader = ChunkReader(@TypeOf(input)).init(with_padding, input);

            const buffer = self.allocator.alloc([4 * c.N_B]u8, self.buffer_size) catch return error.OutOfMemory;
            defer self.allocator.free(buffer);

            var next_pos: u64 = 0;

            while (true) {
                const chunks_filled = try chunk_reader.read_chunks(self.buffer_size, buffer);
                if (chunks_filled == 0) {
                    break;
                }
                for (buffer[0..chunks_filled]) |block| {
                    const m = Message(T).init(block, next_pos);
                    try self.queue.push(m);
                    next_pos += 1;
                }
            }
        }

        pub fn run_from_file(self: *Self, with_padding: bool, input_file_path: []const u8) !void {
            const input_file = try std.fs.cwd().openFile(input_file_path, .{});
            defer input_file.close();
            try self.run_from_reader(with_padding, input_file.reader());
        }
    };
}
