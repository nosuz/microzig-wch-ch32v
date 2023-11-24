const std = @import("std");

pub fn RingBuffer(comptime id: usize, comptime T: type, comptime length: usize) type {
    // FIXME: want to remove specifying id.
    _ = id;
    if (length < 2) {
        @compileError("buffer size should mimimam 2.");
    }

    return struct {
        const Self = @This();

        var buffer: [length]T = undefined;
        var write_pos: usize = 0;
        var read_pos: usize = 0;
        var full: bool = false;
        var mutex = std.Thread.Mutex{};

        fn next_pos(pos: usize) usize {
            return (pos + 1) % length;
        }

        pub fn write(self: Self, value: T) !void {
            _ = self;

            // mutex.lock();
            // defer mutex.unlock();
            if (mutex.tryLock()) {
                defer mutex.unlock();

                if ((write_pos == read_pos) and full) {
                    return error.Full;
                }

                buffer[write_pos] = value;

                write_pos = next_pos(write_pos);
                full = (write_pos == read_pos);
            } else {
                return error.Lock;
            }
        }

        pub fn read(self: Self) !T {
            _ = self;

            // mutex.lock();
            // defer mutex.unlock();
            if (mutex.tryLock()) {
                defer mutex.unlock();

                if ((write_pos == read_pos) and !full) {
                    return error.Empty;
                }

                const value = buffer[read_pos];

                read_pos = next_pos(read_pos);
                full = false;

                return value;
            } else {
                return error.Lock;
            }
        }

        pub fn is_empty(self: Self) bool {
            _ = self;
            return ((write_pos == read_pos) and !full);
        }

        pub fn is_full(self: Self) bool {
            _ = self;
            return ((write_pos == read_pos) and full);
        }

        pub fn write_block(self: Self, value: T) void {
            // busy wait untile writeable.
            while (self.is_full()) {
                asm volatile ("" ::: "memory");
            }
            // push data into buffer. must no error.
            self.write(value) catch {};
        }
    };
}
