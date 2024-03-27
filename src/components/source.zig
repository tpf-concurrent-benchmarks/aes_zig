const std = @import("std");
const c = @import("../constants.zig");
const Queue = @import("queue.zig").Queue;
const ChunkReader = @import("../chunk_reader.zig").ChunkReader;
const Message = @import("message.zig").Message;

const BUFFER_SIZE = 1000000;

pub fn initiate_source(input_queue: *Queue(Message)) !void {
    const input_filename = "data/input.txt";
    const input_file = try std.fs.cwd().openFile(input_filename, .{});
    defer input_file.close();

    var buffered_reader = std.io.bufferedReader(input_file.reader());
    var br = buffered_reader.reader();
    var chunk_reader = ChunkReader.init(true);

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    var arena_allocator = arena.allocator();
    const buffer = arena_allocator.alloc([4 * c.N_B]u8, BUFFER_SIZE) catch return error.OutOfMemory;

    var next_pos: u64 = 0;

    while (true) {
        const chunks_filled = try chunk_reader.read_chunks(br, BUFFER_SIZE, buffer);
        if (chunks_filled == 0) {
            break;
        }
        for (buffer[0..chunks_filled]) |block| {
            const m = Message.init(block, next_pos);
            //std.debug.print("{s}", .{block});
            try input_queue.push(m);
            next_pos += 1;
        }
    }
}
