const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const time = ch32v.time;
const serial = ch32v.serial;
const usbhd = if (ch32v.cpu_type == .ch32v103) ch32v.usbhd else ch32v.usbfs;
const interrupt = ch32v.interrupt;

pub const usbd_class = if (ch32v.cpu_type == .ch32v103)
    @import("lib_ch32v103/hid_mouse.zig")
else
    @import("lib_ch32v203/usbfs_hid_mouse.zig");

pub const pin_config = if (ch32v.cpu_type == .ch32v103)
    ch32v.pins.GlobalConfiguration{
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
            .function = .USBHD,
            // .usbhd_speed = .Full_speed,
            // .usbhd_speed = .Low_speed, // default speed
            .usbhd_ep_num = 2,
            // .usbhd_buffer_size = .byte_8, // default buffer size
            // .usbhd_handle_sof = false, // genellary no need to handle SOF
        },
        // .PA12 = .{
        //     // Using for other than USBD will make error.
        //     .name = "dummy",
        //     .function = .GPIO,
        // },
    }
else
    ch32v.pins.GlobalConfiguration{
        .PA5 = .{
            .name = "led",
            .direction = .out,
            .level = .low,
        },
        .PA6 = .{
            .name = "triger",
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
        .PB6 = .{
            .name = "usb",
            .function = .USBFS,
            // .usbfs_speed = .Full_speed,
            // .usbfs_speed = .Low_speed, // default speed
            .usbfs_ep_num = 2,
            // .usbfs_buffer_size = .byte_8, // default buffer size
            // .usbfs_buffer_size = .byte_64,
            // .usbfs_handle_sof = false, // genellary no need to handle SOF
        },
        // .PB7 = .{
        //     // Using for other than USBFS will make error.
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
    pub const interrupts = if (ch32v.cpu_type == .ch32v103)
        struct {
            // CH32V103
            pub fn USBHD() void {
                usbhd.interrupt_handler();
            }
        }
    else
        struct {
            // CH32V203
            // pub fn OTG_FS() void {
            //     usbhd.interrupt_handler();
            // }
            pub fn TIM8_BRK() void {
                usbhd.interrupt_handler();
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

    pins.usb.init();
    interrupt.enable_interrupt();

    // const raise error: expected type '*rand.Xoshiro256', found '*const rand.Xoshiro256'
    var rand = std.rand.DefaultPrng.init(0);

    while (true) {
        time.sleep_ms(1000);
        pins.led.toggle();
        const x = rand.random().int(i8);
        const y = rand.random().int(i8);
        pins.usb.update(x, y);
    }
}
