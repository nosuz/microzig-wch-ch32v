const microzig = @import("microzig");

const ch32v = microzig.hal;
const time = ch32v.time;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "fixed",
        .direction = .out,
        .level = .high,
    },
    .PA6 = .{
        .name = "led",
        .direction = .out,
    },
};

pub fn main() !void {
    const pins = pin_config.apply();

    while (true) {
        pins.led.toggle();
        time.sleep_ms(500);
    }
}
