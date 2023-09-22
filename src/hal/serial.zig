const microzig = @import("microzig");
const ch32v = microzig.hal;
const pins = ch32v.pins;
const rcc = ch32v.rcc;

const peripherals = microzig.chip.peripherals;

const UART1 = peripherals.USART1;
const UART2 = peripherals.USART2;
const UART3 = peripherals.USART3;
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

pub const UART = enum {
    PORT1,
    PORT2,
    PORT3,
    PORT4,

    fn get_regs(uart: UART) *volatile UartRegs {
        return switch (@intFromEnum(uart)) {
            0 => UART1,
            1 => UART2,
            2 => UART3,
            3 => UART4,
        };
    }

    pub fn apply(uart: UART, comptime config: Config) void {
        switch (@intFromEnum(uart)) {
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

        pins.setup_uart_pins(uart);

        const regs = get_regs(uart);

        if (config.baud_rate == 0) @compileError("Baud rate should greater than 0.");
        regs.BRR.write_raw(rcc.Clocks.pclk2_freq / config.baud_rate);

        // Enable USART, Tx, and Rx
        regs.CTLR1.modify(.{
            .UE = 1,
            .TE = 1,
            .RE = 1,
        });
    }

    const WriteError = error{};
    const ReadError = error{};

    pub fn is_readable(uart: UART) bool {
        return (uart.get_regs().STATR.read().RXNE == 1);
    }

    pub fn is_writeable(uart: UART) bool {
        return (uart.get_regs().STATR.read().TXE == 1);
    }

    pub fn write(uart: UART, payload: []const u8) WriteError!usize {
        const regs = uart.get_regs();
        for (payload) |byte| {
            // while (!uart.is_writeable()) {}
            var i: u32 = 0;
            while (!uart.is_writeable()) : (i += 1) {
                @import("std").mem.doNotOptimizeAway(i);
            }

            regs.DATAR.raw = byte;
        }

        return payload.len;
    }
};
