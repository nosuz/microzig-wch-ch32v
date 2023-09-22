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

    pub fn is_readable(port: Port) bool {
        return (port.get_regs().STATR.read().RXNE == 1);
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
