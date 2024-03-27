const std = @import("std");
const io = std.io;

const CHUNK_SIZE = 16;

pub const ChunkWriter = struct {
    remove_padding: bool,

    const Self = @This();

    pub fn init(remove_padding: bool) Self {
        return Self{
            .remove_padding = remove_padding,
        };
    }

    /// Write the chunks to the writer, removing any null padding if `remove_padding` is true.
    /// Returns an error if it fails to write any of the chunks.
    pub fn write_chunks(self: Self, writer: anytype, chunks: [][CHUNK_SIZE]u8) @TypeOf(writer).Error!void {
        for (chunks) |chunk| {
            try self.write_chunk(writer, chunk);
        }
    }

    pub fn write_chunk(self: Self, writer: anytype, chunk: [CHUNK_SIZE]u8) @TypeOf(writer).Error!void {
        if (self.remove_padding) {
            try Self.write_chunk_without_padding(writer, chunk);
        } else {
            try writer.writeAll(chunk[0..]);
        }
    }

    fn write_chunk_without_padding(writer: anytype, chunk: [CHUNK_SIZE]u8) @TypeOf(writer).Error!void {
        var i: usize = chunk.len - 1;
        while (i > 0) : (i -= 1) {
            if (chunk[i] != 0) {
                break;
            }
        }
        try writer.writeAll(chunk[0 .. i + 1]);
    }
};
