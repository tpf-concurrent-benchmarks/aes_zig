const matrix = @import("matrix.zig");
const std = @import("std");
const constants = @import("constants.zig");

const N_B = constants.N_B;
const Word = constants.Word;

pub const State = struct {
    data: matrix.Matrix,

    pub fn new() State {
        return State{ .data = matrix.Matrix.new() };
    }

    pub fn new_from_matrix(data: matrix.Matrix) State {
        return State{ .data = data };
    }

    pub fn new_from_data(data: [4][N_B]u8) State {
        return State{ .data = matrix.Matrix.init(data) };
    }

    pub fn new_from_data_in(data_in: *const [4 * N_B]u8) State {
        var state = State.new();
        inline for (0..N_B) |i| {
            const col = [N_B]u8{
                data_in[4 * i],
                data_in[4 * i + 1],
                data_in[4 * i + 2],
                data_in[4 * i + 3],
            };
            state.data.set_col(i, col);
        }
        return state;
    }

    pub fn u32_to_be_bytes(n: u32) [4]u8 {
        return [4]u8{
            @truncate(n >> 24),
            @truncate(n >> 16),
            @truncate(n >> 8),
            @truncate(n),
        };
    }

    pub fn new_from_words(words: *[N_B]Word) State {
        var state = State.new();
        inline for (0..N_B) |i| {
            const word = words[i];
            const word_bytes = State.u32_to_be_bytes(word);
            const col = [N_B]u8{ word_bytes[0], word_bytes[1], word_bytes[2], word_bytes[3] };
            state.data.set_col(i, col);
        }
        return state;
    }

    pub fn set_data_out(self: *const State, data_out: *[4 * N_B]u8) void {
        inline for (0..N_B) |i| {
            const col = self.data.get_col(i);
            data_out[4 * i] = col[0];
            data_out[4 * i + 1] = col[1];
            data_out[4 * i + 2] = col[2];
            data_out[4 * i + 3] = col[3];
        }
    }

    pub fn sub_bytes(self: *State) void {
        self.apply_substitution(constants.S_BOX);
    }

    pub fn inv_sub_bytes(self: *State) void {
        self.apply_substitution(constants.INV_S_BOX);
    }

    fn apply_substitution(self: *State, sub_box: [256]u8) void {
        inline for (0..N_B) |i| {
            inline for (0..N_B) |j| {
                const value = self.data.get(i, j);
                self.data.set(i, j, sub_box[value]);
            }
        }
    }

    pub fn shift_rows(self: *State) void {
        for (1..N_B) |i| {
            self.data.shift_row_left(@truncate(i), @truncate(i));
        }
    }

    pub fn inv_shift_rows(self: *State) void {
        for (1..N_B) |i| {
            self.data.shift_row_right(@truncate(i), @truncate(i));
        }
    }

    pub fn add_round_key(self: *State, round_key: *const [N_B]Word) void {
        inline for (0..N_B) |i| {
            const col = self.data.get_col(i);
            const word = round_key[i];
            const word_bytes = State.u32_to_be_bytes(word);
            const new_col = [4]u8{
                col[0] ^ word_bytes[0],
                col[1] ^ word_bytes[1],
                col[2] ^ word_bytes[2],
                col[3] ^ word_bytes[3],
            };
            self.data.set_col(i, new_col);
        }
    }

    pub fn mix_columns(self: *State) void {
        inline for (0..N_B) |i| {
            var col = self.data.get_col(i);
            State.mix_column(&col);
            self.data.set_col(i, col);
        }
    }

    pub fn inv_mix_columns(self: *State) void {
        inline for (0..N_B) |i| {
            var col = self.data.get_col(i);
            State.inv_mix_column(&col);
            self.data.set_col(i, col);
        }
    }

    fn mix_column(col: *[N_B]u8) void {
        const a = col[0];
        const b = col[1];
        const c = col[2];
        const d = col[3];
        col[0] = State.galois_dobule(@bitCast(a ^ b)) ^ b ^ c ^ d;
        col[1] = State.galois_dobule(@bitCast(b ^ c)) ^ c ^ d ^ a;
        col[2] = State.galois_dobule(@bitCast(c ^ d)) ^ d ^ a ^ b;
        col[3] = State.galois_dobule(@bitCast(d ^ a)) ^ a ^ b ^ c;
    }

    fn inv_mix_column(col: *[N_B]u8) void {
        const a = col[0];
        const b = col[1];
        const c = col[2];
        const d = col[3];
        const x = State.galois_dobule(@bitCast(a ^ b ^ c ^ d));
        const y = State.galois_dobule(@bitCast(x ^ a ^ c));
        const z = State.galois_dobule(@bitCast(x ^ b ^ d));
        col[0] = State.galois_dobule(@bitCast(y ^ a ^ b)) ^ b ^ c ^ d;
        col[1] = State.galois_dobule(@bitCast(z ^ b ^ c)) ^ c ^ d ^ a;
        col[2] = State.galois_dobule(@bitCast(y ^ c ^ d)) ^ d ^ a ^ b;
        col[3] = State.galois_dobule(@bitCast(z ^ d ^ a)) ^ a ^ b ^ c;
    }

    fn galois_dobule(a: i8) u8 {
        var result: u8 = @bitCast(a << 1);
        if (a < 0) {
            result ^= 0x1b;
        }
        return result;
    }

    fn equals(self: *const State, other: *const State) bool {
        return self.data.equals(&other.data);
    }
};

