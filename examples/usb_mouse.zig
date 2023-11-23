const std = @import("std");
const microzig = @import("microzig");
const usb = @import("usb/hid_mouse/usbd.zig");
const mouse = @import("usb/hid_mouse/mouse.zig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const time = ch32v.time;
const serial = ch32v.serial;
const interrupt = ch32v.interrupt;

pub const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
        .level = .low,
    },
    .PA9 = .{
        .name = "tx",
        .function = .SERIAL,
        .baud_rate = 115200,
    },
    // .PA10 = .{
    //     // .name = "rx",
    //     .function = .SERIAL,
    // },
    .PA11 = .{
        .name = "usb",
        .function = .USBD,
        // .usbd_speed = .Full_speed,
        .usbd_speed = .Low_speed,
    },
    // .PA12 = .{
    //     // Using for other than USBD will make error.
    //     .name = "dummy",
    //     .function = .GPIO,
    // },
};

const clocks_config = clocks.Configuration{
    // supply 48 MHz from PLL
    // .sysclk_src = .HSI,
    .sysclk_src = .PLL,
    .pll_src = .HSI, // 8MHz
    .pll_multiplex = .MUL_6, // 48 MHz
    // .pll_multiplex = .MUL_12, // 96 MHz
    // .ahb_prescale = .SYSCLK_2, // sysclk / 2

    // .enable_rtc = false, // Disable RTC blocks log with timestamp.
};

pub const __Clocks_freq = clocks_config.get_freqs();
// pub const __Clocks_freq = clocks.Default_clocks_freq();

// Set interrupt handlers
pub const microzig_options = struct {
    pub const interrupts = struct {
        pub fn USB_LP_CAN1_RX0() void {
            usb.usbd_handler();
        }
    };
};

// set logger
pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = serial.log;
    // pub const logFn = ch32v.serial.log_no_timestamp;
};

pub fn main() !void {
    clocks_config.apply();

    const pins = pin_config.apply();

    // start logger
    serial.init_logger(pins.tx.get_port());

    usb.init();
    interrupt.enable_interrupt();

    // const raise error: expected type '*rand.Xoshiro256', found '*const rand.Xoshiro256'
    var rand = std.rand.DefaultPrng.init(0);

    while (true) {
        time.sleep_ms(1000);
        // pins.led.toggle();
        const x = rand.random().int(i8);
        const y = rand.random().int(i8);
        mouse.update(x, y);
    }
}