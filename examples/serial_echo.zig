const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const time = ch32v.time;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
    .PA9 = .{
        .name = "tx",
        .function = .SERIAL,
    },
    .PA10 = .{
        // .name = "rx",
        .function = .SERIAL,
        .baud_rate = 115200,
    },
};

pub fn main() !void {
    const pins = pin_config.apply();

    while (true) {
        const char = pins.tx.read_word();
        pins.tx.write_word(char);
        pins.led.toggle();
    }
}
