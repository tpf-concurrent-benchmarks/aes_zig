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

    pub fn new_from_data(data: [N_B]u8) State {
        return State{ .data = matrix.Matrix.new_from_data(data) };
    }

    pub fn new_from_data_in(data_in: *[4 * N_B]u8) State {
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
            self.data.shift_row_left(i, i);
        }
    }

    pub fn inv_shift_rows(self: *State) void {
        for (1..N_B) |i| {
            self.data.shift_row_right(i, i);
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
            State.mix_column(col);
            self.data.set_col(i, col);
        }
    }

    pub fn inv_mix_columns(self: *State) void {
        inline for (0..N_B) |i| {
            var col = self.data.get_col(i);
            State.inv_mix_column(col);
            self.data.set_col(i, col);
        }
    }

    fn mix_column(col: *[N_B]u8) void {
        const a = col[0];
        const b = col[1];
        const c = col[2];
        const d = col[3];
        col[0] = State.galois_dobule(@as(i8, a ^ b)) ^ b ^ c ^ d;
        col[1] = State.galois_dobule(@as(i8, b ^ c)) ^ c ^ d ^ a;
        col[2] = State.galois_dobule(@as(i8, c ^ d)) ^ d ^ a ^ b;
        col[3] = State.galois_dobule(@as(i8, d ^ a)) ^ a ^ b ^ c;
    }

    fn inv_mix_column(col: *[N_B]u8) void {
        const a = col[0];
        const b = col[1];
        const c = col[2];
        const d = col[3];
        const x = State.galois_dobule(@as(i8, a ^ b ^ c ^ d));
        const y = State.galois_dobule(@as(i8, x ^ a ^ c));
        const z = State.galois_dobule(@as(i8, x ^ b ^ d));
        col[0] = State.galois_dobule(@as(i8, y ^ a ^ b)) ^ b ^ c ^ d;
        col[1] = State.galois_dobule(@as(i8, z ^ b ^ c)) ^ c ^ d ^ a;
        col[2] = State.galois_dobule(@as(i8, y ^ c ^ d)) ^ d ^ a ^ b;
        col[3] = State.galois_dobule(@as(i8, z ^ d ^ a)) ^ a ^ b ^ c;
    }

    fn galois_dobule(a: i8) u8 {
        var result = @as(u8, a << 1);
        if (a < 0) {
            result ^= 0x1b;
        }
        return result;
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