test "State.new_from_words should work" {
    var words = [N_B]Word{ 0x01020304, 0x05060708, 0x090a0b0c, 0x0d0e0f10 };
    const state = State.new_from_words(&words);
    const expected = matrix.Matrix.init([4][4]u8{
        [4]u8{ 0x01, 0x05, 0x09, 0x0d },
        [4]u8{ 0x02, 0x06, 0x0a, 0x0e },
        [4]u8{ 0x03, 0x07, 0x0b, 0x0f },
        [4]u8{ 0x04, 0x08, 0x0c, 0x10 },
    });

    try std.testing.expect(expected.equals(&state.data));
}

test "State.shift_rows should work" {
    var s = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0xd4, 0xe0, 0xb8, 0x1e },
        [N_B]u8{ 0xbf, 0xb4, 0x41, 0x27 },
        [N_B]u8{ 0x5d, 0x52, 0x11, 0x98 },
        [N_B]u8{ 0x30, 0xae, 0xf1, 0xe5 },
    });

    s.shift_rows();

    const expected_state = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0xd4, 0xe0, 0xb8, 0x1e },
        [N_B]u8{ 0xb4, 0x41, 0x27, 0xbf },
        [N_B]u8{ 0x11, 0x98, 0x5d, 0x52 },
        [N_B]u8{ 0xe5, 0x30, 0xae, 0xf1 },
    });

    try std.testing.expect(s.equals(&expected_state));
}

test "State.inv_shift_rows should work" {
    var s = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0xd4, 0xe0, 0xb8, 0x1e },
        [N_B]u8{ 0xb4, 0x41, 0x27, 0xbf },
        [N_B]u8{ 0x11, 0x98, 0x5d, 0x52 },
        [N_B]u8{ 0xe5, 0x30, 0xae, 0xf1 },
    });

    s.inv_shift_rows();

    const expected_state = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0xd4, 0xe0, 0xb8, 0x1e },
        [N_B]u8{ 0xbf, 0xb4, 0x41, 0x27 },
        [N_B]u8{ 0x5d, 0x52, 0x11, 0x98 },
        [N_B]u8{ 0x30, 0xae, 0xf1, 0xe5 },
    });

    try std.testing.expect(s.equals(&expected_state));
}

test "State.sub_bytes should work" {
    var s = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0x19, 0xa0, 0x9a, 0xe9 },
        [N_B]u8{ 0x3d, 0xf4, 0xc6, 0xf8 },
        [N_B]u8{ 0xe3, 0xe2, 0x8d, 0x48 },
        [N_B]u8{ 0xbe, 0x2b, 0x2a, 0x08 },
    });

    s.sub_bytes();

    const expected_state = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0xd4, 0xe0, 0xb8, 0x1e },
        [N_B]u8{ 0x27, 0xbf, 0xb4, 0x41 },
        [N_B]u8{ 0x11, 0x98, 0x5d, 0x52 },
        [N_B]u8{ 0xae, 0xf1, 0xe5, 0x30 },
    });

    try std.testing.expect(s.equals(&expected_state));
}

