// Ref.
// Arduino UNO を使って ASCIIART（マンデルブロ集合）ベンチマークを実行
// http://radiopench.blog96.fc2.com/blog-entry-1121.html
//
// MCS BASIC52でマンデルブロ集合ベンチマーク
// https://www.protom.org/micon/0113

const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
const serial = ch32v.serial;

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
};

const clocks_config = clocks.Configuration{
    // .sysclk_src = .HSI, // 8MHz
    .sysclk_src = .PLL,
    .pll_src = .HSI,
    .pll_multiplex = .MUL_4, // 32 MHz
    // FIXME: 40MHz not work.
    // .pll_multiplex = .MUL_5, // 40 MHz
    // .pll_multiplex = .MUL_12, // 96 MHz
    // .ahb_prescale = .SYSCLK_2,
};

pub const __Clocks_freq = clocks_config.get_freqs();
// pub const __Clocks_freq = clocks.Default_clocks_freq();

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
    std.log.debug("seq:", .{});

    for (0..2) |j| {
        std.log.debug("start: {}", .{j});
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
                    pins.tx.write_word(' ');
                    // 140 GOTO 210
                } else {
                    // 200 IF I>9 THEN I=I+7
                    if (i > 9) i += 7;
                    // 205 PRINT CHR(48+I),
                    pins.tx.write_word(48 + i);
                }
                // 210 NEXT X
                x += 1;
            }
            // 220 PRINT
            _ = pins.tx.write("\r\n") catch 0;
            // 230 NEXT Y
            y += 1;
        }
        std.log.debug("end: {}", .{j});
    }

    // halt
    while (true) {
        asm volatile ("" ::: "memory");
    }
}
