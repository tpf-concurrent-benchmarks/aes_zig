const std = @import("std");
const print = std.debug.print;

pub const Matrix = struct {
    data: [4][4]u8,

    pub fn new() Matrix {
        return Matrix{ .data = [4][4]u8{
            [4]u8{ 0, 0, 0, 0 },
            [4]u8{ 0, 0, 0, 0 },
            [4]u8{ 0, 0, 0, 0 },
            [4]u8{ 0, 0, 0, 0 },
        } };
    }

    /// Create a new matrix from a 2-dimensional array of u8.
    pub fn init(data: [4][4]u8) Matrix {
        return Matrix{ .data = data };
    }

    /// Get the item at the given row and column.
    pub fn get(self: Matrix, row: u2, col: u2) u8 {
        return self.data[row][col];
    }

    /// Set the item at the given row and column.
    pub fn set(self: *Matrix, row: u2, col: u2, value: u8) void {
        self.*.data[row][col] = value;
    }

    pub fn get_cols(self: Matrix) [4][4]u8 {
        var cols: [4][4]u8 = undefined;
        inline for (0..4) |i| {
            inline for (0..4) |j| {
                cols[j][i] = self.data[i][j];
            }
        }
        return cols;
    }

    pub fn get_col(self: Matrix, col: u2) [4]u8 {
        var col_data: [4]u8 = undefined;
        inline for (0..4) |i| {
            col_data[i] = self.get(i, col);
        }
        return col_data;
    }

    pub fn set_col(self: *Matrix, col: u2, data: [4]u8) void {
        inline for (0..4) |i| {
            self.*.set(i, col, data[i]);
        }
    }

    pub fn shift_row_left(self: *Matrix, row: u2, shift: u2) void {
        for (0..shift) |_| {
            const tmp = self.get(row, 0);
            inline for (0..3) |i| {
                self.set(row, i, self.get(row, i + 1));
            }
            self.set(row, 3, tmp);
        }
    }

    pub fn shift_row_right(self: *Matrix, row: u2, shift: u2) void {
        for (0..shift) |_| {
            const tmp = self.get(row, 3);
            inline for (0..3) |i| {
                self.set(row, 3 - i, self.get(row, 2 - i));
            }
            self.set(row, 0, tmp);
        }
    }

    pub fn equals(self: *const Matrix, other: *const Matrix) bool {
        inline for (0..4) |i| {
            inline for (0..4) |j| {
                if (self.get(i, j) != other.get(i, j)) {
                    return false;
                }
            }
        }
        return true;
    }
};

test "Matrix.get returns the expected value" {
    const m = Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x02, 0x03, 0x04 },
        [4]u8{ 0x05, 0x06, 0x07, 0x08 },
        [4]u8{ 0x09, 0x0a, 0x0b, 0x0c },
        [4]u8{ 0x0d, 0x0e, 0x0f, 0x10 },
    });

    inline for (0..4) |i| {
        inline for (0..4) |j| {
            try std.testing.expectEqual(i * 4 + j + 1, m.get(i, j));
        }
    }
}

test "Matrix.set sets the value correctly" {
    var m = Matrix.init([4][4]u8{
        [4]u8{ 0xFF, 0x02, 0x03, 0x04 },
        [4]u8{ 0x05, 0x06, 0xAF, 0x08 },
        [4]u8{ 0x09, 0x0a, 0x0b, 0x0c },
        [4]u8{ 0x0d, 0x0e, 0x0f, 0x10 },
    });

    m.set(0, 0, 0x01);
    m.set(1, 2, 0x07);

    try std.testing.expectEqual(@as(u8, 0x01), m.get(0, 0));
    try std.testing.expectEqual(@as(u8, 0x07), m.get(1, 2));
}

test "Matrix.get_cols returns the columns of the matrix" {
    var m = Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x02, 0x03, 0x04 },
        [4]u8{ 0x05, 0x06, 0x07, 0x08 },
        [4]u8{ 0x09, 0x0a, 0x0b, 0x0c },
        [4]u8{ 0x0d, 0x0e, 0x0f, 0x10 },
    });

    const cols = m.get_cols();
    try std.testing.expectEqual([4]u8{ 0x01, 0x05, 0x09, 0x0d }, cols[0]);
    try std.testing.expectEqual([4]u8{ 0x02, 0x06, 0x0a, 0x0e }, cols[1]);
    try std.testing.expectEqual([4]u8{ 0x03, 0x07, 0x0b, 0x0f }, cols[2]);
    try std.testing.expectEqual([4]u8{ 0x04, 0x08, 0x0c, 0x10 }, cols[3]);
}

test "Matrix.get_col returns a column of the matrix" {
    var m = Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x02, 0x03, 0x04 },
        [4]u8{ 0x05, 0x06, 0x07, 0x08 },
        [4]u8{ 0x09, 0x0a, 0x0b, 0x0c },
        [4]u8{ 0x0d, 0x0e, 0x0f, 0x10 },
    });

    const col = m.get_col(2);
    try std.testing.expectEqual([4]u8{ 0x03, 0x07, 0x0b, 0x0f }, col);
}

test "Matrix.set_col changes the values of a column" {
    var m = Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x02, 0x03, 0x04 },
        [4]u8{ 0x05, 0x06, 0x07, 0x08 },
        [4]u8{ 0x09, 0x0a, 0x0b, 0x0c },
        [4]u8{ 0x0d, 0x0e, 0x0f, 0x10 },
    });

    m.set_col(2, [4]u8{ 0x0f, 0x0b, 0x07, 0x03 });
    const col = m.get_col(2);
    try std.testing.expectEqual([4]u8{ 0x0f, 0x0b, 0x07, 0x03 }, col);
}

test "Matrix.shift_row_left shifts a row to the left" {
    var m = Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x02, 0x03, 0x04 },
        [4]u8{ 0x05, 0x06, 0x07, 0x08 },
        [4]u8{ 0x09, 0x0a, 0x0b, 0x0c },
        [4]u8{ 0x0d, 0x0e, 0x0f, 0x10 },
    });

    m.shift_row_left(0, 0);
    m.shift_row_left(1, 1);
    m.shift_row_left(2, 2);
    m.shift_row_left(3, 3);

    const expected_m = Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x02, 0x03, 0x04 },
        [4]u8{ 0x06, 0x07, 0x08, 0x05 },
        [4]u8{ 0x0b, 0x0c, 0x09, 0x0a },
        [4]u8{ 0x10, 0x0d, 0x0e, 0x0f },
    });

    inline for (0..4) |i| {
        inline for (0..4) |j| {
            try std.testing.expectEqual(expected_m.get(i, j), m.get(i, j));
        }
    }
}

test "Matrix.shift_row_right shifts a row to the right" {
    var m = Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x02, 0x03, 0x04 },
        [4]u8{ 0x05, 0x06, 0x07, 0x08 },
        [4]u8{ 0x09, 0x0a, 0x0b, 0x0c },
        [4]u8{ 0x0d, 0x0e, 0x0f, 0x10 },
    });

    m.shift_row_right(0, 0);
    m.shift_row_right(1, 1);
    m.shift_row_right(2, 2);
    m.shift_row_right(3, 3);

    const expected_m = Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x02, 0x03, 0x04 },
        [4]u8{ 0x08, 0x05, 0x06, 0x07 },
        [4]u8{ 0x0b, 0x0c, 0x09, 0x0a },
        [4]u8{ 0x0e, 0x0f, 0x10, 0x0d },
    });

    inline for (0..4) |i| {
        inline for (0..4) |j| {
            try std.testing.expectEqual(expected_m.get(i, j), m.get(i, j));
        }
    }
}
