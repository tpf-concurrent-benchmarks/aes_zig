const std = @import("std");
const io = std.io;

const CHUNK_SIZE = 16;

pub fn ChunkReader(comptime T: type) type {
    return struct {
        with_padding: bool,
        buffered_reader: io.BufferedReader(4096, T),

        const Self = @This();

        pub fn init(with_padding: bool, reader: anytype) Self {
            const buffered_reader = io.bufferedReader(reader);
            return Self{
                .with_padding = with_padding,
                .buffered_reader = buffered_reader,
            };
        }

        fn fill_chunk(self: *Self, buffer: *[CHUNK_SIZE]u8) !usize {
            var bytes_read: usize = 0;
            while (bytes_read < CHUNK_SIZE) {
                const read_result = try self.buffered_reader.read(buffer[0..]);

                if (read_result == 0) {
                    if (self.with_padding) {
                        apply_null_padding(bytes_read, buffer);
                    }
                    return bytes_read;
                } else {
                    bytes_read += read_result;
                }
            }
            return bytes_read;
        }

        pub fn read_chunks(self: *Self, chunks_amount: usize, buffer: [][CHUNK_SIZE]u8) !usize {
            var chunks_filled: usize = 0;

            while (chunks_filled < chunks_amount) {
                const bytes_filled = try self.fill_chunk(&buffer[chunks_filled]);
                if (bytes_filled == 0) {
                    return chunks_filled;
                } else {
                    chunks_filled += 1;
                    if (bytes_filled < CHUNK_SIZE) {
                        return chunks_filled;
                    }
                }
            }
            return chunks_filled;
        }

        fn apply_null_padding(bytes_read: usize, buffer: *[CHUNK_SIZE]u8) void {
            for (bytes_read..CHUNK_SIZE) |i| {
                buffer[i] = 0;
            }
        }

    };

}

pub const Cursor = struct {
    data: []const u8,
    curr: usize,

    pub const Error = error{NoError};
    pub const Self = @This();
    pub const Reader = io.Reader(*Self, Error, read);

    pub fn init(data: []const u8) Self {
        return Self{
            .data = data,
            .curr = 0,
        };
    }

    pub fn read(self: *Self, dest: []u8) Error!usize {
        if (self.curr >= self.data.len or dest.len == 0) {
            return 0;
        }
        const bytes_to_copy = @min(dest.len, self.data.len - self.curr);

        @memcpy(dest[0..bytes_to_copy], self.data[self.curr .. self.curr + bytes_to_copy]);
        self.curr += bytes_to_copy;
        return bytes_to_copy;
    }

    pub fn reader(self: *Self) Reader {
        return .{ .context = self };
    }
};

test "apply_null_padding pads the entire buffer with null bytes if bytes_read is 0" {
    var buffer: [CHUNK_SIZE]u8 = undefined;

    ChunkReader(Cursor).apply_null_padding(0, &buffer);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(u8, 0), buffer[i]);
    }
}

test "apply_null_padding only pads the last CHUNK_SIZE - bytes_read bytes with null bytes" {
    var buffer: [CHUNK_SIZE]u8 = undefined;
    @memset(&buffer, 1);

    ChunkReader(Cursor).apply_null_padding(2, &buffer);
    inline for (0..2) |i| {
        try std.testing.expectEqual(@as(u8, 1), buffer[i]);
    }
    inline for (2..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(u8, 0), buffer[i]);
    }
}

test "ChunkReader.fill_chunk fills the buffer if the input has enough data" {
    var data: [CHUNK_SIZE]u8 = undefined;
    @memset(&data, 42);
    const cursor = Cursor.init(&data);

    var cr = ChunkReader(Cursor).init(true, cursor);
    var buffer: [CHUNK_SIZE]u8 = undefined;
    const bytes_filled = try cr.fill_chunk(&buffer);
    try std.testing.expectEqual(@as(usize, CHUNK_SIZE), bytes_filled);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(usize, 42), buffer[i]);
    }
}

test "ChunkReader.fill_chunk fills the buffer partially if the input has less data than the buffer size" {
    const data = [_]u8{ 1, 2, 3, 4 };
    const cursor = Cursor.init(&data);

    var cr = ChunkReader(Cursor).init(true, cursor);
    var buffer: [CHUNK_SIZE]u8 = undefined;
    const bytes_filled = try cr.fill_chunk(&buffer);
    try std.testing.expectEqual(@as(usize, 4), bytes_filled);
    try std.testing.expectEqual(@as(usize, 1), buffer[0]);
    try std.testing.expectEqual(@as(usize, 2), buffer[1]);
    try std.testing.expectEqual(@as(usize, 3), buffer[2]);
    try std.testing.expectEqual(@as(usize, 4), buffer[3]);
}

