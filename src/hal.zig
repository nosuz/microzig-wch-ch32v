const std = @import("std");
const microzig = @import("microzig");

pub const gpio = @import("hal/gpio.zig");
pub const pins = @import("hal/pins.zig");
pub const clocks = @import("hal/clocks.zig");
pub const time = @import("hal/time.zig");
pub const serial = @import("hal/serial.zig");
pub const adc = @import("hal/adc.zig");
pub const i2c = @import("hal/i2c.zig");
pub const spi = @import("hal/spi.zig");
pub const interrupt = @import("hal/interrupt.zig");
