const std = @import("std");
const matrix = @import("matrix.zig");

pub fn main() !void {
    std.debug.print("Hello world\n", .{});
}

test {
    _ = @import("matrix.zig");
}