test "ChunkReader.fill_chunk fills the buffer with null bytes if the input has no data and with_padding is true" {
    const cursor = Cursor.init(&([_]u8{}));

    var cr = ChunkReader(Cursor).init(true, cursor);
    var buffer: [CHUNK_SIZE]u8 = undefined;
    const bytes_filled = try cr.fill_chunk(&buffer);
    try std.testing.expectEqual(@as(usize, 0), bytes_filled);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(u8, 0), buffer[i]);
    }
}

test "ChunkReader.fill_chunk applies padding correctly when the input has some data" {
    const data = [_]u8{ 1, 2, 3, 4 };
    const cursor = Cursor.init(&data);

    var cr = ChunkReader(Cursor).init(true, cursor);
    var buffer: [CHUNK_SIZE]u8 = undefined;
    const bytes_filled = try cr.fill_chunk(&buffer);
    try std.testing.expectEqual(@as(usize, 4), bytes_filled);
    try std.testing.expectEqual(@as(usize, 1), buffer[0]);
    try std.testing.expectEqual(@as(usize, 2), buffer[1]);
    try std.testing.expectEqual(@as(usize, 3), buffer[2]);
    try std.testing.expectEqual(@as(usize, 4), buffer[3]);
    inline for (4..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(u8, 0), buffer[i]);
    }
}

test "ChunkReader.read_chunk can read one chunk with the exact size" {
    const data = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16 };
    const cursor = Cursor.init(&data);

    var cr = ChunkReader(Cursor).init(true, cursor);
    var buffer: [1][CHUNK_SIZE]u8 = undefined;
    const chunks_filled = try cr.read_chunks(1, &buffer);
    try std.testing.expectEqual(@as(usize, 1), chunks_filled);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(usize, i + 1), buffer[0][i]);
    }
}

test "ChunkReader.read_chunk can read one chunk with less data CHUNK_SIZE bytes" {
    const data = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 };
    const cursor = Cursor.init(&data);

    var cr = ChunkReader(Cursor).init(true, cursor);
    var buffer: [1][CHUNK_SIZE]u8 = undefined;
    const chunks_filled = try cr.read_chunks(1, &buffer);
    try std.testing.expectEqual(@as(usize, 1), chunks_filled);
    inline for (0..14) |i| {
        try std.testing.expectEqual(@as(usize, i + 1), buffer[0][i]);
    }
    inline for (14..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(u8, 0), buffer[0][i]);
    }
}

test "ChunkReader.read_chunk can read multiple chunks with the exact size" {
    const data = [_]u8{
        1,  2,  3,  4,  5,  6,  7,  8,
        9,  10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31, 32,
    };
    const cursor = Cursor.init(&data);

    var cr = ChunkReader(Cursor).init(true, cursor);
    var buffer: [2][CHUNK_SIZE]u8 = undefined;
    const chunks_filled = try cr.read_chunks(2, &buffer);
    try std.testing.expectEqual(@as(usize, 2), chunks_filled);
    inline for (0..2) |i| {
        inline for (0..CHUNK_SIZE) |j| {
            try std.testing.expectEqual(@as(usize, i * CHUNK_SIZE + j + 1), buffer[i][j]);
        }
    }
}

test "ChunkReader.read_chunk can read multiple chunks with less data than CHUNK_SIZE bytes" {
    const data = [_]u8{
        1,  2,  3,  4,  5,  6,  7,  8,
        9,  10, 11, 12, 13, 14, 15, 16,
        17, 18, 19, 20, 21, 22, 23, 24,
        25, 26, 27, 28, 29, 30, 31,
    };
    const cursor = Cursor.init(&data);

    var cr = ChunkReader(Cursor).init(true, cursor);
    var buffer: [2][CHUNK_SIZE]u8 = undefined;
    const chunks_filled = try cr.read_chunks(2, &buffer);
    try std.testing.expectEqual(@as(usize, 2), chunks_filled);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(usize, i + 1), buffer[0][i]);
    }
    inline for (0..CHUNK_SIZE - 1) |i| {
        try std.testing.expectEqual(@as(usize, i + CHUNK_SIZE + 1), buffer[1][i]);
    }
    try std.testing.expectEqual(@as(u8, 0), buffer[1][CHUNK_SIZE - 1]);
}
