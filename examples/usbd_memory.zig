const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const time = ch32v.time;
const serial = ch32v.serial;
const usbd = if (ch32v.cpu_type == .ch32v103) ch32v.usbhd else ch32v.usbd;
const interrupt = ch32v.interrupt;

pub const BUFFER_SIZE = usbd.BUFFER_SIZE;

pub const usbd_class = if (ch32v.cpu_type == .ch32v103)
    @import("lib_ch32v103/usbd_msc_sd.zig")
else
    @import("lib_ch32v203/usbd_msc_sd.zig");

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
            .usbhd_ep_num = 3,
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
        .PA11 = .{
            .name = "usb",
            .function = .USBD,
            // .usbd_speed = .Full_speed,
            .usbd_speed = .Low_speed, // default speed
            .usbd_ep_num = 3,
            // .usbd_buffer_size = .byte_8, // default buffer size
            // .usbd_handle_sof = false, // genellary no need to handle SOF
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
    pub const interrupts = if (ch32v.cpu_type == .ch32v103)
        struct {
            // CH32V103
            pub fn USBHD() void {
                usbd.interrupt_handler();
            }
        }
    else
        struct {
            // CH32V203
            pub fn USB_LP_CAN1_RX0() void {
                usbd.interrupt_handler();
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

    while (true) {
        time.sleep_ms(1000);
        pins.led.toggle();
    }
}
