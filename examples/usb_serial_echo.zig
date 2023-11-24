const std = @import("std");
const microzig = @import("microzig");

const usb = @import("usb/cdc_acm/usbd.zig");
const usb_serial = @import("usb/cdc_acm/serial.zig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const time = ch32v.time;
const serial = ch32v.serial;
const interrupt = ch32v.interrupt;

pub const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
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
        // .usbd_speed = .Full_speed, // use SOF instead of timer
        .usbd_speed = .Low_speed, // no BULK transfer; for debugging
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
    pub const interrupts = struct {
        pub fn USB_LP_CAN1_RX0() void {
            usb.usbd_handler();
        }
        pub fn TIM1_UP() void {
            tim1_up_handler();
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

    usb.init();
    setup_timer();
    interrupt.enable_interrupt();

    // start logger
    serial.init_logger(pins.tx.get_port());

    while (true) {
        // echo recieved data
        const chr = usb_serial.Rx_Buffer.read_block();
        // usb_serial.Tx_Buffer.write_block(chr);
        for (0..10) |_| {
            usb_serial.Tx_Buffer.write_block(chr);
        }
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
    PFIC.IPRR2.write_raw(1 << (@intFromEnum(interrupt.Interrupts_ch32v203.TIM1_UP) - 32)); // TIM1_UP = 41

    // enable interrupt on Update.
    TIM1.DMAINTENR.modify(.{
        .UIE = 1,
    });
    // enable interrupts
    var ienr = PFIC.IENR2.read().INTEN;
    ienr |= 1 << (@intFromEnum(interrupt.Interrupts_ch32v203.TIM1_UP) - 32);
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
    usb_serial.start_tx();
}
