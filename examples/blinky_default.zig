const microzig = @import("microzig");

const ch32v = microzig.hal;
const time = ch32v.time;

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
        .level = .high,
        // .level = .low,
    },
};

pub fn main() !void {
    const pins = pin_config.apply();

    time.sleep_ms(3000);

    while (true) {
        pins.led.toggle();
        time.sleep_ms(500);
    }
}