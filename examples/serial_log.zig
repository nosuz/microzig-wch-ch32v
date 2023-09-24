const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const time = ch32v.time;
const gpio = ch32v.gpio;
const serial = ch32v.serial;
const clocks = ch32v.clocks;

const clocks_config = clocks.Configuration{
    // .sysclk_src = clocks.Sysclk_src.HSE,
    // .hse_freq = 25_000_000,
    .pll_src = clocks.Pll_src.HSI,
    // .enable_rtc = false, // Disable RTC blocks log with timestam.
};

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
    // pub const logFn = ch32v.serial.log_no_timestamp;
};

pub fn main() !void {
    clocks_config.apply();

    const pins = pin_config.apply();

    const usart1 = serial.Port.USART1;
    usart1.apply(.{
        .baud_rate = 115200,
    });
    // start logger
    serial.init_logger(usart1);

    var i: u32 = 0;
    while (true) {
        std.log.debug("seq: {}", .{i});
        i += 1;
        // _ = usart1.write("Hello world\n") catch 0;

        pins.led.toggle();
        time.sleep_ms(500);
    }
}
