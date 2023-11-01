const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const serial = ch32v.serial;
const time = ch32v.time;
const clocks = ch32v.clocks;

const clocks_config = clocks.Configuration{
    // .sysclk_src = clocks.Sysclk_src.HSE,
    // .hse_freq = 25_000_000,
    .pll_src = clocks.Pll_src.HSI,
    // .enable_rtc = false, // Disable RTC blocks log with timestam.
};

const pin_config = ch32v.pins.GlobalConfiguration{
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
    //     .name = "rx",
    //     .function = .SERIAL,
    // },
    .PB6 = .{
        // SCL
        .name = "i2c",
        .function = .I2C,
        .speed = .standard,
    },
    .PB7 = .{
        //SDA
        .function = .I2C,
    },
};

const ADT7410_ADDR: u8 = 0x48;
const RESET_ADT7410 = [_]u8{0x2f};
const ONE_SHOT = [_]u8{ 0x03, 0x20 };
const READ_TEMP = [_]u8{0x00};
const READ_ID = [_]u8{0x08};
const READ_STATUS = [_]u8{0x02};

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
    // wait loading default config
    time.sleep_ms(1);

    const peripherals = microzig.chip.peripherals;
    std.log.debug("APB1PCENR: 0x{x:0>2}", .{peripherals.RCC.APB1PCENR.raw});
    std.log.debug("APB2PCENR: 0x{x:0>2}", .{peripherals.RCC.APB2PCENR.raw});

    const regs = ch32v.i2c.Port.get_regs(pins.i2c.get_port());
    std.log.debug("CTLR1: 0x{x:0>2}", .{regs.CTLR1.raw});
    std.log.debug("CTLR2: 0x{x:0>2}", .{regs.CTLR2.raw});
    std.log.debug("CKCFGR: 0x{x:0>2}", .{regs.CKCFGR.raw});
    std.log.debug("STAR1: 0x{x:0>2}", .{regs.STAR1.raw});
    std.log.debug("STAR2: 0x{x:0>2}", .{regs.STAR2.raw});
    // reset ADT7410
    // pins.i2c.write(ADT7410_ADDR, &RESET_ADT7410) catch |err| {
    //     std.log.debug("ERROR: {}", .{err});
    // };
    pins.i2c.write(ADT7410_ADDR, &RESET_ADT7410) catch {};
    time.sleep_ms(1);

    // var buffer = []u8{0} ** lenght;
    // var _buffer: [128]u8 = undefined;
    var buffer: [1]u8 = undefined;
    if (pins.i2c.write_read(ADT7410_ADDR, &READ_ID, &buffer)) |_| {
        // https://github.com/ziglang/zig/issues/17611
        // std.log.debug("ID: 0x{s}", .{std.fmt.fmtSliceHexLower(buffer[0..1])});
        std.log.debug("ID: 0x{x:0>2}", .{buffer[0]});
    } else |err| {
        std.log.debug("ERROR: {}", .{err});
    }

    var i: u32 = 0;
    while (true) {
        pins.i2c.write(ADT7410_ADDR, &ONE_SHOT) catch |err| {
            std.log.debug("ERROR: {}", .{err});
        };
        time.sleep_ms(240);

        var data: [2]u8 = undefined;
        if (pins.i2c.write_read(ADT7410_ADDR, &READ_TEMP, &data)) |_| {
            var _temp = (@as(u16, data[0]) << 8) | @as(u16, data[1]);
            // std.log.debug("seq: {}", .{_temp});

            var temp = switch (_temp & 0x8000) {
                0 => @as(f32, @floatFromInt(_temp >> 3)) / 16.0,
                else => (@as(f32, @floatFromInt((_temp >> 3))) - 8191.0) / 16.0,
            };
            // writeln!(&mut log, "Temp:{:+.1}", temp).unwrap();

            std.log.debug("seq:{}, {d:.1}C", .{ i, temp });
        } else |err| {
            std.log.debug("seq:{}, {}", .{ i, err });
        }
        i += 1;

        pins.led.toggle();
        time.sleep_ms(1000);
    }
}
