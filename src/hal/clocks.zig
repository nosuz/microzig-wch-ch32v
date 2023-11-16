const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const RCC = peripherals.RCC;
const RTC = peripherals.RTC;

const root = @import("root");

pub const Sysclk_src = enum(u2) {
    HSI = 0,
    HSE = 0b01,
    PLL = 0b10,
};

// 0xxx: SYSCLK not divided;
// 1000: SYSCLK divided by 2;
// 1001: SYSCLK divided by 4;
// 1010: SYSCLK divided by 8;
// 1011: SYSCLK divided by 16;
// 1100: SYSCLK divided by 64;
// 1101: SYSCLK divided by 128;
// 1110: SYSCLK divided by 256;
// 1111: SYSCLK divided by 512.

pub const Ahb_prescale = enum(u4) {
    SYSCLK = 0,
    SYSCLK_2 = 0b1000,
    SYSCLK_4 = 0b1001,
    SYSCLK_8 = 0b1010,
    SYSCLK_16 = 0b1011,
    SYSCLK_64 = 0b1100,
    SYSCLK_128 = 0b1101,
    SYSCLK_256 = 0b1110,
    SYSCLK_512 = 0b1111,
};

// 0xx: HCLK not divided;
// 100: HCLK divided by 2;
// 101: HCLK divided by 4;
// 110: HCLK divided by 8;
// 111: HCLK divided by 16.

pub const Apb_prescale = enum(u3) {
    HCLK = 0,
    HCLK_2 = 0b100,
    HCLK_4 = 0b101,
    HCLK_8 = 0b110,
    HCLK_16 = 0b111,
};

// 00: PCLK2 divided by 2;
// 01: PCLK2 divided by 4;
// 10: PCLK2 divided by 6;
// 11: PCLK2 divided by 8;

pub const Adc_prescale = enum(u2) {
    PCLK2_2 = 0,
    PCLK2_4 = 0b01,
    PCLK2_6 = 0b10,
    PCLK2_8 = 0b11,
};

// 0000: PLL input clock x 2;
// 0001: PLL input clock x 3;
// 0010: PLL input clock x 4;
// 0011: PLL input clock x 5;
// 0100: PLL input clock x 6;
// 0101: PLL input clock x 7;
// 0110: PLL input clock x 8;
// 0111: PLL input clock x 9;
// 1000: PLL input clock x 10;
// 1001: PLL input clock x 11;
// 1010: PLL input clock x 12;
// 1011: PLL input clock x 13;
// 1100: PLL input clock x 14;
// 1101: PLL input clock x 15;
// 1110: PLL input clock x 16;
// 1111: PLL input clock x 18;

pub const Pll_multiplex = enum(u4) {
    MUL_2 = 0b0000,
    MUL_3 = 0b0001,
    MUL_4 = 0b0010,
    MUL_5 = 0b0011,
    MUL_6 = 0b0100,
    MUL_7 = 0b0101,
    MUL_8 = 0b0110,
    MUL_9 = 0b0111,
    MUL_10 = 0b1000,
    MUL_11 = 0b1001,
    MUL_12 = 0b1010,
    MUL_13 = 0b1011,
    MUL_14 = 0b1100,
    MUL_15 = 0b1101,
    MUL_16 = 0b1110,
    MUL_18 = 0b1111,
};

pub const Pll_src = enum {
    HSI,
    HSI_div2,
    HSE,
    HSE_div2,
};

// RTCSEL
// 00: No clock;
// 01: LSE oscillator clock;
// 10: LSI oscillator clock;
// 11: HSE oscillator clock divided by 128.

pub const Rtcclk_src = enum(u2) {
    LSE = 0b01,
    LSI = 0b10,
    HSE_128 = 0b11,
};

const Clocks_freq = struct {
    // config: Configuration = undefined,
    use_pll: bool = false,
    pll_src: Pll_src = .HSI,
    pll_multiplex: Pll_multiplex = .MUL_2,
    pllclk: u32 = 0,
    hclk: u32 = 8_000_000,
    pclk1: u32 = 8_000_000,
    pclk2: u32 = 8_000_000,
    adcclk: u32 = 4_000_000,
    apb1_timclk: u32 = 8_000_000,
    apb2_timclk: u32 = 8_000_000,
    rtcclk: u32 = 40_000,
    default: bool = true,
};

pub fn Default_clocks_freq() Clocks_freq {
    return Clocks_freq{};
}

