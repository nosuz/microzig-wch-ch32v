const microzig = @import("microzig");
const ch32v = microzig.hal;
const pins = ch32v.pins;
const time = ch32v.time;

const peripherals = microzig.chip.peripherals;

const ADC1 = peripherals.ADC1;
const ADC2 = peripherals.ADC2;

// p. 157, p.122
pub const SAMPTR = enum(u3) {
    cycles1_5 = 0b000, // 1.5 cycles
    cycles7_5 = 0b001, // 7.5 cycles
    cycles13_5 = 0b010, // 13.5 cycles
    cycles28_5 = 0b011, // 28.5 cycles
    cycles41_5 = 0b100, // 41.5 cycles
    cycles55_5 = 0b101, // 55.5 cycles
    cycles71_5 = 0b110, // 71.5 cycles
    cycles239_5 = 0b111, // 239.5 cycles
};

pub const Channel = enum {
    PA0,
    PA1,
    PA2,
    PA3,
    PA4,
    PA5,
    PA6,
    PA7,
    PB0,
    PB1,
    PC0,
    PC1,
    PC2,
    PC3,
    PC4,
    PC5,
    IN16, // temp sensor
    IN17, // Vrefint
};

pub fn ADC(comptime pin_name: []const u8, comptime port: Port) type {
    return struct {
        const pin = pins.parse_pin(pin_name);

        inline fn do_conversion(self: @This()) u16 {
            _ = self;
            var value: u16 = 0;

            switch (@intFromEnum(port)) {
                // ADC1
                0 => {
                    ADC1.RSQR3__CHANNEL.modify(.{
                        .SQ1__CHSEL = pin.adc_channel_num,
                    });
                    ADC1.RSQR1.modify(.{
                        .L = 1,
                    });

                    // start conversion
                    ADC1.CTLR2.modify(.{
                        .ADON = 1,
                    });
                    // wait conversion
                    while (ADC1.STATR.read().EOC == 0) {
                        asm volatile ("" ::: "memory");
                    }

                    value = @truncate(ADC1.RDATAR_DR_ACT_DCG.raw & 0xffff);
                },
                1 => {
                    ADC2.RSQR3__CHANNEL.modify(.{
                        .SQ1__CHSEL = pin.adc_channel_num,
                    });
                    ADC2.RSQR1.modify(.{
                        .L = 1,
                    });

                    // start conversion
                    ADC2.CTLR2.modify(.{
                        .ADON = 1,
                    });
                    // wait conversion
                    while (ADC2.STATR.read().EOC == 0) {
                        asm volatile ("" ::: "memory");
                    }

                    value = @truncate(ADC2.RDATAR_DR_ACT_DCG.raw & 0xffff);
                },
            }

            return value;
        }

        pub fn read(self: @This()) u16 {
            port.power_on();
            if (pin.adc_tsvr) {
                // enable tem sensor
                switch (@intFromEnum(port)) {
                    // ADC1
                    0 => {
                        ADC1.CTLR2.modify(.{
                            .TSVREFE = 1,
                        });
                    },
                    1 => {
                        // only for ADC1
                    },
                }
            }

            const value = self.do_conversion();

            if (pin.adc_tsvr) {
                // disable tem sensor
                switch (@intFromEnum(port)) {
                    // ADC1
                    0 => {
                        ADC1.CTLR2.modify(.{
                            .TSVREFE = 0,
                        });
                    },
                    1 => {
                        // only for ADC1
                    },
                }
            }
            port.power_off();

            return value;
        }
    };
}

pub const Port = enum {
    ADC1,
    ADC2,

    pub const Configuration = struct {
        setup: bool = false,

        samptr1: u32 = 0,
        samptr2: u32 = 0,
    };

    pub fn power_on(port: Port) void {
        switch (@intFromEnum(port)) {
            // ADC1
            0 => {
                ADC1.CTLR2.modify(.{
                    .ADON = 1,
                });
            },
            1 => {
                ADC2.CTLR2.modify(.{
                    .ADON = 1,
                });
            },
        }

        //wait Tstab (1us)
        time.sleep_ms(1);
    }

    pub fn power_off(port: Port) void {
        switch (@intFromEnum(port)) {
            // ADC1
            0 => {
                ADC1.CTLR2.modify(.{
                    .ADON = 0,
                });
            },
            1 => {
                ADC2.CTLR2.modify(.{
                    .ADON = 0,
                });
            },
        }
    }

    pub fn calibration(port: Port) u16 {
        power_on(port);
        time.sleep_ms(1);

        // start calibration
        var cal: u16 = 0;
        switch (@intFromEnum(port)) {
            // ADC1
            0 => {
                ADC1.CTLR2.modify(.{
                    .RSTCAL = 1,
                });
                while (ADC1.CTLR2.read().RSTCAL == 1) {
                    asm volatile ("" ::: "memory");
                }

                ADC1.CTLR2.modify(.{
                    .CAL = 1,
                });
                while (ADC1.CTLR2.read().CAL == 1) {
                    asm volatile ("" ::: "memory");
                }

                cal = @truncate(ADC1.RDATAR_DR_ACT_DCG.raw & 0xffff);
            },
            1 => {
                ADC2.CTLR2.modify(.{
                    .RSTCAL = 1,
                });
                while (ADC2.CTLR2.read().RSTCAL == 1) {
                    asm volatile ("" ::: "memory");
                }

                ADC2.CTLR2.modify(.{
                    .CAL = 1,
                });
                while (ADC2.CTLR2.read().CAL == 1) {
                    asm volatile ("" ::: "memory");
                }

                cal = @truncate(ADC2.RDATAR_DR_ACT_DCG.raw & 0xffff);
            },
        }
        power_off(port);

        return cal;
    }
};
