const std = @import("std");
const microzig = @import("microzig");
const ch32v = microzig.hal;
const pins = ch32v.pins;
const clocks = ch32v.clocks;

const peripherals = microzig.chip.peripherals;

const USART1 = peripherals.USART1;
const USART2 = peripherals.USART2;
const USART3 = peripherals.USART3;
const UART4 = peripherals.UART4;

const UartRegs = microzig.chip.types.peripherals.USART1;

pub const Stop = enum {
    ONE,
    TWO,
};

pub const Parity = enum {
    NONE,
    EVEN,
    ODD,
};

pub const WordBits = enum {
    EIGHT,
    SEVEN,
};

pub const Config = struct {
    baud_rate: u32,
    word_bits: WordBits = WordBits.EIGHT,
    stop: Stop = Stop.ONE,
    parity: Parity = Parity.NONE,
};

pub const Port = enum {
    USART1,
    USART2,
    USART3,
    UART4,

    fn get_regs(port: Port) *volatile UartRegs {
        return switch (@intFromEnum(port)) {
            0 => USART1,
            1 => USART2,
            2 => USART3,
            3 => UART4,
        };
    }

    pub fn apply(port: Port, comptime config: Config) void {
        switch (@intFromEnum(port)) {
            // UART1
            0 => {
                peripherals.RCC.APB2PCENR.modify(.{
                    .USART1EN = 1,
                });
            },
            // UART2
            1 => {
                peripherals.RCC.APB1PCENR.modify(.{
                    .USART2EN = 1,
                });
            },
            else => {},
        }

        pins.setup_uart_pins(port);

        const regs = get_regs(port);

        if (config.baud_rate == 0) @compileError("Baud rate should greater than 0.");
        regs.BRR.write_raw(clocks.Clocks_freq.pclk2 / config.baud_rate);

        // Enable USART, Tx, and Rx
        regs.CTLR1.modify(.{
            .UE = 1,
            .TE = 1,
            .RE = 1,
        });
    }

    const WriteError = error{};
    const ReadError = error{};

    pub const Writer = std.io.Writer(Port, WriteError, write);
    pub const Reader = std.io.Reader(Port, ReadError, read);

    pub fn writer(port: Port) Writer {
        return .{ .context = port };
    }

    pub fn reader(port: Port) Reader {
        return .{ .context = port };
    }

    pub fn is_readable(port: Port) bool {
        return (port.get_regs().STATR.read().RXNE == 1);
    }

    pub fn read(port: Port, buffer: []u8) ReadError!usize {
        const regs = port.get_regs();
        for (buffer) |*byte| {
            // while (!port.is_readable()) {}
            var i: u32 = 0;
            while (!port.is_read_able()) : (i += 1) {
                @import("std").mem.doNotOptimizeAway(i);
            }

            byte.* = regs.UARTDR.read().DATA;
        }
        return buffer.len;
    }

    pub fn read_word(port: Port) u8 {
        const regs = port.get_regs();
        // while (!port.is_readable()) {}
        var i: u32 = 0;
        while (!port.is_read_able()) : (i += 1) {
            @import("std").mem.doNotOptimizeAway(i);
        }

        return regs.DATAR.read().DATA;
    }

    pub fn is_writeable(port: Port) bool {
        return (port.get_regs().STATR.read().TXE == 1);
    }

    pub fn write(port: Port, payload: []const u8) WriteError!usize {
        const regs = port.get_regs();
        for (payload) |byte| {
            // while (!port.is_writeable()) {}
            var i: u32 = 0;
            while (!port.is_writeable()) : (i += 1) {
                @import("std").mem.doNotOptimizeAway(i);
            }

            regs.DATAR.raw = byte;
        }

        return payload.len;
    }
};

// Logger
var uart_logger: ?Port.Writer = null;

pub fn init_logger(port: Port) void {
    // bind logger to serail port.
    uart_logger = port.writer();
    uart_logger.?.writeAll("\r\n================ STARTING NEW LOGGER ================\r\n") catch {};
}

pub fn log(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    // const level_prefix = comptime "[{}.{:0>6}] " ++ level.asText();
    const level_prefix = comptime level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (uart_logger) |uart| {
        // TODO: use RTC for log time.
        // const current_time = time.get_time_since_boot();
        // const seconds = current_time.to_us() / std.time.us_per_s;
        // const microseconds = current_time.to_us() % std.time.us_per_s;

        // uart.print(prefix ++ format ++ "\r\n", .{ seconds, microseconds } ++ args) catch {};

        uart.print(prefix ++ format ++ "\r\n", args) catch {};
        // uart.writeAll("-") catch {};
    }
}