pub const Configuration = struct {
    sysclk_src: Sysclk_src = Sysclk_src.HSI,
    hsi_freq: u32 = 8_000_000,
    hse_freq: ?u32 = null,
    hse_baypass: bool = false,
    pll_src: Pll_src = Pll_src.HSI,
    pll_multiplex: Pll_multiplex = Pll_multiplex.MUL_2,
    ahb_prescale: Ahb_prescale = Ahb_prescale.SYSCLK,
    apb1_prescale: Apb_prescale = Apb_prescale.HCLK,
    apb2_prescale: Apb_prescale = Apb_prescale.HCLK,
    adc_prescale: Adc_prescale = Adc_prescale.PCLK2_2,
    lsi_freq: u32 = 40_000,
    lse_freq: ?u32 = null,
    lse_baypass: bool = false,
    enable_rtc: bool = true,
    rtcclk_src: Rtcclk_src = Rtcclk_src.LSI,

    pub fn apply(comptime config: Configuration) void {
        comptime var sysclk_src = Sysclk_src.HSI;
        comptime var pllclk_freq = 0;
        comptime var hclk_freq = 0;
        comptime var pclk1_freq = 0;
        comptime var apb1_timclk_freq = 0;
        comptime var pclk2_freq = 0;
        comptime var apb2_timclk_freq = 0;
        comptime var adc_prescale = 0;
        comptime var adcclk_freq = 0;
        comptime var rtcclk_freq = 0;

        comptime {
            if (root.__Clocks_freq.default) @compileError("Missing statement: pub const __Clocks_freq = clocks_config.get_freqs();");

            if (config.sysclk_src == Sysclk_src.HSE) {
                if (config.hse_freq) |_| {
                    sysclk_src = Sysclk_src.HSE;
                } else {
                    @compileError("No External clock freq.");
                }
            } else {
                sysclk_src = config.sysclk_src;
            }
            // @compileLog(config.sysclk_src);
            // @compileLog(sysclk_src);
            const pll_multiplex = @as(u32, @intFromEnum(config.pll_multiplex)) + 2;
            pllclk_freq = pll_multiplex * switch (config.pll_src) {
                .HSI => config.hsi_freq,
                .HSI_div2 => config.hsi_freq / 2,
                .HSE => config.hse_freq,
                .HSE_div2 => config.hse_freq / 2,
            };
            const sysclk_freq = switch (sysclk_src) {
                .PLL => pllclk_freq,
                .HSI => config.hsi_freq,
                .HSE => config.hse_freq,
            };
            // @compileLog(sysclk_src);
            switch (sysclk_src) {
                Sysclk_src.HSE => {
                    if (sysclk_freq > 25_000_000) {
                        @compileError("HSE freq must lesss than 25MHz.");
                    } else if (!config.hse_baypass and sysclk_freq < 3_000_000) {
                        @compileError("HSE freq must greater than 3MHz.");
                    }
                },
                Sysclk_src.PLL => {
                    if (sysclk_freq > 144_000_000) {
                        @compileError("Sysclk freq must lesss than 25MHz.");
                    }
                },
                else => {},
            }

            const ahb_prescale = switch (config.ahb_prescale) {
                .SYSCLK => 1,
                .SYSCLK_2 => 2,
                .SYSCLK_4 => 4,
                .SYSCLK_8 => 8,
                .SYSCLK_16 => 16,
                .SYSCLK_64 => 64,
                .SYSCLK_128 => 128,
                .SYSCLK_256 => 256,
                .SYSCLK_512 => 512,
            };
            hclk_freq = sysclk_freq / ahb_prescale;

            const apb1_prescale = switch (config.apb1_prescale) {
                .HCLK => 1,
                .HCLK_2 => 2,
                .HCLK_4 => 4,
                .HCLK_8 => 8,
                .HCLK_16 => 16,
            };
            pclk1_freq = hclk_freq / apb1_prescale;

            apb1_timclk_freq = pclk1_freq * if (config.apb1_prescale == Apb_prescale.HCLK) 1 else 2;

            const apb2_prescale = switch (config.apb2_prescale) {
                .HCLK => 1,
                .HCLK_2 => 2,
                .HCLK_4 => 4,
                .HCLK_8 => 8,
                .HCLK_16 => 16,
            };
            pclk2_freq = hclk_freq / apb2_prescale;
            apb2_timclk_freq = pclk2_freq * if (config.apb1_prescale == Apb_prescale.HCLK) 1 else 2;

            adc_prescale = switch (config.adc_prescale) {
                .PCLK2_2 => 2,
                .PCLK2_4 => 4,
                .PCLK2_6 => 6,
                .PCLK2_8 => 8,
            };
            adcclk_freq = pclk2_freq / adc_prescale;
            // if (adcclk_freq > 14_000_000) {
            //     @compileLog("ADC clock = ", adcclk_freq);
            //     @compileError("ADC clock shall not exceed 14MHz ");
            // }

            rtcclk_freq = switch (config.rtcclk_src) {
                .LSE => config.lse_freq,
                .LSI => config.lsi_freq,
                .HSE_128 => config.hse_freq / 128,
            };
        }

        // runtimes
        // EXTEN_CTR
        // EXTEN reseted only on system reset.
        peripherals.EXTEND.EXTEND_CTR.modify(.{
            .PLL_HSI_PRE = if (config.pll_src == Pll_src.HSI) 1 else 0,
        });

        switch (sysclk_src) {
            .PLL => {
                // RCC_CFGR0
                RCC.CFGR0.modify(.{
                    .PLLMUL = @intFromEnum(config.pll_multiplex),
                    .PLLXTPRE = if (config.pll_src == Pll_src.HSE_div2) 1 else 0,
                    .PLLSRC = switch (config.pll_src) {
                        .HSI => 0,
                        .HSI_div2 => 0,
                        .HSE => 1,
                        .HSE_div2 => 1,
                    },
                });
                // RCC_CTLR
                RCC.CTLR.modify(.{
                    .PLLON = 1,
                });
                // while (RCC.CTLR.read().PLLRDY == 0) {}
                while (RCC.CTLR.read().PLLRDY == 0) {
                    asm volatile ("" ::: "memory");
                }
            },
            .HSI => {
                // RCC_CTLR
                RCC.CTLR.modify(.{
                    .HSION = 1,
                });
                // while (RCC.CTLR.read().HSIRDY == 0) {}
                while (RCC.CTLR.read().HSIRDY == 0) {
                    asm volatile ("" ::: "memory");
                }
            },
            .HSE => {
                RCC.CTLR.modify(.{
                    .HSEBYP = if (config.hse_baypass) 1 else 0,
                });
                RCC.CTLR.modify(.{
                    .HSEON = 1,
                });
                while (RCC.CTLR.read().HSERDY == 0) {
                    asm volatile ("" ::: "memory");
                }
            },
        }

        // RCC_CFGR0: set SYSCLK source
        RCC.CFGR0.modify(.{ .SW = @intFromEnum(config.sysclk_src) });

        // RCC_CFGR0: set HCLK, APB1, APB2 freq
        RCC.CFGR0.modify(.{
            .HPRE = @intFromEnum(config.ahb_prescale), // HCLS
            .PPRE1 = @intFromEnum(config.apb1_prescale), // APB1
            .PPRE2 = @intFromEnum(config.apb2_prescale), // APB2
            .ADCPRE = @intFromEnum(config.adc_prescale), // ADC
        });

        if (config.enable_rtc) {
            // supply clock to POWER and BACKUP domain.
            RCC.APB1PCENR.modify(.{
                .PWREN = 1,
                .BKPEN = 1,
            });

            // Setup RTC
            RCC.BDCTLR.modify(.{
                .RTCEN = 0,
            });

            //  Disable backup domain protection
            peripherals.PWR.CTLR.modify(.{
                .DBP = 1,
            });

            switch (config.rtcclk_src) {
                Rtcclk_src.LSE => {
                    RCC.BDCTLR.modify(.{
                        .LSEON = 1,
                        .LSEBYP = if (config.lse_baypass) 1 else 1,
                    });
                    while (RCC.BDCTLR.read().LSERDY == 0) {
                        asm volatile ("" ::: "memory");
                    }
                },
                Rtcclk_src.LSI => {
                    RCC.RSTSCKR.modify(.{
                        .LSION = 1,
                    });
                    while (RCC.RSTSCKR.read().LSIRDY == 0) {
                        asm volatile ("" ::: "memory");
                    }
                },
                Rtcclk_src.HSE_128 => {},
            }
            // set RTC clock source
            RCC.BDCTLR.modify(.{
                .RTCSEL = @intFromEnum(config.rtcclk_src),
            });

            // wait RTOFF
            while (RTC.CTLRL.read().RTOFF == 0) {
                asm volatile ("" ::: "memory");
            }
            // count up RTC every 1ms not 1s.
            RTC.CTLRL.modify(.{
                .CNF = 1,
            });
            const rtc_prescale = @as(u20, rtcclk_freq / 1000 - 1);
            RTC.PSCRL.write(.{
                .PRLL = @as(u16, rtc_prescale & 0xffff),
                .padding = 0,
            });
            RTC.PSCRH.write(.{
                .PRLH = @as(u4, rtc_prescale >> 16),
                .padding = 0,
            });

            // exit configuration mode
            RTC.CTLRL.modify(.{
                .CNF = 0,
            });
            // wait RTOFF
            while (RTC.CTLRL.read().RTOFF == 0) {
                asm volatile ("" ::: "memory");
            }
            // start RTC
            RCC.BDCTLR.modify(.{
                .RTCEN = 1,
            });
        }
    }

    pub fn get_freqs(comptime config: Configuration) Clocks_freq {
        comptime var sysclk_src = Sysclk_src.HSI;
        comptime var pllclk_freq = 0;
        comptime var hclk_freq = 0;
        comptime var pclk1_freq = 0;
        comptime var apb1_timclk_freq = 0;
        comptime var pclk2_freq = 0;
        comptime var apb2_timclk_freq = 0;
        comptime var adc_prescale = 0;
        comptime var adcclk_freq = 0;
        comptime var rtcclk_freq = 0;
        comptime var use_pll: bool = false;
        comptime var pll_src: Pll_src = .HSI;
        comptime var pll_multiplex: Pll_multiplex = .MUL_2;

        comptime {
            if (config.sysclk_src == .HSE) {
                if (config.hse_freq) |_| {
                    sysclk_src = .HSE;
                } else {
                    @compileError("No External clock freq.");
                }
            } else {
                sysclk_src = config.sysclk_src;
            }
            // @compileLog(config.sysclk_src);
            // @compileLog(sysclk_src);
            use_pll = if (config.sysclk_src == .PLL) true else false;
            pll_src = config.pll_src;
            pll_multiplex = config.pll_multiplex;

            const pll_multiplex_value = @as(u32, @intFromEnum(config.pll_multiplex)) + 2;
            pllclk_freq = pll_multiplex_value * switch (config.pll_src) {
                .HSI => config.hsi_freq,
                .HSI_div2 => config.hsi_freq / 2,
                .HSE => config.hse_freq,
                .HSE_div2 => config.hse_freq / 2,
            };
            const sysclk_freq = switch (sysclk_src) {
                .PLL => pllclk_freq,
                .HSI => config.hsi_freq,
                .HSE => config.hse_freq,
            };
            // @compileLog(sysclk_src);
            if (sysclk_src == .HSE) {
                if (sysclk_freq > 25_000_000) {
                    @compileError("HSE freq must lesss than 25MHz.");
                } else if (!config.hse_baypass and sysclk_freq < 3_000_000) {
                    @compileError("HSE freq must greater than 3MHz.");
                }
            }
            if (use_pll and (sysclk_freq > 144_000_000)) {
                @compileError("Sysclk freq must lesss than 144MHz.");
            }

            const ahb_prescale = switch (config.ahb_prescale) {
                .SYSCLK => 1,
                .SYSCLK_2 => 2,
                .SYSCLK_4 => 4,
                .SYSCLK_8 => 8,
                .SYSCLK_16 => 16,
                .SYSCLK_64 => 64,
                .SYSCLK_128 => 128,
                .SYSCLK_256 => 256,
                .SYSCLK_512 => 512,
            };
            hclk_freq = sysclk_freq / ahb_prescale;

            const apb1_prescale = switch (config.apb1_prescale) {
                .HCLK => 1,
                .HCLK_2 => 2,
                .HCLK_4 => 4,
                .HCLK_8 => 8,
                .HCLK_16 => 16,
            };
            pclk1_freq = hclk_freq / apb1_prescale;

            apb1_timclk_freq = pclk1_freq * if (config.apb1_prescale == Apb_prescale.HCLK) 1 else 2;

            const apb2_prescale = switch (config.apb2_prescale) {
                .HCLK => 1,
                .HCLK_2 => 2,
                .HCLK_4 => 4,
                .HCLK_8 => 8,
                .HCLK_16 => 16,
            };
            pclk2_freq = hclk_freq / apb2_prescale;
            apb2_timclk_freq = pclk2_freq * if (config.apb1_prescale == Apb_prescale.HCLK) 1 else 2;

            adc_prescale = switch (config.adc_prescale) {
                .PCLK2_2 => 2,
                .PCLK2_4 => 4,
                .PCLK2_6 => 6,
                .PCLK2_8 => 8,
            };
            adcclk_freq = pclk2_freq / adc_prescale;

            rtcclk_freq = switch (config.rtcclk_src) {
                .LSE => config.lse_freq,
                .LSI => config.lsi_freq,
                .HSE_128 => config.hse_freq / 128,
            };
        }

        return Clocks_freq{
            .use_pll = use_pll,
            .pll_src = pll_src,
            .pll_multiplex = pll_multiplex,
            .pllclk = pllclk_freq,
            .hclk = hclk_freq,
            .pclk1 = pclk1_freq,
            .apb1_timclk = apb1_timclk_freq,
            .pclk2 = pclk2_freq,
            .apb2_timclk = apb2_timclk_freq,
            .adcclk = adcclk_freq,
            .rtcclk = rtcclk_freq,
            .default = false,
        };
    }
};
