const std = @import("std");
const print = std.debug.print;

/// Efficient implementation of a 4x4 matrix of u8, used in the AES-128 algorithm.
pub const Matrix = struct {
	data: [4][4]u8,

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
};

test "Matrix.get returns the expected value" {
	const m = Matrix.init([4][4]u8{
		[4]u8{0x01, 0x02, 0x03, 0x04},
		[4]u8{0x05, 0x06, 0x07, 0x08},
		[4]u8{0x09, 0x0a, 0x0b, 0x0c},
		[4]u8{0x0d, 0x0e, 0x0f, 0x10},
	});

	inline for (0..4) |i| {
		inline for (0..4) |j| {
			try std.testing.expectEqual( m.get(i, j), i * 4 + j + 1);
		}
	}
}

test "Matrix.set sets the value correctly" {
	var m = Matrix.init([4][4]u8{
	[4]u8{0xFF, 0x02, 0x03, 0x04},
	[4]u8{0x05, 0x06, 0xAF, 0x08},
	[4]u8{0x09, 0x0a, 0x0b, 0x0c},
	[4]u8{0x0d, 0x0e, 0x0f, 0x10},
	});

	m.set(0, 0, 0x01);
	m.set(1, 2, 0x07);

	try std.testing.expectEqual(m.get(0, 0), 0x01);
	try std.testing.expectEqual(m.get(1, 2), 0x07);
}

