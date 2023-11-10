const microzig = @import("microzig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const pins = ch32v.pins;
const time = ch32v.time;
const interrupt = ch32v.interrupt;
const rb = ch32v.ring_buffer;

const peripherals = microzig.chip.peripherals;

const Capacity = 16;
const RingBuf = rb.RingBuffer(u8, Capacity){};

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
    .PA6 = .{
        .name = "sig",
        .direction = .out,
    },
    .PA9 = .{
        .name = "tx",
        .function = .SERIAL,
        .baud_rate = 115200,
    },
    // .PA10 = .{
    //     .name = "rx",
    //     .function = .SERIAL,
    // },
};

// pub const __Clocks_freq = clocks_config.get_freqs();
pub const __Clocks_freq = clocks.Default_clocks_freq();

var byte: u8 = 0;

pub fn main() !void {
    const pin = pin_config.apply();

    setup_timer();
    interrupt.enable_interrupt();

    pin.sig.toggle();
    while (true) {
        time.sleep_ms(1000);
        pin.sig.toggle();

        while (true) {
            if (RingBuf.read()) |char| {
                pin.tx.write_word(char);
            } else |err| switch (err) {
                error.Empty => {
                    _ = pin.tx.write("\r\n") catch 0;
                    break;
                },
                error.Lock => {
                    _ = pin.tx.write(" -- Locked -- ") catch 0;
                },
            }
        }
    }
}

fn setup_timer() void {
    const RCC = peripherals.RCC;
    const TIM1 = peripherals.TIM1;
    const PFIC = peripherals.PFIC;

    RCC.APB2PCENR.modify(.{
        .TIM1EN = 1,
    });

    const prescale = __Clocks_freq.pclk2 / 1_000_000 * 100 - 1; // count update every 0.1ms.
    TIM1.PSC.write_raw(prescale);

    const count = 1000; // 0.1ms * 1000 = 100ms
    TIM1.CNT.write_raw(count);
    TIM1.ATRLR.write_raw(count);
    TIM1.CTLR1.modify(.{
        .ARPE = 1,
        .CEN = 1,
    });

    // clear interupt requist by the above counter update
    TIM1.INTFR.modify(.{
        .UIF = 0,
    });
    PFIC.IPRR2.write_raw(1 << (@intFromEnum(interrupt.Interrupts_ch32v203.TIM1_UP) - 32)); // TIM1_UP = 41

    // enable interrupt on Update.
    TIM1.DMAINTENR.modify(.{
        .UIE = 1,
    });
    // enable interrupts
    var ienr = PFIC.IENR2.read().INTEN;
    ienr |= 1 << (@intFromEnum(interrupt.Interrupts_ch32v203.TIM1_UP) - 32);
    PFIC.IENR2.write_raw(ienr);
}

fn tim1_up_handler() void {
    // clear timer interrupt flag. Or trigered again and again.
    const TIM1 = peripherals.TIM1;

    TIM1.INTFR.modify(.{
        .UIF = 0,
    });

    const pin = pins.get_pins(pin_config);
    pin.led.toggle();

    // ignore error
    // RingBuf.write('@') catch {};
    RingBuf.write(byte + 0x20) catch {};
    byte = (byte + 1) % (0x5F); // ' ' to '~'
    // Should I separate the buffer for communication and pusshing data?
}

// Set interrupt handlers
pub const microzig_options = struct {
    pub const interrupts = struct {
        pub fn TIM1_UP() void {
            tim1_up_handler();
        }
    };
};
