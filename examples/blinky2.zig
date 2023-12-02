const microzig = @import("microzig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
};

// pub const __Clocks_freq = clocks_config.get_freqs();
pub const __Clocks_freq = clocks.Default_clocks_freq();

pub fn main() !void {
    const pins = pin_config.apply();

    while (true) {
        pins.led.toggle();
        busyloop();

        // var val = pins.led.read();
        // switch (val) {
        //     0 => pins.led.put(1),
        //     1 => pins.led.put(0),
        // }

        // // time.sleep_ms(250);
        // busyloop();
    }
}

fn busyloop() void {
    const limit = 500_000;

    var i: u32 = 0;
    while (i < limit) : (i += 1) {
        asm volatile ("" ::: "memory");
    }
}
