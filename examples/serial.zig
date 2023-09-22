const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const time = ch32v.time;
const gpio = ch32v.gpio;
// const rcc = ch32v.rcc;
const serial = ch32v.serial;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
};

pub fn main() !void {
    const serial1 = serial.UART.PORT1;
    serial1.apply(.{
        .baud_rate = 115200,
    });

    const pins = pin_config.apply();

    while (true) {
        _ = serial1.write("Hello world\n") catch 0;
        pins.led.toggle();
        time.sleep_ms(500);
    }
}
