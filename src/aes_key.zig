const std = @import("std");
const constants = @import("constants.zig");
const state = @import("state.zig");

const Word = constants.Word;
const N_B = constants.N_B;
const N_R = constants.N_R;
const N_K = constants.N_K;

pub const AESKey = struct {
    data: [N_B * (N_R + 1)]Word,

    // pub fn new_direct(cipher_key: [u8; 4 * N_K as usize]) -> Self {
    // let mut data = [0; N_B * (N_R + 1)];
    // Self::expand_key(cipher_key, &mut data);
    // Self { data }
    // }

    pub fn new_direct(cipher_key: [4 * N_K]u8) AESKey {
        var data: [N_B * (N_R + 1)]Word = undefined;
        @memset(&data, 0);

        AESKey.expand_key(cipher_key, &data);
        return AESKey{ .data = data };
    }

    //
    // pub fn new_inverse(cipher_key: [u8; 4 * N_K as usize]) -> Self {
    // let mut data = [0; N_B * (N_R + 1)];
    // Self::inv_expand_key(cipher_key, &mut data);
    // Self { data }
    // }

    pub fn new_inverse(cipher_key: [4 * N_K]u8) AESKey {
        var data: [N_B * (N_R + 1)]Word = undefined;
        @memset(&data, 0);

        AESKey.inv_expand_key(cipher_key, &data);
        return AESKey{ .data = data };
    }

    pub fn u32_from_be_bytes(bytes: [4]u8) Word {
        const reversed_bytes = [4]u8{
            bytes[3],
            bytes[2],
            bytes[1],
            bytes[0],
        };
        return @bitCast(reversed_bytes);
    }

    pub fn expand_key(cipher_key: [4 * N_K]u8, data: *[N_B * (N_R + 1)]Word) void {
        var temp: Word = undefined;
        var i: usize = 0;

        while (i < N_K) {
            data[i] = AESKey.u32_from_be_bytes([4]u8{
                cipher_key[4 * i],
                cipher_key[4 * i + 1],
                cipher_key[4 * i + 2],
                cipher_key[4 * i + 3],
            });
            i += 1;
        }

        i = N_K;

        while (i < (N_B * (N_R + 1))) {
            temp = data[i - 1];
            if (i % N_K == 0) {
                temp = AESKey.sub_word(AESKey.rot_word(temp)) ^ constants.R_CON[i / N_K - 1];
            }
            data[i] = data[i - N_K] ^ temp;
            i += 1;
        }
    }

    fn inv_expand_key(cipher_key: [4 * N_K]u8, dw: *[N_B * (N_R + 1)]Word) void {
        AESKey.expand_key(cipher_key, dw);

        for (1..N_R) |round| {
            const new_words: [N_B]Word = state.inv_mix_columns_words(&dw[round * N_B .. (round + 1) * N_B]);
            for (0..N_B) |i| {
                dw[round * N_B + i] = new_words[i];
            }
        }
    }

    fn sub_word(word: Word) Word {
        var result: u32 = 0;
        var i: u2 = 0;
        while (true) {
            const byte = AESKey.get_byte_from_word(word, i);
            const new_byte = AESKey.apply_s_box(byte);
            result |= (@as(u32, new_byte)) << (8 * @as(u5, i));
            if (i == 3) {
                break;
            }
            i += 1;
        }

        return result;
    }

    fn rot_word(word: Word) Word {
        return (word << 8) | (word >> 24);
    }

    fn inv_mix_columns_words(words: *[N_B]Word) [N_B]Word {
        var s = state.State.new_from_words(words);
        s.inv_mix_columns();
        const cols = s.data.get_cols();
        var result: [N_B]Word = undefined;
        @memset(&result, 0);

        for (0..N_B) |i| {
            result[i] = AESKey.u32_from_be_bytes([4]u8{
                cols[i][0],
                cols[i][1],
                cols[i][2],
                cols[i][3],
            });
        }
        return result;
    }

    fn get_byte_from_word(word: Word, pos: u2) u8 {
        return @truncate(word >> (8 * @as(u5, pos)));
    }

    fn apply_s_box(value: u8) u8 {
        const pos_x: u8 = @truncate(value >> 4);
        const pos_y: u8 = @truncate(value & 0x0f);
        return constants.S_BOX[pos_x * 16 + pos_y];
    }
};

test "AESKey.rot_word should work" {
    const word: u32 = 0x09cf4f3c;
    const expected_word: u32 = 0xcf4f3c09;
    try std.testing.expectEqual(expected_word, AESKey.rot_word(word));
}

test "AESKey.sub_word should work" {
    const word: u32 = 0xcf4f3c09;
    const expected_word: u32 = 0x8a84eb01;
    try std.testing.expectEqual(expected_word, AESKey.sub_word(word));
}

test "AESKey.new_direct should work" {
    const cipher_key = [4 * N_K]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f, 0x3c,
    };

    const expected_words = [N_B * (N_R + 1)]Word{
        0x2b7e1516, 0x28aed2a6, 0xabf71588, 0x09cf4f3c, 0xa0fafe17, 0x88542cb1, 0x23a33939, 0x2a6c7605,
        0xf2c295f2, 0x7a96b943, 0x5935807a, 0x7359f67f, 0x3d80477d, 0x4716fe3e, 0x1e237e44, 0x6d7a883b,
        0xef44a541, 0xa8525b7f, 0xb671253b, 0xdb0bad00, 0xd4d1c6f8, 0x7c839d87, 0xcaf2b8bc, 0x11f915bc,
        0x6d88a37a, 0x110b3efd, 0xdbf98641, 0xca0093fd, 0x4e54f70e, 0x5f5fc9f3, 0x84a64fb2, 0x4ea6dc4f,
        0xead27321, 0xb58dbad2, 0x312bf560, 0x7f8d292f, 0xac7766f3, 0x19fadc21, 0x28d12941, 0x575c006e,
        0xd014f9a8, 0xc9ee2589, 0xe13f0cc8, 0xb6630ca6,
    };

    const key = AESKey.new_direct(cipher_key);

    for (0..(N_B * (N_R + 1))) |i| {
        try std.testing.expectEqual(expected_words[i], key.data[i]);
    }
}