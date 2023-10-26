const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const time = ch32v.time;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
    .PB6 = .{
        .name = "led2",
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

pub fn main() !void {
    const pins = pin_config.apply();

    while (true) {
        _ = pins.tx.write("Hello world\r\n") catch 0;
        // pins.tx.write_word('@');

        pins.led.toggle();
        pins.led2.toggle();
        time.sleep_ms(500);
    }
}
