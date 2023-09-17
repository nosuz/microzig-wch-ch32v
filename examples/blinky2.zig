const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const gpio = ch32v.gpio;
// const time = ch32v.time;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
};

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
    const limit = 100_000;

    var i: u32 = 0;
    while (i < limit) : (i += 1) {
        @import("std").mem.doNotOptimizeAway(i);
    }
}
