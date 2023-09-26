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

// var pin: pins.Pins(pin_config) = undefined;
// const pin = pins.get_pins(pin_config);

pub fn main() !void {
    // _ = pin_config.apply();
    const pin = pin_config.apply();

    setup_timer();

    while (true) {
        interrupt.enable_interrupt();
        time.sleep_ms(1000);
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

    const prescale = clocks.Clocks_freq.pclk2 / 1_000_000 * 100 - 1; // count update every 0.1ms.
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

export fn interrupts_handler(mcause: u32) void {
    switch (@as(interrupt.Interrupts_ch32v203, @enumFromInt(mcause))) {
        interrupt.Interrupts_ch32v203.TIM1_UP => {
            // clear timer interrupt flag
            const peripherals = microzig.chip.peripherals;
            const TIM1 = peripherals.TIM1;

            TIM1.INTFR.modify(.{
                .UIF = 0,
            });

            const pin = pins.get_pins(pin_config);
            pin.led.toggle();
        },
        else => {},
    }
}
