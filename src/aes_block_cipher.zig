const std = @import("std");

const aes_key = @import("aes_key.zig");
const state = @import("state.zig");
const constants = @import("constants.zig");

const N_K = constants.N_K;
const N_B = constants.N_B;
const N_R = constants.N_R;

pub const AESBlockCipher = struct {
    expanded_key: aes_key.AESKey,
    inv_expanded_key: aes_key.AESKey,

    pub fn new(cipher_key: [4 * N_B]u8) AESBlockCipher {
        const expanded_key = aes_key.AESKey.new_direct(cipher_key);
        const inv_expanded_key = aes_key.AESKey.new_inverse(cipher_key);

        return AESBlockCipher{
            .expanded_key = expanded_key,
            .inv_expanded_key = inv_expanded_key,
        };
    }

    fn u128_to_be_bytes(n: u128) [16]u8 {
        var bytes: [16]u8 = undefined;

        inline for (0..16) |i| {
            bytes[i] = @truncate(n >> (8 * (15 - i)));
        }

        return bytes;
    }

    pub fn new_u128(cipher_key: u128) AESBlockCipher {
        const cipher_key_bytes = AESBlockCipher.u128_to_be_bytes(cipher_key);
        return AESBlockCipher.new(cipher_key_bytes);
    }

    pub fn cipher_block(self: AESBlockCipher, data_in: [4 * N_B]u8) [4 * N_B]u8 {
        var data_out: [4 * N_B]u8 = undefined;

        var s = state.State.new_from_data_in(data_in);

        s.add_round_key(self.expanded_key.data[0..N_B]);

        inline for (1..N_R) |round| {
            s.sub_bytes();
            s.shift_rows();
            s.mix_columns();
            s.add_round_key(self.expanded_key.data[(round * N_B)..((round + 1) * N_B)]);
        }
        s.sub_bytes();
        s.shift_rows();
        s.add_round_key(self.expanded_key.data[(N_R * N_B)..((N_R + 1) * N_B)]);

        s.set_data_out(&data_out);

        return data_out;
    }

    pub fn inv_cipher_block(self: AESBlockCipher, data_in: [4 * N_B]u8) [4 * N_B]u8 {
        var data_out: [4 * N_B]u8 = undefined;

        var s = state.State.new_from_data_in(data_in);

        s.add_round_key(self.inv_expanded_key.data[(N_R * N_B)..((N_R + 1) * N_B)]);

        inline for (1..N_R) |i| {
            const round = N_R - i;
            s.inv_sub_bytes();
            s.inv_shift_rows();
            s.inv_mix_columns();
            s.add_round_key(self.inv_expanded_key.data[(round * N_B)..((round + 1) * N_B)]);
        }
        s.inv_sub_bytes();
        s.inv_shift_rows();
        s.add_round_key(self.inv_expanded_key.data[0..N_B]);

        s.set_data_out(&data_out);

        return data_out;
    }
};

test "AESBlockCipher.cipher_block should return the expected cipher bytes when creating a new AESBlockCipher with AESBlockCipher.new" {
    const plain_bytes = [4 * N_B]u8{
        0x32, 0x43, 0xf6, 0xa8, 0x88, 0x5a, 0x30, 0x8d, 0x31, 0x31, 0x98, 0xa2, 0xe0, 0x37, 0x07,
        0x34,
    };

    const cipher_key = [4 * N_K]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f,
        0x3c,
    };

    const expected_cipher_bytes = [4 * N_B]u8{
        0x39, 0x25, 0x84, 0x1d, 0x02, 0xdc, 0x09, 0xfb, 0xdc, 0x11, 0x85, 0x97, 0x19, 0x6a, 0x0b,
        0x32,
    };

    const cipher = AESBlockCipher.new(cipher_key);

    const cipher_bytes = cipher.cipher_block(plain_bytes);

    try std.testing.expect(std.mem.eql(u8, &cipher_bytes, &expected_cipher_bytes));
}

test "AESBlockCipher.cipher_block should return the expected cipher bytes when creating a new AESBlockCipher with AESBlockCipher.new_u128" {
    const plain_bytes = [4 * N_B]u8{
        0x32, 0x43, 0xf6, 0xa8, 0x88, 0x5a, 0x30, 0x8d, 0x31, 0x31, 0x98, 0xa2, 0xe0, 0x37, 0x07,
        0x34,
    };

    const cipher_key = 0x2b7e151628aed2a6abf7158809cf4f3c;

    const expected_cipher_bytes = [4 * N_B]u8{
        0x39, 0x25, 0x84, 0x1d, 0x02, 0xdc, 0x09, 0xfb, 0xdc, 0x11, 0x85, 0x97, 0x19, 0x6a, 0x0b,
        0x32,
    };

    const cipher = AESBlockCipher.new_u128(cipher_key);

    const cipher_bytes = cipher.cipher_block(plain_bytes);

    try std.testing.expect(std.mem.eql(u8, &cipher_bytes, &expected_cipher_bytes));
}

test "AESBlockCipher.inv_cipher_block should return the expected plain text" {
    const expected_plain_text = [4 * N_B]u8{
        0x32, 0x43, 0xf6, 0xa8, 0x88, 0x5a, 0x30, 0x8d, 0x31, 0x31, 0x98, 0xa2, 0xe0, 0x37, 0x07,
        0x34,
    };

    const cipher_key = [4 * N_K]u8{
        0x2b, 0x7e, 0x15, 0x16, 0x28, 0xae, 0xd2, 0xa6, 0xab, 0xf7, 0x15, 0x88, 0x09, 0xcf, 0x4f,
        0x3c,
    };

    const cipher_bytes = [4 * N_B]u8{
        0x39, 0x25, 0x84, 0x1d, 0x02, 0xdc, 0x09, 0xfb, 0xdc, 0x11, 0x85, 0x97, 0x19, 0x6a, 0x0b,
        0x32,
    };

    const cipher = AESBlockCipher.new(cipher_key);

    const plain_text = cipher.inv_cipher_block(&cipher_bytes);

    try std.testing.expect(std.mem.eql(u8, &plain_text, &expected_plain_text));
}
