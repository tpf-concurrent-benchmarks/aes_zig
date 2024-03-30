const std = @import("std");
const io = std.io;

const CHUNK_SIZE = 16;

pub fn ChunkWriter(comptime T: type) type {
    return struct {
        remove_padding: bool,
        buffered_writer: io.BufferedWriter(4096, T),

        const Self = @This();

        pub fn init(remove_padding: bool, writer: anytype) Self {
            const buffered_writer = io.bufferedWriter(writer);
            return Self{
                .remove_padding = remove_padding,
                .buffered_writer = buffered_writer,
            };
        }

        /// Write the chunks to the writer, removing any null padding if `remove_padding` is true.
        /// Returns an error if it fails to write any of the chunks.
        pub fn write_chunks(self: *Self, chunks: [][CHUNK_SIZE]u8) !void {
            defer self.buffered_writer.flush();
            for (chunks) |chunk| {
                try self.write_chunk(chunk);
            }
        }

        pub fn write_chunk(self: *Self, chunk: [CHUNK_SIZE]u8) !void {
            if (self.remove_padding) {
                try self.write_chunk_without_padding(chunk);
            } else {
                const bytes_written = try self.buffered_writer.write(chunk[0..]);
                if (bytes_written != chunk.len) {
                    @panic("Failed to write chunk");
                }
            }
        }

        fn write_chunk_without_padding(self: *Self, chunk: [CHUNK_SIZE]u8) !void {
            var i: usize = chunk.len - 1;
            while (i > 0) : (i -= 1) {
                if (chunk[i] != 0) {
                    break;
                }
            }
            const bytes_written = try self.buffered_writer.write(chunk[0 .. i + 1]);
            if (bytes_written != i + 1) {
                @panic("Failed to write chunk");
            }
        }

        pub fn flush(self: *Self) !void {
            try self.buffered_writer.flush();
        }
    };
}
