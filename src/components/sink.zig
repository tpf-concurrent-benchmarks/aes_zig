const std = @import("std");
const Queue = @import("queue.zig").Queue;
const Message = @import("message.zig").Message;
const MessageHeap = @import("message.zig").MessageHeap;
const ChunkWriter = @import("../chunk_writer.zig").ChunkWriter;
const c = @import("../constants.zig");

fn handle_block(block: [4 * c.N_B]u8, writer: anytype, chunk_writer: ChunkWriter) !void {
    // std.debug.print("{s}", .{block});
    try chunk_writer.write_chunk(writer, block);
}

const BUFFER_SIZE = 1000000; // TODO!: put this somewhere else

fn sink_loop(result_queue: *Queue(Message)) !void {
    var heap = try MessageHeap.init(c.MAX_HEAP_SIZE, Message.messageComparison, std.heap.page_allocator);
    var next_block: u64 = 0;
    defer heap.deinit();

    const output_filename = "data/output.txt";
    const output_file = try std.fs.cwd().createFile(output_filename, .{});
    defer output_file.close();

    var buffered_writer = std.io.bufferedWriter(output_file.writer());
    var bw = buffered_writer.writer();
    var cw = ChunkWriter.init(true);

    while (true) {
        const message: Message = result_queue.pop();

        if (message.isEof()) {
            break;
        }

        if (message.pos > next_block) {
            heap.push(message);
            continue;
        }

        if (message.pos < next_block) {
            @panic("Received block out of order");
        }

        try handle_block(message.block, bw, cw);
        next_block += 1;

        while (heap.len() > 0 and heap.peek().pos == next_block) {
            const message_i = heap.pop();
            try handle_block(message_i.block, bw, cw);
            next_block += 1;
        }
    }

    try buffered_writer.flush();
}

pub fn initiate_sink(result_queue: *Queue(Message)) !std.Thread {
    return std.Thread.spawn(.{}, sink_loop, .{result_queue});
}
