const std = @import("std");
const microzig = @import("microzig");

const ch32v = microzig.hal;
const time = ch32v.time;
const serial = ch32v.serial;
const clocks = ch32v.clocks;
const adc = ch32v.adc;

const clocks_config = clocks.Configuration{
    .sysclk_src = .HSI,
    // .sysclk_src = .HSE,
    // .hse_freq = 25_000_000,
    .pll_src = .HSI, // 8MHz
    .pll_multiplex = .MUL_6, // 48 MHz
    // .sysclk_src = .PLL,

    // .enable_rtc = false, // Disable RTC blocks log with timestam.
};

pub const __Clocks_freq = clocks_config.get_freqs();
// pub const __Clocks_freq = clocks.Default_clocks_freq();

const pin_config = ch32v.pins.GlobalConfiguration{
    .PA5 = .{
        .name = "led",
        // .function = .GPIO, // Default function
        .direction = .out,
    },
    .PA1 = .{
        .name = "analog",
        .function = .ADC,
        .adc = .ADC1,
        .cycles = .cycles239_5,
    },
    .IN16 = .{
        .name = "temp",
        .function = .ADC,
        // .adc = .ADC1,
        .cycles = .cycles7_5,
    },
    .IN17 = .{
        .name = "vref",
        .function = .ADC,
        // .adc = .ADC1,
        .cycles = .cycles239_5,
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
};

// set logger
pub const std_options = struct {
    pub const log_level = .debug;
    pub const logFn = serial.log;
    // pub const logFn = ch32v.serial.log_no_timestamp;
};

var i: u32 = 1;

pub fn main() !void {
    clocks_config.apply();

    const pins = pin_config.apply();

    // start logger
    serial.init_logger(pins.tx.get_port());

    const adc1 = adc.Port.ADC1;
    const cal = adc1.calibration();
    std.log.debug("cal: {}", .{cal});

    const vref = @as(f32, @floatFromInt(pins.vref.read())) / 0x1000 * 3.3;
    std.log.debug("Vref: {d:1.3}", .{vref});
    // const vref = pins.vref.read();
    // std.log.debug("Vref: {}", .{vref});

    const V25: f32 = 1.4; // V
    const AVG_SLOPE: f32 = -4.3e-3; // V/C (negative coefficient)
    while (true) {
        pins.led.put(1);
        // read adc
        const val = pins.analog.read();
        // Temperature (°C) = ((VSENSE-V25)/Avg_Slope)+25
        const temp = (@as(f32, @floatFromInt(pins.temp.read())) / 0x1000 * 3.3 - V25) / AVG_SLOPE + 25;
        std.log.debug("seq: {}, temp: {d:6.1}C, val: {}", .{ i, temp, val });

        pins.led.put(0);
        time.sleep_ms(1000);
        i += 1;
    }
}
