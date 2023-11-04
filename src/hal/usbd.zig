const std = @import("std");
const microzig = @import("microzig");
const mmio = microzig.mmio;

const ch32v = microzig.hal;
const pins = ch32v.pins;
const clocks = ch32v.clocks;

const peripherals = microzig.chip.peripherals;
const RCC = peripherals.RCC;
const regs = peripherals.USB;

pub const SRAM_BASE = 0x4000_6000;

pub const Speed = enum(u1) {
    Full_speed = 0,
    Low_speed = 1,
};

pub const Configuration = struct {
    setup: bool = false,

    speed: Speed = Speed.Full_speed,
};

pub fn USBD() type {
    return struct {
        const UsbdError = error{
            PllFreqError,
        };

        pub inline fn init_clocks(self: @This()) UsbdError!void {
            _ = self;

            switch (clocks.Clocks_freq.pllclk) {
                48_000_000 => {
                    RCC.CFGR0.modify(.{
                        .USBPRE = 0b00,
                    });
                },
                96_000_000 => {
                    RCC.CFGR0.modify(.{
                        .USBPRE = 0b01,
                    });
                },
                144_000_000 => {
                    RCC.CFGR0.modify(.{
                        .USBPRE = 0b10,
                    });
                },
                else => return UsbdError.PllFreqError, // PLL freq must 48, 96, or 144 MHz.
            }
        }
    };
}
