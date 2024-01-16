const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const serial = ch32v.serial;
const time = ch32v.time;
const clocks = ch32v.clocks;
const sdcard = ch32v.sdcard;

const clocks_config = clocks.Configuration{
    .sysclk_src = .HSI,
    // .hse_freq = 25_000_000,
    // .pll_src = .HSI,
    // .enable_rtc = false, // Disable RTC blocks log with timestam.
};

pub const __Clocks_freq = clocks_config.get_freqs();
// pub const __Clocks_freq = clocks.Default_clocks_freq();

pub const pin_config = ch32v.pins.GlobalConfiguration{
    // For CH32V203
    .PA4 = .{
        .name = "cs",
        .direction = .out,
        .level = .high,
    },
    .PA5 = .{
        // SCK
        .name = "spi",
        .function = .SPI,
        .clock_div = .PCLK_64,
        .cpol = 0,
        .cpha = 0,
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
    const writer = pins.tx.writer();
    // wait loading default config
    time.sleep_ms(1);

    const sd_card = sdcard.SDCARD_DRIVER("spi", "cs");
    pins.led.toggle();
    if (sd_card.init()) {
        // gear up. set new communication speed.
        // pins.spi.set_clock_div(.PCLK_4); // worked at 2 Mbps
        pins.spi.set_clock_div(.PCLK_16);

        time.sleep_ms(1);

        const cid = sd_card.read_cid() catch 0;
        try writer.print("CID: {X}", .{cid});

        time.sleep_ms(1);

        const csd = sd_card.read_csd() catch 0;
        try writer.print("CDS: {X}", .{csd});

        time.sleep_ms(1);

        const sec_size = sd_card.sector_size() catch 0;
        try writer.print("sec size: {}", .{sec_size});

        time.sleep_ms(1);

        const vol_size = sd_card.volume_size() catch 0;
        // try writer.print("vol size: {}", .{vol_size});
        try writer.print("vol size: {}M", .{vol_size / 1024 / 1024});

        time.sleep_ms(1);

        // set block size to 512 bytes if sector size is not 512 bytes.
        if (try sd_card.fix_block_len512()) {
            time.sleep_ms(1);

            // read and write
            var buffer1: [512]u8 = undefined;
            var buffer2: [2 * 512]u8 = undefined;

            // read
            sd_card.read_single(0, &buffer1) catch {};

            time.sleep_ms(1);

            sd_card.read_multi(0, &buffer2) catch {};

            time.sleep_ms(1);

            // write
            sd_card.write_single(0, &buffer1) catch {};

            time.sleep_ms(1);

            sd_card.write_multi(0, &buffer2) catch {};
        }
    } else |_| {
        pins.led.toggle();
        // _ = err;
    }
    sd_card.deactivate();

    while (true) {
        time.sleep_ms(1000);
    }
}
