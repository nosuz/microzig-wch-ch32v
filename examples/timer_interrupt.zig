const microzig = @import("microzig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const pins = ch32v.pins;
const time = ch32v.time;
const interrupt = ch32v.interrupt;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
};

// pub const __Clocks_freq = clocks_config.get_freqs();
pub const __Clocks_freq = clocks.Default_clocks_freq();

pub fn main() !void {
    // _ = pin_config.apply();
    const pin = pin_config.apply();

    setup_timer();

    while (true) {
        // microzig.cpu.enable_interrupt();
        interrupt.enable_interrupt();
        time.sleep_ms(1000);
        // microzig.cpu.disable_interrupt();
        interrupt.disable_interrupt();
        time.sleep_ms(1000);
        pin.led.toggle();
        time.sleep_ms(1000);
    }
}

fn setup_timer() void {
    const peripherals = microzig.chip.peripherals;
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
    PFIC.IPRR2.write_raw(1 << (@intFromEnum(interrupt.Interrupts.TIM1_UP) - 32)); // TIM1_UP = 41

    // enable interrupt on Update.
    TIM1.DMAINTENR.modify(.{
        .UIE = 1,
    });
    // enable interrupts
    var ienr = PFIC.IENR2.read().INTEN;
    ienr |= 1 << (@intFromEnum(interrupt.Interrupts.TIM1_UP) - 32);
    PFIC.IENR2.write_raw(ienr);
}

fn tim1_up_handler() void {
    // clear timer interrupt flag
    const peripherals = microzig.chip.peripherals;
    const TIM1 = peripherals.TIM1;

    TIM1.INTFR.modify(.{
        .UIF = 0,
    });

    const pin = pins.get_pins(pin_config);
    pin.led.toggle();
}

// Set interrupt handlers
pub const microzig_options = struct {
    pub const interrupts = struct {
        pub fn TIM1_UP() void {
            tim1_up_handler();
        }
    };
};
