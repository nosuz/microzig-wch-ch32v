const std = @import("std");
const microzig = @import("microzig");

const cpu_types = enum {
    ch32v103,
    ch32v203,
};

pub const cpu_type: cpu_types = .ch32v103;

pub const pins = @import("hal_ch32v103/pins.zig");
pub const clocks = @import("hal_ch32v103/clocks.zig");
pub const time = @import("hal_ch32v103/time.zig");
pub const serial = @import("hal_ch32v103/serial.zig");
pub const adc = @import("hal_ch32v103/adc.zig");
pub const i2c = @import("hal_ch32v103/i2c.zig");
pub const interrupt = @import("hal_ch32v103/interrupt.zig");
pub const usbd = @import("hal_ch32v103/usbhd.zig");

pub const gpio = @import("hal/gpio.zig");
pub const spi = @import("hal/spi.zig");
pub const ring_buffer = @import("hal/ring_buffer.zig");