test "State.inv_sub_bytes should work" {
    var s = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0xd4, 0xe0, 0xb8, 0x1e },
        [N_B]u8{ 0x27, 0xbf, 0xb4, 0x41 },
        [N_B]u8{ 0x11, 0x98, 0x5d, 0x52 },
        [N_B]u8{ 0xae, 0xf1, 0xe5, 0x30 },
    });

    s.inv_sub_bytes();

    const expected_state = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0x19, 0xa0, 0x9a, 0xe9 },
        [N_B]u8{ 0x3d, 0xf4, 0xc6, 0xf8 },
        [N_B]u8{ 0xe3, 0xe2, 0x8d, 0x48 },
        [N_B]u8{ 0xbe, 0x2b, 0x2a, 0x08 },
    });

    try std.testing.expect(s.equals(&expected_state));
}

test "State.get_state_from_data_in should work" {
    const data_in = [4 * N_B]u8{
    0x32, 0x88, 0x31, 0xe0, 0x43, 0x5a, 0x31, 0x37, 0xf6, 0x30, 0x98, 0x07, 0xa8, 0x8d, 0xa2,
    0x34,
    };

    const expected_state = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0x32, 0x43, 0xf6, 0xa8 },
        [N_B]u8{ 0x88, 0x5a, 0x30, 0x8d },
        [N_B]u8{ 0x31, 0x31, 0x98, 0xa2 },
        [N_B]u8{ 0xe0, 0x37, 0x07, 0x34 },
    });

    const state = State.new_from_data_in(&data_in);

    try std.testing.expect(state.equals(&expected_state));
}


test "State.set_data_out should work" {
    var data_out: [4 * N_B]u8 = undefined;
    const s = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0x39, 0x02, 0xdc, 0x19 },
        [N_B]u8{ 0x25, 0xdc, 0x11, 0x6a },
        [N_B]u8{ 0x84, 0x09, 0x85, 0x0b },
        [N_B]u8{ 0x1d, 0xfb, 0x97, 0x32 },
    });

    const expected_data_out = [4 * N_B]u8{
        0x39, 0x25, 0x84, 0x1d, 0x02, 0xdc, 0x09, 0xfb, 0xdc, 0x11, 0x85, 0x97, 0x19, 0x6a, 0x0b, 0x32,
    };

    s.set_data_out(&data_out);

    try std.testing.expect(std.mem.eql(u8, &data_out, &expected_data_out));
}

test "State.mix_columns should work" {
    var s = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0xdb, 0xf2, 0x01, 0xc6 },
        [N_B]u8{ 0x13, 0x0a, 0x01, 0xc6 },
        [N_B]u8{ 0x53, 0x22, 0x01, 0xc6 },
        [N_B]u8{ 0x45, 0x5c, 0x01, 0xc6 },
    });

    s.mix_columns();

    const expected_state = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0x8e, 0x9f, 0x01, 0xc6 },
        [N_B]u8{ 0x4d, 0xdc, 0x01, 0xc6 },
        [N_B]u8{ 0xa1, 0x58, 0x01, 0xc6 },
        [N_B]u8{ 0xbc, 0x9d, 0x01, 0xc6 },
    });

    try std.testing.expect(s.equals(&expected_state));
}

test "State.inv_mix_columns should work" {
    var s = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0x8e, 0x9f, 0x01, 0xc6 },
        [N_B]u8{ 0x4d, 0xdc, 0x01, 0xc6 },
        [N_B]u8{ 0xa1, 0x58, 0x01, 0xc6 },
        [N_B]u8{ 0xbc, 0x9d, 0x01, 0xc6 },
    });

    s.inv_mix_columns();

    const expected_state = State.new_from_data([4][N_B]u8{
        [N_B]u8{ 0xdb, 0xf2, 0x01, 0xc6 },
        [N_B]u8{ 0x13, 0x0a, 0x01, 0xc6 },
        [N_B]u8{ 0x53, 0x22, 0x01, 0xc6 },
        [N_B]u8{ 0x45, 0x5c, 0x01, 0xc6 },
    });

    try std.testing.expect(s.equals(&expected_state));
}