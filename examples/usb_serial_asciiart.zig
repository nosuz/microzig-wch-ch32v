// Ref.
// Arduino UNO を使って ASCIIART（マンデルブロ集合）ベンチマークを実行
// http://radiopench.blog96.fc2.com/blog-entry-1121.html
//
// MCS BASIC52でマンデルブロ集合ベンチマーク
// https://www.protom.org/micon/0113

const std = @import("std");
const microzig = @import("microzig");

const usb = @import("usb/cdc_acm/usbd.zig");
const usb_serial = @import("usb/cdc_acm/serial.zig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const interrupt = ch32v.interrupt;
const time = ch32v.time;

pub const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        .direction = .out,
        .level = .low,
    },
    .PA11 = .{
        .name = "usb",
        .function = .USBD,
        .usbd_speed = .Full_speed, // use SOF instead of timer
        // .usbd_speed = .Low_speed, // no BULK transfer; for debugging
    },
};

const clocks_config = clocks.Configuration{
    // .sysclk_src = .HSI, // 8MHz
    .sysclk_src = .PLL,
    .pll_src = .HSI,
    // .pll_multiplex = .MUL_6, // 48 MHz
    // .pll_multiplex = .MUL_12, // 96 MHz
    .pll_multiplex = .MUL_18, // 144 MHz
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
    pub const logFn = usb_serial.log;
    // pub const logFn = ch32v.serial.log_no_timestamp;
};

pub fn main() !void {
    clocks_config.apply();

    const pins = pin_config.apply();

    usb.init();
    interrupt.enable_interrupt();

    // start logger
    while (!usb_serial.is_connected()) {
        asm volatile ("" ::: "memory");
    }
    time.sleep_ms(500);
    pins.led.toggle();
    std.log.debug("seq:", .{});

    while (true) {
        for (0..20) |j| {
            std.log.debug("start: {}", .{j});
            const time_start = time.get_uptime();
            // 10 FOR Y=-12 TO 12
            var y: f32 = -12;
            while (y <= 12) {
                // 20 FOR X=-39 TO 39
                var x: f32 = -39;
                while (x <= 39) {
                    // 30 CA=X*0.0458
                    var ca: f32 = x * 0.0458;
                    // 40 CB= Y*0.08333
                    var cb: f32 = y * 0.08333;
                    // 50 A=CA
                    var a: f32 = ca;
                    // 60 B=CB
                    var b: f32 = cb;
                    // 65 I=0
                    var i: u8 = 0;
                    // 70 DO
                    while (i <= 15) {
                        // 80 T=A*A-B*B+CA
                        var t: f32 = a * a - b * b + ca;
                        // 90 B=2*A*B+CB
                        b = 2 * a * b + cb;
                        // 100 A=T
                        a = t;
                        // 110 IF (A*A+B*B)>4 THEN GOTO 200
                        if ((a * a + b * b) > 4) break;
                        // 120 I=I+1 : WHILE I < 16
                        i += 1;
                    }
                    if (i > 15) {
                        // 130 PRINT " ",
                        usb_serial.write(' ');
                        // 140 GOTO 210
                    } else {
                        // 200 IF I>9 THEN I=I+7
                        if (i > 9) i += 7;
                        // 205 PRINT CHR(48+I),
                        usb_serial.write(48 + i);
                    }
                    // 210 NEXT X
                    x += 1;
                }
                // 220 PRINT
                usb_serial.write('\r');
                usb_serial.write('\n');
                // 230 NEXT Y
                y += 1;
            }
            const delta = time.get_uptime() - time_start;
            std.log.debug("end: {}", .{j});
            std.log.debug("delta: {} ms", .{delta});
        }
        pins.led.toggle();

        // wait until any key
        _ = usb_serial.read();
    }

    // // halt
    // while (true) {
    //     asm volatile ("" ::: "memory");
    // }
}
