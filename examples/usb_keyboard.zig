const std = @import("std");
const microzig = @import("microzig");
const usb = @import("usb/hid_keyboard/usbd.zig");
const keyboard = @import("usb/hid_keyboard/keyboard.zig");

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
    .sysclk_src = .HSI,
    // .sysclk_src = .PLL,
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
    pins.led.toggle();

    // const raise error: expected type '*rand.Xoshiro256', found '*const rand.Xoshiro256'
    // var rand = std.rand.DefaultPrng.init(0);

    // this sleep is mandetoly. short will loose some key-types.
    time.sleep_ms(1000);
    const command = "cat > /dev/null\n";
    for (0..command.len) |i| {
        pins.led.toggle();
        type_keyboard(command[i]);
    }
    time.sleep_ms(500);
    // while (true) {
    //     for (0..20) |_| {
    //         // pins.led.toggle();
    //         const chr = rand.random().int(u8) & 0x7f;
    //         type_keyboard(chr);
    //         // time.sleep_ms(100);
    //     }

    //     type_keyboard('\n');
    // }

    //  Draw ASCIIART
    type_mandelbrot();

    // set Ctrl-D
    // press key
    var ctrl_d = keyboard.ascii_to_usb_keycode('d').?;
    ctrl_d.modifier.left_ctrl = 1;
    keyboard.send_keycodes(ctrl_d);
    // release key
    keyboard.send_keycodes(keyboard.KeyboardData{});

    // halt
    while (true) {
        asm volatile ("" ::: "memory");
    }
}

fn type_keyboard(code: u8) void {
    if (keyboard.ascii_to_usb_keycode(code)) |key_data| {
        // std.log.debug("code: 0x{X}", .{key_data.key1});
        // press key
        keyboard.send_keycodes(key_data);
        // release key
        keyboard.send_keycodes(keyboard.KeyboardData{});
    }
}

fn type_mandelbrot() void {
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
                type_keyboard(' ');
                // 140 GOTO 210
            } else {
                // 200 IF I>9 THEN I=I+7
                if (i > 9) i += 7;
                // 205 PRINT CHR(48+I),
                type_keyboard(48 + i);
            }
            // 210 NEXT X
            x += 1;
        }
        // 220 PRINT
        type_keyboard('\n');
        // 230 NEXT Y
        y += 1;
    }
}
