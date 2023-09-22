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

// set logger
pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = ch32v.serial.log;
};

pub fn main() !void {
    const usart1 = serial.Port.USART1;
    usart1.apply(.{
        .baud_rate = 115200,
    });
    // start logger
    serial.init_logger(usart1);

    const pins = pin_config.apply();

    var i: u32 = 0;
    while (true) {
        std.log.debug("seq: {}", .{i});
        i += 1;
        // _ = usart1.write("Hello world\n") catch 0;

        pins.led.toggle();
        time.sleep_ms(500);
    }
}
