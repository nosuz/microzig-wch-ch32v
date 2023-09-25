const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const time = ch32v.time;
const serial = ch32v.serial;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
};

pub fn main() !void {
    const pins = pin_config.apply();

    const usart1 = serial.Port.USART1;
    usart1.apply(.{
        .baud_rate = 115200,
    });

    while (true) {
        _ = usart1.write("Hello world\r\n") catch 0;

        pins.led.toggle();
        time.sleep_ms(500);
    }
}
