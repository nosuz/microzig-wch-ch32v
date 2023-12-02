const std = @import("std");
const microzig = @import("microzig");
const ch32v = microzig.hal;
const pins = ch32v.pins;
const clocks = ch32v.clocks;
const time = ch32v.time;

const peripherals = microzig.chip.peripherals;

const UartRegs = microzig.chip.types.peripherals.USART1;
const USART1 = peripherals.USART1;
const USART2 = peripherals.USART2;
const USART3 = peripherals.USART3;

pub const Stop = enum {
    one,
    two,
};

pub const Parity = enum {
    none,
    even,
    odd,
};

pub const WordBits = enum {
    eight,
    seven,
};

pub fn SERIAL(comptime pin_name: []const u8) type {
    return struct {
        const pin = pins.parse_pin(pin_name);

        const WriteError = error{};
        const ReadError = error{};

        pub fn is_readable(self: @This()) bool {
            _ = self;
            return (pin.serial_port_regs.STATR.read().RXNE == 1);
        }

        pub inline fn read_word(self: @This()) u8 {
            const regs = pin.serial_port_regs;
            // while (!self.is_readable()) {}
            while (!self.is_readable()) {
                asm volatile ("" ::: "memory");
            }

            const char: u8 = @truncate(regs.DATAR.read().DR);

            // Clear RXNE
            regs.STATR.modify(.{
                .RXNE = 0,
            });

            return char;
        }

        pub inline fn is_writeable(self: @This()) bool {
            _ = self;
            return (pin.serial_port_regs.STATR.read().TXE == 1);
        }

        pub inline fn write(self: @This(), payload: []const u8) WriteError!usize {
            const regs = pin.serial_port_regs;
            for (payload) |byte| {
                // while (!self.is_writeable()) {}
                while (!self.is_writeable()) {
                    asm volatile ("" ::: "memory");
                }

                regs.DATAR.raw = byte;
            }

            return payload.len;
        }

        pub inline fn write_word(self: @This(), byte: u8) void {
            const regs = pin.serial_port_regs;
            while (!self.is_writeable()) {
                asm volatile ("" ::: "memory");
            }

            regs.DATAR.raw = byte;
        }

        pub inline fn get_port(self: @This()) Port {
            _ = self;
            return pin.serial_port;
        }
    };
}

pub const Port = enum {
    USART1,
    USART2,
    USART3,

    pub const Configuration = struct {
        setup: bool = false,

        baud_rate: u32 = 115200,
        word_bits: WordBits = WordBits.eight,
        stop: Stop = Stop.one,
        parity: Parity = Parity.none,
    };

    pub fn get_regs(port: Port) *volatile UartRegs {
        return switch (@intFromEnum(port)) {
            0 => USART1,
            1 => USART2,
            2 => USART3,
            else => unreachable,
        };
    }

    const WriteError = error{};
    // const ReadError = error{};

    pub const Writer = std.io.Writer(Port, WriteError, write);
    // pub const Reader = std.io.Reader(Port, ReadError, read);

    pub fn writer(port: Port) Writer {
        return .{ .context = port };
    }

    // pub fn reader(port: Port) Reader {
    //     return .{ .context = port };
    // }

    pub inline fn is_writeable(port: Port) bool {
        const regs = get_regs(port);
        return (regs.STATR.read().TXE == 1);
    }

    pub fn write(port: Port, payload: []const u8) WriteError!usize {
        const regs = get_regs(port);
        for (payload) |byte| {
            // while (!port.is_writeable()) {}
            while (!port.is_writeable()) {
                asm volatile ("" ::: "memory");
            }

            regs.DATAR.raw = byte;
        }

        return payload.len;
    }
};

pub const Configs = struct {
    pub var USART1 = Port.Configuration{};
    pub var USART2 = Port.Configuration{};
    pub var USART3 = Port.Configuration{};
};

// Logger
var uart_logger: ?Port.Writer = null;

pub fn init_logger(port: Port) void {
    const port_config = switch (port) {
        Port.USART1 => Configs.USART1,
        Port.USART2 => Configs.USART2,
        Port.USART3 => Configs.USART3,
    };
    // bind logger to serail port if configured.
    if (port_config.setup) {
        uart_logger = port.writer();
        uart_logger.?.writeAll("\r\n================ STARTING NEW LOGGER ================\r\n") catch {};
    }
}

pub fn log(
    // RTC required
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime "[{}.{:0>3}] " ++ level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (uart_logger) |uart| {
        const current_time = time.get_uptime();
        const seconds = current_time / 1000;
        const microseconds = current_time % 1000;

        uart.print(prefix ++ format ++ "\r\n", .{ seconds, microseconds } ++ args) catch {};
    }
}

pub fn log_no_timestamp(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (uart_logger) |uart| {
        uart.print(prefix ++ format ++ "\r\n", args) catch {};
    }
}
