const microzig = @import("microzig");

const ch32v = microzig.hal;
const gpio = ch32v.gpio;
const clocks = ch32v.clocks;
const time = ch32v.time;

const clocks_config = clocks.Configuration{
    // .sysclk_src = clocks.Sysclk_src.HSE,
    // .hse_freq = 25_000_000,
    .sysclk_src = clocks.Sysclk_src.PLL,
    // .pll_src = clocks.Pll_src.HSI,
    .pll_src = clocks.Pll_src.HSI_div2,
    .pll_multiplex = clocks.Pll_multiplex.MUL_18,
    .ahb_prescale = clocks.Ahb_prescale.SYSCLK_2,
};

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
};

pub fn main() !void {
    clocks_config.apply();

    const pins = pin_config.apply();

    while (true) {
        pins.led.toggle();
        // time.sleep_ms(500);
        busyloop();
    }
}

fn busyloop() void {
    const limit = 500_000;

    var i: u32 = 0;
    while (i < limit) : (i += 1) {
        @import("std").mem.doNotOptimizeAway(i);
    }
}
