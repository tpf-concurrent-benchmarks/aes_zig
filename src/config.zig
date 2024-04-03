const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvFileReader = @import("components/env_file_reader.zig").EnvFileReader;

pub const Config = struct {
	n_threads: usize,
	input_file: ?[]const u8,
	encrypted_file: ?[]const u8,
	decrypted_file: ?[]const u8,
	repeat: usize,
	publish_metrics: bool,

	arena: std.heap.ArenaAllocator,

	const Self = @This();

	pub fn init_from_env(allocator: Allocator) !Self {
		const env_file_reader = try EnvFileReader.init(allocator);

		const n_threads = try env_file_reader.get_usize("N_THREADS");
		const input_file = try env_file_reader.get_str("INPUT_FILE");
		const encrypted_file = try env_file_reader.get_str("ENCRYPTED_FILE");
		const decrypted_file = try env_file_reader.get_str("DECRYPTED_FILE");
		const repeat = try env_file_reader.get_usize("REPEAT");
		const publish_metrics = try env_file_reader.get_bool("PUBLISH_METRICS");

		var arena = std.heap.ArenaAllocator.init(allocator);
		const alloc = arena.allocator();

		return Self{
			.n_threads = n_threads orelse 1,
			.input_file = if (input_file) |i| try alloc.dupe(u8, i) else null,
			.encrypted_file = if (encrypted_file) |i| try alloc.dupe(u8, i) else null,
			.decrypted_file = if (decrypted_file) |i| try alloc.dupe(u8, i) else null,
			.repeat = repeat orelse 1,
			.publish_metrics = publish_metrics orelse false,
			.arena = arena,
		};
	}

	pub fn deinit(self: Self) void {
		self.arena.deinit();
	}
};

