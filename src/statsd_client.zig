const std = @import("std");
const os = std.os;
const net = std.net;
const Allocator = std.mem.Allocator;

pub const StatsDConfig = struct {
    host: []const u8 = "127.0.0.1",
    port: u16 = 8125,
    // It is strongly recommended that you use another allocator, because this one makes a syscall for every alloc,
    // and the StatsDClient uses it to concatenate the metric string that will be sent
    allocator: Allocator = std.heap.page_allocator,
    prefix: ?[]const u8 = null,
};

/// Simple pseudo random number generator to avoid depending on the std implementation, which caused some problems
/// Anyway, this use case does not require an extremely good generator
const Rng = struct {
    prev: u128,

    pub fn init(seed: u64) Rng {
        return .{ .prev = seed };
    }

    pub fn next(self: *Rng) u32 {
        const ret = self.prev;
        self.prev = (1664525 * self.prev + 1013904223) % (1 << 32);
        return @truncate(ret);
    }

    pub fn next_f64(self: *Rng) f64 {
        const n = self.next();
        const n_f32: f32 = @floatFromInt(n);
        return @as(f64, n_f32 / (1 << 32));
    }
};

pub const StatsDClient = struct {
    stream: net.Stream,
    prefix: ?[]const u8,
    arena: std.heap.ArenaAllocator,
    allocator: Allocator,

    rand: Rng,

    const Self = @This();

    /// Creates a new client that sends metrics over UDP
    /// The metrics will be sent one by one
    /// Creates a new client that sends metrics over UDP
    /// The metrics will be sent one by one
    pub fn init(config: StatsDConfig) !Self {
        const arena = std.heap.ArenaAllocator.init(config.allocator);

        const stream = try Self.create_udp_stream(config.host, config.port, config.allocator);
        errdefer stream.close();

        return try Self.init_with_stream(config.prefix, stream, arena, config.allocator);
    }

    pub fn init_with_stream(prefix: ?[]const u8, stream: net.Stream, arena: std.heap.ArenaAllocator, allocator: Allocator) !Self {
        var ret: Self = undefined;

        ret.rand = try Self.create_prng();

        ret.stream = stream;
        ret.arena = arena;
        ret.allocator = allocator;

        if (prefix) |pr| {
            const prefix_alloc = try allocator.alloc(u8, pr.len);
            std.mem.copy(u8, prefix_alloc, pr);
            ret.prefix = prefix_alloc;
        } else {
            ret.prefix = null;
        }

        return ret;
    }

    /// Closes the stream and frees the allocated memory
    pub fn deinit(self: Self) void {
        self.arena.deinit();
    }

    fn create_prng() !Rng {
        var seed: u64 = undefined;
        try std.os.getrandom(std.mem.asBytes(&seed));
        return Rng.init(seed);
    }

    fn create_udp_stream(host: []const u8, port: u16, allocator: Allocator) !net.Stream {
        const addr_list = try net.getAddressList(allocator, host, port);
        defer addr_list.deinit();

        if (addr_list.addrs.len == 0) return error.UnknownHostName;
        var addr = try allocator.create(net.Address);
        addr = &addr_list.addrs[0];

        const fd = try os.socket(os.AF.INET, os.SOCK.DGRAM | os.SOCK.CLOEXEC, 0);
        errdefer os.closeSocket(fd);
        try os.connect(fd, &addr.any, addr.getOsSockLen());
        return net.Stream{ .handle = fd };
    }

    /// Concatenates the strings to form the metric to send
    /// If self.prefix is set, it will add it to the start of the metric
    /// Caller owns the memory
    fn alloc_metric(self: Self, slices: []const []const u8) ![]u8 {
        if (self.prefix) |prefix| {
            var buf_size: usize = prefix.len + 1;
            for (slices) |slice| {
                buf_size += slice.len;
            }
            const buf = try self.allocator.alloc(u8, buf_size);
            errdefer self.allocator.free(buf);

            std.mem.copy(u8, buf, prefix);
            std.mem.copy(u8, buf[prefix.len..], ".");
            var buf_index: usize = prefix.len + 1;
            for (slices) |slice| {
                std.mem.copy(u8, buf[buf_index..], slice);
                buf_index += slice.len;
            }
            return buf;
        } else {
            return std.mem.concat(self.allocator, u8, slices);
        }
    }

    fn number_to_str(self: Self, a: anytype) ![]u8 {
        return std.fmt.allocPrint(self.allocator, "{d}", .{a});
    }

    /// Modify a counter by `value`
    pub fn count(self: Self, metric_name: []const u8, value: f64) !void {
        return self.send_sampled_count(metric_name, value, null);
    }

    /// Modify a counter by `value` only `rate`*100% of the time
    pub fn sampled_count(self: *Self, metric_name: []const u8, value: f64, rate: f64) !void {
        if (self.should_sample(rate)) {
            return self.send_sampled_count(metric_name, value, rate);
        }
    }

    fn send_sampled_count(self: Self, metric_name: []const u8, value: f64, rate: ?f64) !void {
        const value_str = try self.number_to_str(value);
        defer self.allocator.free(value_str);
        var metric: []const u8 = undefined;
        if (rate) |r| {
            const rate_str = try self.number_to_str(r);
            defer self.allocator.free(rate_str);
            metric = try self.alloc_metric(&[_][]const u8{ metric_name, ":", value_str, "|c|@", rate_str });
        } else {
            metric = try self.alloc_metric(&[_][]const u8{ metric_name, ":", value_str, "|c" });
        }

        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }

    /// Increment a metric by 1
    pub fn incr(self: Self, metric_name: []const u8) !void {
        return self.count(metric_name, 1.0);
    }

    /// Decrement a metric by 1
    pub fn decr(self: Self, metric_name: []const u8) !void {
        return self.count(metric_name, -1.0);
    }

    /// Send a timer with `value`, in ms
    pub fn timer(self: Self, metric_name: []const u8, value: f64) !void {
        return self.send_sampled_timer(metric_name, value, null);
    }

    /// Send a timer with `value`, in ms, only `rate`*100% of the time
    pub fn sampled_timer(self: *Self, metric_name: []const u8, value: f64, rate: f64) !bool {
        if (self.should_sample(rate)) {
            return self.send_sampled_timer(metric_name, value, rate);
        }
    }

    fn send_sampled_timer(self: Self, metric_name: []const u8, value: f64, rate: ?f64) !void {
        const value_str = try self.number_to_str(value);
        defer self.allocator.free(value_str);
        var metric: []const u8 = undefined;
        if (rate) |r| {
            const rate_str = try self.number_to_str(r);
            defer self.allocator.free(rate_str);
            metric = try self.alloc_metric(&[_][]const u8{ metric_name, ":", value_str, "|ms|@", rate_str });
        } else {
            metric = try self.alloc_metric(&[_][]const u8{ metric_name, ":", value_str, "|ms" });
        }
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }

    /// Set a gauge to `value`
    pub fn gauge(self: Self, metric_name: []const u8, value: f64) !void {
        const value_str = try self.number_to_str(value);
        defer self.allocator.free(value_str);

        const metric = try self.alloc_metric(&[_][]const u8{ metric_name, ":", value_str, "|g" });
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }

    /// Increment a gauge by `value`
    pub fn gauge_incr(self: Self, metric_name: []const u8, amount: f64) !void {
        const amount_str = try self.number_to_str(amount);
        defer self.allocator.free(amount_str);

        const metric = try self.alloc_metric(&[_][]const u8{ metric_name, ":+", amount_str, "|g" });
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }

    /// Decrement a gauge by `value`
    pub fn gauge_decr(self: Self, metric_name: []const u8, amount: f64) !void {
        const amount_str = try self.number_to_str(amount);
        defer self.allocator.free(amount_str);

        const metric = try self.alloc_metric(&[_][]const u8{ metric_name, ":-", amount_str, "|g" });
        defer self.allocator.free(metric);

        try self.stream.writeAll(metric);
    }

    fn should_sample(self: *Self, rate: f64) bool {
        return self.rand.next_f64() < rate;
    }
};
