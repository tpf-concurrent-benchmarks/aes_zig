const std = @import("std");
const Allocator = std.mem.Allocator;
const File = std.fs.File;

pub const EnvFileReader = struct {
	vars: Map,

	arena: std.heap.ArenaAllocator,

	const Self = @This();
	const Map = std.StringHashMap([]const u8);
	const item_size = 128;

	pub fn init(allocator: Allocator) !Self {
		const file = try std.fs.cwd().openFile(".env", .{});
		defer file.close();

		var arena = std.heap.ArenaAllocator.init(allocator);

		const map = try Self.read_vars(file.reader(), arena.allocator());

		return Self{ .vars = map, .arena = arena };
	}

	pub fn deinit(self: Self) void {
		self.arena.deinit();
	}

	fn read_vars(reader: File.Reader, allocator: Allocator) !Map {
		var map = Map.init(allocator);

		while (true) {
			const l = try reader.readUntilDelimiterOrEofAlloc(allocator, '\n', Self.item_size);
			if (l) |line| {
				var it = std.mem.split(u8, line, "=");

				const key = it.next();
				const value = it.next();

				if (key == null or value == null) {
					continue;
				}
				try map.put(key.?, value.?);
			} else {
				break;
			}
		}
		return map;
	}

	pub fn get_str(self: Self, key: []const u8) !?[]const u8 {
		return self.vars.get(key) orelse return null;
	}

	pub fn get_usize(self: Self, key: []const u8) !?usize {
		const value = self.vars.get(key) orelse return null;
		return try std.fmt.parseInt(usize, value, 0);
	}

    pub fn get_u16(self: Self, key: []const u8) !?u16 {
        const value = self.vars.get(key) orelse return null;
        return try std.fmt.parseInt(u16, value, 0);
    }

	pub fn get_bool(self: Self, key: []const u8) !?bool {
		const value = self.vars.get(key) orelse return null;
		return std.mem.eql(u8, value, "true") or std.mem.eql(u8, value, "1");
	}
};