const std = @import("std");
const Queue = @import("queue.zig").Queue;
const Message = @import("message.zig").Message;
const c = @import("../constants.zig");
const AESBlockCipher = @import("../aes_block_cipher.zig").AESBlockCipher;

const Block = [4 * c.N_B]u8;

pub fn Worker(comptime R: type, comptime S: type) type {
    return struct {
        input_queue: *Queue(Message(R)),
        result_queue: *Queue(Message(S)),
        aes_block_cipher: AESBlockCipher,
        maybe_encrypt: bool,

        const Self = @This();

        pub fn init(input_queue: *Queue(Message(R)), result_queue: *Queue(Message(S)), maybe_encrypt: bool) Self {
            return Self{
                .input_queue = input_queue,
                .result_queue = result_queue,
                .aes_block_cipher = AESBlockCipher.new_u128(0x2b7e151628aed2a6abf7158809cf4f3c),
                .maybe_encrypt = maybe_encrypt,
            };
        }

        pub fn run(self: *Self) !void {
            while (true) {
                var message = self.input_queue.pop();

                if (message.is_eof()) {
                    break;
                }

                // const result = (self.work_fn)(message.data);

                const result = switch (self.maybe_encrypt) {
                    true => self.encrypt(message.data),
                    false => self.decrypt(message.data),
                };

                message.data = result;
                try self.result_queue.push(message);
            }
        }

        pub fn encrypt(self: *Self, block: Block) Block {
            return self.aes_block_cipher.cipher_block(&block);
        }

        pub fn decrypt(self: *Self, block: Block) Block {
            return self.aes_block_cipher.inv_cipher_block(&block);
        }
    };
}

pub fn worker_loop(comptime R: type, comptime S: type, worker: *Worker(R, S)) !void {
    return worker.run();
}

pub fn initiate_worker(comptime R: type, comptime S: type, worker: *Worker(R, S)) !std.Thread {
    return std.Thread.spawn(.{}, worker_loop, .{ R, S, worker });
}
