const std = @import("std");
const io = std.io;

const CHUNK_SIZE = 16;

pub const ChunkReader = struct {
    with_padding: bool,

    const Self = @This();

    pub fn init(with_padding: bool) Self {
        return Self{
            .with_padding = with_padding,
        };
    }

    fn fill_chunk(self: Self, reader: anytype, buffer: *[CHUNK_SIZE]u8) @TypeOf(reader).Error!usize {
        var bytes_read: usize = 0;
        while (bytes_read < CHUNK_SIZE) {
            const read_result = try reader.read(buffer[0..]);

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

    pub fn read_chunks(self: Self, reader: anytype, chunks_amount: usize, buffer: [][CHUNK_SIZE]u8) @TypeOf(reader).Error!usize {
        var chunks_filled: usize = 0;

        while (chunks_filled < chunks_amount) {
            const bytes_filled = try self.fill_chunk(reader, &buffer[chunks_filled]);
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

    ChunkReader.apply_null_padding(0, &buffer);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(u8, 0), buffer[i]);
    }
}

test "apply_null_padding only pads the last CHUNK_SIZE - bytes_read bytes with null bytes" {
    var buffer: [CHUNK_SIZE]u8 = undefined;
    @memset(&buffer, 1);

    ChunkReader.apply_null_padding(2, &buffer);
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
    var cursor = Cursor.init(&data);
    var r = cursor.reader();

    var cr = ChunkReader.init(true);
    var buffer: [CHUNK_SIZE]u8 = undefined;
    const bytes_filled = try cr.fill_chunk(r, &buffer);
    try std.testing.expectEqual(@as(usize, CHUNK_SIZE), bytes_filled);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(usize, 42), buffer[i]);
    }
}

test "ChunkReader.fill_chunk fills the buffer partially if the input has less data than the buffer size" {
    const data = [_]u8{ 1, 2, 3, 4 };
    var cursor = Cursor.init(&data);
    var r = cursor.reader();

    var cr = ChunkReader.init(true);
    var buffer: [CHUNK_SIZE]u8 = undefined;
    const bytes_filled = try cr.fill_chunk(r, &buffer);
    try std.testing.expectEqual(@as(usize, 4), bytes_filled);
    try std.testing.expectEqual(@as(usize, 1), buffer[0]);
    try std.testing.expectEqual(@as(usize, 2), buffer[1]);
    try std.testing.expectEqual(@as(usize, 3), buffer[2]);
    try std.testing.expectEqual(@as(usize, 4), buffer[3]);
}

test "ChunkReader.fill_chunk fills the buffer with null bytes if the input has no data and with_padding is true" {
    var cursor = Cursor.init(&([_]u8{}));
    var r = cursor.reader();

    var cr = ChunkReader.init(true);
    var buffer: [CHUNK_SIZE]u8 = undefined;
    const bytes_filled = try cr.fill_chunk(r, &buffer);
    try std.testing.expectEqual(@as(usize, 0), bytes_filled);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(u8, 0), buffer[i]);
    }
}

test "ChunkReader.fill_chunk applies padding correctly when the input has some data" {
    const data = [_]u8{ 1, 2, 3, 4 };
    var cursor = Cursor.init(&data);
    var r = cursor.reader();

    var cr = ChunkReader.init(true);
    var buffer: [CHUNK_SIZE]u8 = undefined;
    const bytes_filled = try cr.fill_chunk(r, &buffer);
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
    var cursor = Cursor.init(&data);
    var r = cursor.reader();

    var cr = ChunkReader.init(true);
    var buffer: [1][CHUNK_SIZE]u8 = undefined;
    const chunks_filled = try cr.read_chunks(r, 1, &buffer);
    try std.testing.expectEqual(@as(usize, 1), chunks_filled);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(usize, i + 1), buffer[0][i]);
    }
}

test "ChunkReader.read_chunk can read one chunk with less data CHUNK_SIZE bytes" {
    const data = [_]u8{ 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14 };
    var cursor = Cursor.init(&data);
    var r = cursor.reader();

    var cr = ChunkReader.init(true);
    var buffer: [1][CHUNK_SIZE]u8 = undefined;
    const chunks_filled = try cr.read_chunks(r, 1, &buffer);
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
    var cursor = Cursor.init(&data);
    var r = cursor.reader();

    var cr = ChunkReader.init(true);
    var buffer: [2][CHUNK_SIZE]u8 = undefined;
    const chunks_filled = try cr.read_chunks(r, 2, &buffer);
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
    var cursor = Cursor.init(&data);
    var r = cursor.reader();

    var cr = ChunkReader.init(true);
    var buffer: [2][CHUNK_SIZE]u8 = undefined;
    const chunks_filled = try cr.read_chunks(r, 2, &buffer);
    try std.testing.expectEqual(@as(usize, 2), chunks_filled);
    inline for (0..CHUNK_SIZE) |i| {
        try std.testing.expectEqual(@as(usize, i + 1), buffer[0][i]);
    }
    inline for (0..CHUNK_SIZE - 1) |i| {
        try std.testing.expectEqual(@as(usize, i + CHUNK_SIZE + 1), buffer[1][i]);
    }
    try std.testing.expectEqual(@as(u8, 0), buffer[1][CHUNK_SIZE - 1]);
}
