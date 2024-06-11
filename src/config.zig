const std = @import("std");
const Allocator = std.mem.Allocator;
const EnvFileReader = @import("components/env_file_reader.zig").EnvFileReader;

const ConfigParseError = error{
    MissingGraphiteHost,
    MissingGraphitePort,
    MissingMetricsPrefix,
};

pub const Config = struct {
    n_threads: usize,
    input_file: ?[]const u8,
    encrypted_file: ?[]const u8,
    decrypted_file: ?[]const u8,
    repeat: usize,
    graphite_host: []const u8,
    graphite_port: u16,
    metrics_prefix: []const u8,

    arena: std.heap.ArenaAllocator,

    const Self = @This();

    pub fn init_from_env(allocator: Allocator) !Self {
        var env_file_reader = try EnvFileReader.init(allocator);
        defer env_file_reader.deinit();

        const n_threads = try env_file_reader.get_usize("N_THREADS");
        const input_file = try env_file_reader.get_str("INPUT_FILE");
        const encrypted_file = try env_file_reader.get_str("ENCRYPTED_FILE");
        const decrypted_file = try env_file_reader.get_str("DECRYPTED_FILE");
        const repeat = try env_file_reader.get_usize("REPEAT");
        var graphite_host: []const u8 = "";
        var graphite_port: u16 = 0;
        var metrics_prefix: []const u8 = "";
        if (try env_file_reader.get_str("GRAPHITE_HOST")) |host| {
            graphite_host = host;
        } else {
            return error.MissingGraphiteHost;
        }
        if (try env_file_reader.get_u16("GRAPHITE_PORT")) |port| {
            graphite_port = port;
        } else {
            return error.MissingGraphitePort;
        }
        if (try env_file_reader.get_str("METRICS_PREFIX")) |prefix| {
            metrics_prefix = prefix;
        } else {
            return error.MissingMetricsPrefix;
        }
        var arena = std.heap.ArenaAllocator.init(allocator);
        const alloc = arena.allocator();

        return Self{
            .n_threads = n_threads orelse 1,
            .input_file = if (input_file) |i| try alloc.dupe(u8, i) else null,
            .encrypted_file = if (encrypted_file) |i| try alloc.dupe(u8, i) else null,
            .decrypted_file = if (decrypted_file) |i| try alloc.dupe(u8, i) else null,
            .repeat = repeat orelse 1,
            .graphite_host = try alloc.dupe(u8, graphite_host),
            .graphite_port = graphite_port,
            .metrics_prefix = try alloc.dupe(u8, metrics_prefix),
            .arena = arena,
        };
    }

    pub fn deinit(self: Self) void {
        self.arena.deinit();
    }
};
