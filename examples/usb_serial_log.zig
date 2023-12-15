const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const time = ch32v.time;
const usbd = ch32v.usbd;
const interrupt = ch32v.interrupt;

// variable name is fixed for usb device class
pub const usbd_class = if (ch32v.cpu_type == .ch32v103)
    @import("lib_ch32v103/cdc_acm.zig")
else
    @import("lib_ch32v203/cdc_acm.zig");

pub const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
    },
    .PA11 = .{
        .name = "usb",
        .function = .USBD,
        .usbd_speed = .Full_speed, // use SOF instead of timer
        // .usbd_speed = .Low_speed, // no BULK transfer; for debugging
        .usbd_ep_num = 4,
        // .usbd_buffer_size = .byte_64,
        .usbd_handle_sof = true,
    },
};

const clocks_config = clocks.Configuration{
    // .sysclk_src = .HSI,
    .sysclk_src = .PLL,
    // supply 48 MHz from PLL
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
            pub fn TIM1_UP() void {
                tim1_up_handler();
            }
        }
    else
        struct {
            // CH32V203
            pub fn USB_LP_CAN1_RX0() void {
                usbd.interrupt_handler();
            }
            pub fn TIM1_UP() void {
                tim1_up_handler();
            }
        };
};

// set logger
pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = usbd_class.log;
    // pub const logFn = ch32v.serial.log_no_timestamp;
};

pub fn main() !void {
    clocks_config.apply();

    const ios = pin_config.apply();

    ios.usb.init();
    // setup_timer(); // low-speed has no SOF packet.
    interrupt.enable_interrupt();

    const count = 10000;
    var i: u32 = 0;
    while (true) {
        time.sleep_ms(500);
        ios.led.toggle();

        std.log.debug("start seq: {}", .{i});
        const time_start = time.get_uptime();
        for (0..count) |_| {
            ios.usb.write('@');
        }
        ios.usb.write('\r');
        ios.usb.write('\n');
        const delta = time.get_uptime() - time_start;
        std.log.debug("finish seq: {}", .{i});
        std.log.debug("count: {} bytes", .{count});
        std.log.debug("delta: {} ms", .{delta});
        // makes really large binary
        // const speed: f32 = count / @as(f32, @floatFromInt(delta)) / 1000;
        // std.log.debug("speed: {d:.1} byte/sec", .{speed});
        i += 1;
    }
}

fn setup_timer() void {
    const peripherals = microzig.chip.peripherals;
    const RCC = peripherals.RCC;
    const TIM1 = peripherals.TIM1;
    const PFIC = peripherals.PFIC;

    RCC.APB2PCENR.modify(.{
        .TIM1EN = 1,
    });

    const prescale = __Clocks_freq.pclk2 / 1_000_000 * 100 - 1; // count update every 0.1ms.
    TIM1.PSC.write_raw(prescale);

    const count = 100; // 0.1ms * 100 = 10ms
    TIM1.CNT.write_raw(count);
    TIM1.ATRLR.write_raw(count);
    TIM1.CTLR1.modify(.{
        .ARPE = 1,
        .CEN = 1,
    });

    // clear interupt requist by the above counter update
    TIM1.INTFR.modify(.{
        .UIF = 0,
    });
    PFIC.IPRR2.write_raw(1 << (@intFromEnum(interrupt.Interrupts.TIM1_UP) - 32)); // TIM1_UP = 41

    // enable interrupt on Update.
    TIM1.DMAINTENR.modify(.{
        .UIE = 1,
    });
    // enable interrupts
    var ienr = PFIC.IENR2.read().INTEN;
    ienr |= 1 << (@intFromEnum(interrupt.Interrupts.TIM1_UP) - 32);
    PFIC.IENR2.write_raw(ienr);
}

fn tim1_up_handler() void {
    // clear timer interrupt flag
    const peripherals = microzig.chip.peripherals;
    const TIM1 = peripherals.TIM1;

    TIM1.INTFR.modify(.{
        .UIF = 0,
    });

    // triger Tx
    usbd_class.start_tx();
}
