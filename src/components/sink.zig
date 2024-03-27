const std = @import("std");
const Queue = @import("queue.zig").Queue;
const Message = @import("message.zig").Message;
const MinHeap = @import("min_heap.zig").MinHeap;
const MessageHeap = @import("message.zig").MessageHeap;
const ChunkWriter = @import("../chunk_writer.zig").ChunkWriter;
const c = @import("../constants.zig");

fn handle_block(block: [4 * c.N_B]u8, writer: anytype, chunk_writer: ChunkWriter) !void {
    // std.debug.print("{s}", .{block});
    try chunk_writer.write_chunk(writer, block);
}

pub fn Sink(comptime T: type) type {
    return struct {
        queue: *Queue(Message(T)),
        buffer_size: usize,
        heap: MinHeap(Message(T)),

        const Self = @This();

        pub fn init(queue: *Queue(Message(T)), buffer_size: usize, allocator: std.mem.Allocator) !Self {
            return Self{
            .queue = queue,
            .buffer_size = buffer_size,
            .heap = try MinHeap(Message(T)).init(c.MAX_HEAP_SIZE, Message(T).order, allocator)
            };
        }

        pub fn run_from_writer(self: *Self, remove_padding: bool, writer: anytype) !void {
            var next_block: u64 = 0;

            var buffered_writer = std.io.bufferedWriter(writer);
            const bw = buffered_writer.writer();
            const cw = ChunkWriter.init(remove_padding);

            while (true) {
                const message = self.queue.pop();

                if (message.is_eof()) {
                    break;
                }

                if (message.pos > next_block) {
                    self.heap.push(message);
                    continue;
                }

                if (message.pos < next_block) {
                    @panic("Received block out of order");
                }

                try handle_block(message.data, bw, cw);
                next_block += 1;

                while (self.heap.len() > 0 and self.heap.peek().pos == next_block) {
                    const message_i = self.heap.pop();
                    try handle_block(message_i.data, bw, cw);
                    next_block += 1;
                }
            }
            try buffered_writer.flush();
        }

        pub fn run_from_file(self: *Self, remove_padding: bool, output_file_path: []const u8) !void {
            const input_file = try std.fs.cwd().createFile(output_file_path, .{});
            defer input_file.close();
            try self.run_from_writer(remove_padding, input_file.writer());
        }
    };
}

pub fn sink_loop(comptime T: type, sink: *Sink(T), remove_padding: bool, output_file_path: []const u8) !void {
    return sink.run_from_file(remove_padding, output_file_path);
}

pub fn initiate_sink(comptime T: type, sink: *Sink(T), remove_padding: bool, output_file_path: []const u8) !std.Thread {
    return std.Thread.spawn(.{}, sink_loop, .{T, sink, remove_padding, output_file_path});
}














