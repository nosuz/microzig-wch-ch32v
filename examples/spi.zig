const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const serial = ch32v.serial;
const time = ch32v.time;
const clocks = ch32v.clocks;

const clocks_config = clocks.Configuration{
    .sysclk_src = .HSI,
    // .hse_freq = 25_000_000,
    // .pll_src = .HSI,
    // .enable_rtc = false, // Disable RTC blocks log with timestam.
};

pub const __Clocks_freq = clocks_config.get_freqs();
// pub const __Clocks_freq = clocks.Default_clocks_freq();

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA4 = .{
        .name = "cs",
        .direction = .out,
    },
    .PA5 = .{
        // SCK
        .name = "spi",
        .function = .SPI,
        .clock_div = .PCLK_64,
        .cpol = 1,
        .cpha = 1,
    },
    .PA6 = .{
        // MISO
        .function = .SPI,
    },
    .PA7 = .{
        // MOSI
        .function = .SPI,
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
        .name = "led",
        .direction = .out,
    },
};

const RESET_ADT7310 = [_]u8{ 0xff, 0xff, 0xff, 0xff };
const ONE_SHOT = [_]u8{ 0x08, 0x20 };
const READ_TEMP = [_]u8{0x50};
const READ_ID = [_]u8{0x58};
const READ_STATUS = [_]u8{0x48};

const Command = packed struct(u8) {
    padding1: u2 = 0,
    continuous_read: u1 = 0,
    register_address: u3,
    rw: u1, // 0: write, 1: read
    padding2: u1 = 0,
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
    // wait loading default config
    time.sleep_ms(1);

    const peripherals = microzig.chip.peripherals;
    std.log.debug("APB1PCENR: 0x{x:0>2}", .{peripherals.RCC.APB1PCENR.raw});
    std.log.debug("APB2PCENR: 0x{x:0>2}", .{peripherals.RCC.APB2PCENR.raw});

    // const regs = ch32v.i2c.Port.get_regs(pins.i2c.get_port());
    // std.log.debug("CTLR1: 0x{x:0>2}", .{regs.CTLR1.raw});
    // std.log.debug("CTLR2: 0x{x:0>2}", .{regs.CTLR2.raw});
    // std.log.debug("CKCFGR: 0x{x:0>2}", .{regs.CKCFGR.raw});
    // std.log.debug("STAR1: 0x{x:0>2}", .{regs.STAR1.raw});
    // std.log.debug("STAR2: 0x{x:0>2}", .{regs.STAR2.raw});
    const regs = peripherals.SPI1;
    std.log.debug("CTLR1: 0x{x:0>2}", .{regs.CTLR1.raw});
    std.log.debug("STATR: 0x{x:0>2}", .{regs.STATR.raw});

    // reset ADT7310
    std.log.debug("Reset", .{});
    pins.cs.put(0);
    pins.spi.write(&RESET_ADT7310);
    pins.cs.put(1);
    time.sleep_ms(1);
    std.log.debug("done", .{});

    var i: u32 = 0;
    while (true) {
        // get ID
        pins.cs.put(0);
        var bytes: [1]u8 = @bitCast(Command{
            .register_address = 0x3,
            .rw = 1,
        });
        var id_buffer: [1]u8 = undefined;
        pins.spi.write_read(&bytes, &id_buffer);
        pins.cs.put(1);
        std.log.debug("ID: 0x{x:0>2}", .{id_buffer[0]});

        time.sleep_ms(100);

        pins.cs.put(0);
        pins.spi.write(&ONE_SHOT);

        time.sleep_ms(250);

        var read_temp_cmd: [1]u8 = @bitCast(Command{
            .register_address = 0x2,
            .rw = 1,
        });
        var buffer: [2]u8 = undefined;
        pins.spi.write_read(&read_temp_cmd, &buffer);
        pins.cs.put(1);

        // std.log.debug("Raw: {X:02}, {X:02}", .{ buffer[0], buffer[1] });
        const temp: u16 = (@as(u16, buffer[0]) << 8) | @as(u16, buffer[1]);
        // std.log.debug("u16: {X:04}", .{temp});

        var _temp: f32 = 0;
        if ((temp & 0x8000) == 0) {
            // When positive
            _temp = @as(f32, @floatFromInt(temp >> 3)) / 16.0;
        } else {
            // When negative
            _temp = (@as(f32, @floatFromInt((temp >> 3))) - 8192.0) / 16.0;
        }
        std.log.debug("seq: {}, Temp:{d:.1}C", .{ i, _temp });
        i += 1;

        pins.led.toggle();
        time.sleep_ms(1000);
    }
}
