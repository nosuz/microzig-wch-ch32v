const std = @import("std");
const assert = std.debug.assert;
const comptimePrint = std.fmt.comptimePrint;
const StructField = std.builtin.Type.StructField;

const microzig = @import("microzig");
const gpio = @import("gpio.zig");
const serial = @import("serial.zig");
const adc = @import("adc.zig");

const ch32v = microzig.hal;
const clocks = ch32v.clocks;
// const GPIOS = microzig.chip.peripherals.GPIO;

const peripherals = microzig.chip.peripherals;
const ADC1 = peripherals.ADC1;
const ADC2 = peripherals.ADC2;

// const pwm = @import("pwm.zig");
// const adc = @import("adc.zig");
// const resets = @import("resets.zig");

pub const Pin = enum {
    PA0, // 0
    PA1,
    PA2,
    PA3,
    PA4,
    PA5,
    PA6,
    PA7,
    PA8,
    PA9,
    PA10,
    PA11,
    PA12,
    PA13,
    PA14,
    PA15,
    PB0, // 16
    PB1,
    PB2,
    PB3,
    PB4,
    PB5,
    PB6,
    PB7,
    PB8,
    PB9,
    PB10,
    PB11,
    PB12,
    PB13,
    PB14,
    PB15, // 31
    PC0,
    PC1,
    PC2,
    PC3,
    PC4,
    PC5,
    PC6,
    PC7,
    PC8,
    PC9,
    PC10,
    PC11,
    PC12,
    PC13,
    PC14,
    PC15, // 47
    PD0,
    PD1,
    PD2, // 50
    IN16, // 51: dummy for temp sensor
    IN17, // 52: Vrefint

    pub const Configuration = struct {
        name: ?[]const u8 = null,
        function: Function = .GPIO,
        // GPIO config
        direction: ?gpio.Direction = null,
        // drive_strength: ?gpio.DriveStrength = null,
        pull: ?gpio.Pull = null,
        // ADC config
        adc: ?adc.Port = null,
        cycles: ?adc.SAMPTR = null,

        pub fn get_direction(comptime config: Configuration) gpio.Direction {
            return if (config.direction) |direction|
                direction
                // else if (comptime config.function.is_pwm())
                //     .out
                // else if (comptime config.function.is_uart_tx())
                //     .out
                // else if (comptime config.function.is_uart_rx())
                //     .in
                // else if (comptime config.function.is_adc())
                //     .in
            else
                @panic("TODO");
        }
    };
};

pub const Function = enum {
    GPIO,
    ADC,
};

fn all() [@typeInfo(Pin).Enum.fields.len]u1 {
    var ret: [@typeInfo(Pin).Enum.fields.len]u1 = undefined;
    for (&ret) |*elem|
        elem.* = 1;

    return ret;
}

fn list(gpio_list: []const u6) [@typeInfo(Pin).Enum.fields.len]u1 {
    var ret = std.mem.zeroes([@typeInfo(Pin).Enum.fields.len]u1);
    for (gpio_list) |num|
        ret[num] = 1;

    return ret;
}

fn single(gpio_num: u6) [@typeInfo(Pin).Enum.fields.len]u1 {
    var ret = std.mem.zeroes([@typeInfo(Pin).Enum.fields.len]u1);
    ret[gpio_num] = 1;
    return ret;
}

const function_table = [@typeInfo(Function).Enum.fields.len][@typeInfo(Pin).Enum.fields.len]u1{
    all(), // GPIO
    list(&.{ 0, 1, 2, 3, 4, 5, 6, 7, 16, 17, 32, 33, 34, 35, 36, 51, 52 }), // ADC
    // all(), // PIO0
    // all(), // PIO1
    // list(&.{ 0, 4, 16, 20 }), // SPI0_RX
    // list(&.{ 1, 5, 17, 21 }), // SPI0_CSn
    // list(&.{ 2, 6, 18, 22 }), // SPI0_SCK
    // list(&.{ 3, 7, 19, 23 }), // SPI0_TX
    // list(&.{ 8, 12, 24, 28 }), // SPI1_RX
    // list(&.{ 9, 13, 25, 29 }), // SPI1_CSn
    // list(&.{ 10, 14, 26 }), // SPI1_SCK
    // list(&.{ 11, 15, 27 }), // SPI1_TX
    // list(&.{ 0, 11, 16, 28 }), // UART0_TX
    // list(&.{ 1, 13, 17, 29 }), // UART0_RX
    // list(&.{ 2, 14, 18 }), // UART0_CTS
    // list(&.{ 3, 15, 19 }), // UART0_RTS
    // list(&.{ 4, 8, 20, 24 }), // UART1_TX
    // list(&.{ 5, 9, 21, 25 }), // UART1_RX
    // list(&.{ 6, 10, 22, 26 }), // UART1_CTS
    // list(&.{ 7, 11, 23, 27 }), // UART1_RTS
    // list(&.{ 0, 4, 8, 12, 16, 20, 24, 28 }), // I2C0_SDA
    // list(&.{ 1, 5, 9, 13, 17, 21, 25, 29 }), // I2C0_SCL
    // list(&.{ 2, 6, 10, 14, 18, 22, 26 }), // I2C1_SDA
    // list(&.{ 3, 7, 11, 15, 19, 23, 27 }), // I2C1_SCL
    // list(&.{ 0, 16 }), // PWM0_A
    // list(&.{ 1, 17 }), // PWM0_B
    // list(&.{ 2, 18 }), // PWM1_A
    // list(&.{ 3, 19 }), // PWM1_B
    // list(&.{ 4, 20 }), // PWM2_A
    // list(&.{ 5, 21 }), // PWM2_B
    // list(&.{ 6, 22 }), // PWM3_A
    // list(&.{ 7, 23 }), // PWM3_B
    // list(&.{ 8, 24 }), // PWM4_A
    // list(&.{ 9, 25 }), // PWM4_B
    // list(&.{ 10, 26 }), // PWM5_A
    // list(&.{ 11, 27 }), // PWM5_B
    // list(&.{ 12, 28 }), // PWM6_A
    // list(&.{ 13, 29 }), // PWM6_B
    // single(14), // PWM7_A
    // single(15), // PWM7_B
    // single(20), // CLOCK_GPIN0
    // single(22), // CLOCK_GPIN1
    // single(21), // CLOCK_GPOUT0
    // single(23), // CLOCK_GPOUT1
    // single(24), // CLOCK_GPOUT2
    // single(25), // CLOCK_GPOUT3
    // list(&.{ 0, 3, 6, 9, 12, 15, 18, 21, 24, 27 }), // USB_OVCUR_DET
    // list(&.{ 1, 4, 7, 10, 13, 16, 19, 22, 25, 28 }), // USB_VBUS_DET
    // list(&.{ 2, 5, 8, 11, 14, 17, 20, 23, 26, 29 }), // USB_VBUS_EN
    // single(26), // ADC0
    // single(27), // ADC1
    // single(28), // ADC2
    // single(29), // ADC3
};

pub fn parse_pin(comptime spec: []const u8) type {
    const invalid_format_msg = "The given pin '" ++ spec ++ "' has an invalid format.";

    if ((spec[0] == 'I') and (spec[1] == 'N')) {
        return struct {
            // pin_num: global pin number
            const pin_number: comptime_int = @intFromEnum(@field(Pin, spec));
            // ADC
            pub const adc_channel_num: comptime_int = @intFromEnum(@field(adc.Channel, spec));
            pub const adc_channel = std.fmt.comptimePrint("IN{d}", .{adc_channel_num});
            pub const adc_suffix = std.fmt.comptimePrint("{d}", .{adc_channel_num});
            pub const adc_tsvr = switch (adc_channel_num) {
                16, 17 => true,
                else => false,
            };
        };
    } else if ((spec[0] == 'P') and (spec[1] >= 'A') and (spec[1] <= 'E')) {
        return struct {
            // pin_num: global pin number
            const pin_number: comptime_int = @intFromEnum(@field(Pin, spec));
            /// 'A'...'I'
            pub const gpio_port_name = spec[1..2];
            pub const gpio_port_num = @intFromEnum(@field(gpio.Port, spec[0..2]));
            pub const gpio_port = @field(peripherals, "GPIO" ++ gpio_port_name);
            const gpio_port_pin_num: comptime_int = std.fmt.parseInt(u4, spec[2..], 10) catch @compileError(invalid_format_msg);
            pub const gpio_suffix = std.fmt.comptimePrint("{d}", .{gpio_port_pin_num});
            // ADC
            pub const adc_channel_num: comptime_int = @intFromEnum(@field(adc.Channel, spec));
            pub const adc_channel = std.fmt.comptimePrint("IN{d}", .{adc_channel_num});
            pub const adc_suffix = std.fmt.comptimePrint("{d}", .{adc_channel_num});
            pub const adc_tsvr = switch (adc_channel_num) {
                16, 17 => true,
                else => false,
            };
        };
    }

    @compileError(invalid_format_msg);
    // unreachable();
}

pub fn Pins(comptime config: GlobalConfiguration) type {
    comptime {
        var fields: []const StructField = &.{};
        for (@typeInfo(GlobalConfiguration).Struct.fields) |field| {
            if (@field(config, field.name)) |pin_config| {
                var pin_field = StructField{
                    .is_comptime = false,
                    .default_value = null,

                    // initialized below:
                    .name = undefined,
                    .type = undefined,
                    .alignment = undefined,
                };

                if (pin_config.function == .GPIO) {
                    pin_field.name = pin_config.name orelse field.name;
                    pin_field.type = gpio.GPIO(field.name, pin_config.direction orelse .in);
                    // } else if (pin_config.function.is_pwm()) {
                    //     pin_field.name = pin_config.name orelse @tagName(pin_config.function);
                    //     pin_field.type = pwm.Pwm(pin_config.function.pwm_slice(), pin_config.function.pwm_channel());
                    // } else if (pin_config.function.is_adc()) {
                    //     pin_field.name = pin_config.name orelse @tagName(pin_config.function);
                    //     pin_field.type = adc.Input;
                    //     pin_field.default_value = @as(?*const anyopaque, @ptrCast(switch (pin_config.function) {
                    //         .ADC0 => &adc.Input.ain0,
                    //         .ADC1 => &adc.Input.ain1,
                    //         .ADC2 => &adc.Input.ain2,
                    //         .ADC3 => &adc.Input.ain3,
                    //         else => unreachable,
                    //     }));
                } else if (pin_config.function == .ADC) {
                    pin_field.name = pin_config.name orelse field.name;
                    pin_field.type = adc.ADC(field.name, pin_config.adc orelse adc.Port.ADC1);
                } else {
                    continue;
                }

                // if (pin_field.default_value == null) {
                //     if (@sizeOf(pin_field.field_type) > 0) {
                //         pin_field.default_value = @as(?*const anyopaque, @ptrCast(&pin_field.field_type{}));
                //     } else {
                //         const Struct = struct {
                //             magic_field: pin_field.field_type = .{},
                //         };
                //         pin_field.default_value = @typeInfo(Struct).Struct.fields[0].default_value;
                //     }
                // }

                pin_field.alignment = @alignOf(field.type);

                fields = fields ++ &[_]StructField{pin_field};
            }
        }

        return @Type(.{
            .Struct = .{
                .layout = .Auto,
                .is_tuple = false,
                .fields = fields,
                .decls = &.{},
            },
        });
    }
}

pub const GlobalConfiguration = struct {
    PA0: ?Pin.Configuration = null,
    PA1: ?Pin.Configuration = null,
    PA2: ?Pin.Configuration = null,
    PA3: ?Pin.Configuration = null,
    PA4: ?Pin.Configuration = null,
    PA5: ?Pin.Configuration = null,
    PA6: ?Pin.Configuration = null,
    PA7: ?Pin.Configuration = null,
    PA8: ?Pin.Configuration = null,
    PA9: ?Pin.Configuration = null,
    PA10: ?Pin.Configuration = null,
    PA11: ?Pin.Configuration = null,
    PA12: ?Pin.Configuration = null,
    PA13: ?Pin.Configuration = null,
    PA14: ?Pin.Configuration = null,
    PA15: ?Pin.Configuration = null,
    PB0: ?Pin.Configuration = null,
    PB1: ?Pin.Configuration = null,
    PB2: ?Pin.Configuration = null,
    PB3: ?Pin.Configuration = null,
    PB4: ?Pin.Configuration = null,
    PB5: ?Pin.Configuration = null,
    PB6: ?Pin.Configuration = null,
    PB7: ?Pin.Configuration = null,
    PB8: ?Pin.Configuration = null,
    PB9: ?Pin.Configuration = null,
    PB10: ?Pin.Configuration = null,
    PB11: ?Pin.Configuration = null,
    PB12: ?Pin.Configuration = null,
    PB13: ?Pin.Configuration = null,
    PB14: ?Pin.Configuration = null,
    PB15: ?Pin.Configuration = null,
    PC0: ?Pin.Configuration = null,
    PC1: ?Pin.Configuration = null,
    PC2: ?Pin.Configuration = null,
    PC3: ?Pin.Configuration = null,
    PC4: ?Pin.Configuration = null,
    PC5: ?Pin.Configuration = null,
    PC6: ?Pin.Configuration = null,
    PC7: ?Pin.Configuration = null,
    PC8: ?Pin.Configuration = null,
    PC9: ?Pin.Configuration = null,
    PC10: ?Pin.Configuration = null,
    PC11: ?Pin.Configuration = null,
    PC12: ?Pin.Configuration = null,
    PC13: ?Pin.Configuration = null,
    PC14: ?Pin.Configuration = null,
    PC15: ?Pin.Configuration = null,
    PD0: ?Pin.Configuration = null,
    PD1: ?Pin.Configuration = null,
    PD2: ?Pin.Configuration = null,
    IN16: ?Pin.Configuration = null, // dummy for temp sensor
    IN17: ?Pin.Configuration = null, // dummy for V ref

    comptime {
        const pin_field_count = @typeInfo(Pin).Enum.fields.len;
        const config_field_count = @typeInfo(GlobalConfiguration).Struct.fields.len;
        if (pin_field_count != config_field_count)
            @compileError(comptimePrint("{} {}", .{ pin_field_count, config_field_count }));
    }

    pub fn apply(comptime config: GlobalConfiguration) Pins(config) {
        // GPIO
        comptime var port_cfg_mask = [_]u32{ 0, 0, 0, 0, 0, 0, 0, 0 };
        comptime var port_cfg_value = [_]u32{ 0, 0, 0, 0, 0, 0, 0, 0 };

        // ADC
        comptime var samptr1: u32 = 0;
        comptime var samptr2: u32 = 0;
        comptime var adc1: bool = false;
        comptime var adc2: bool = false;

        // validate selected function
        comptime {
            inline for (@typeInfo(GlobalConfiguration).Struct.fields) |field|
                if (@field(config, field.name)) |pin_config| {
                    const pin = parse_pin(field.name);
                    const gpio_num = @intFromEnum(@field(Pin, field.name));
                    if (0 == function_table[@intFromEnum(pin_config.function)][gpio_num])
                        @compileError(comptimePrint("{s} cannot be configured for {}", .{ field.name, pin_config.function }));

                    if (pin_config.function == .GPIO) {
                        switch (pin.pin_number) {
                            0...7 => {
                                const shift_num = pin.pin_number * 4;
                                port_cfg_mask[pin.gpio_port_num * 2] |= 0b1111 << shift_num;
                                switch (pin_config.get_direction()) {
                                    .in => {
                                        port_cfg_value[pin.gpio_port_num * 2] |= 0b01 << (shift_num + 2);
                                        port_cfg_value[pin.gpio_port_num * 2] |= 0b00 << shift_num;
                                    },
                                    .out => {
                                        port_cfg_value[pin.gpio_port_num * 2] |= 0b00 << (shift_num + 2);
                                        port_cfg_value[pin.gpio_port_num * 2] |= 0b11 << shift_num;
                                    },
                                }
                            },
                            8...15 => {
                                const shift_num = (pin.pin_number - 8) * 4;
                                port_cfg_mask[pin.gpio_port_num * 2 + 1] |= 0b1111 << shift_num;
                                switch (pin_config.get_direction()) {
                                    .in => {
                                        port_cfg_value[pin.gpio_port_num * 2 + 1] |= 0b01 << (shift_num + 2);
                                        port_cfg_value[pin.gpio_port_num * 2 + 1] |= 0b00 << shift_num;
                                    },
                                    .out => {
                                        port_cfg_value[pin.gpio_port_num * 2 + 1] |= 0b00 << (shift_num + 2);
                                        port_cfg_value[pin.gpio_port_num * 2 + 1] |= 0b11 << shift_num;
                                    },
                                }
                            },
                            else => {},
                        }
                    } else if (pin_config.function == .ADC) {
                        if (pin_config.adc == adc.Port.ADC1) {
                            adc1 = true;
                        } else if (pin_config.adc == adc.Port.ADC2) {
                            adc2 = true;
                        }
                        const adc_ch = pin.adc_channel_num;
                        var val = 0;
                        if (pin_config.cycles) |cycles| {
                            val = @intFromEnum(cycles);
                        }
                        switch (adc_ch) {
                            0...9 => {
                                samptr2 = samptr2 | (val << (adc_ch * 3));
                            },
                            10...16 => {
                                samptr1 = samptr1 | (val << (adc_ch - 10) * 3);
                            },
                            else => {},
                        }
                    }

                    // if (pin_config.function.is_adc()) {
                    //     has_adc = true;
                    // }
                    // if (pin_config.function.is_pwm()) {
                    //     has_pwm = true;
                    // }
                };
        }

        // TODO: ensure only one instance of an input function exists

        // const used_gpios = comptime input_gpios | output_gpios;

        // if (used_gpios != 0) {
        //     SIO.GPIO_OE_CLR.raw = used_gpios;
        //     SIO.GPIO_OUT_CLR.raw = used_gpios;
        // }

        // inline for (@typeInfo(GlobalConfiguration).Struct.fields) |field| {
        //     if (@field(config, field.name)) |pin_config| {
        //         const pin = gpio.num(@intFromEnum(@field(Pin, field.name)));
        //         const func = pin_config.function;

        //         // xip = 0,
        //         // spi,
        //         // uart,
        //         // i2c,\
        //         // pio0,
        //         // pio1,
        //         // gpck,
        //         // usb,
        //         // @"null" = 0x1f,

        //         if (func == .SIO) {
        //             pin.set_function(.sio);
        //         } else if (comptime func.is_pwm()) {
        //             pin.set_function(.pwm);
        //         } else if (comptime func.is_adc()) {
        //             pin.set_function(.null);
        //         } else if (comptime func.is_uart_tx() or func.is_uart_rx()) {
        //             pin.set_function(.uart);
        //         } else {
        //             @compileError(std.fmt.comptimePrint("Unimplemented pin function. Please implement setting pin function {s} for GPIO {}", .{
        //                 @tagName(func),
        //                 @intFromEnum(pin),
        //             }));
        //         }
        //     }
        // }

        // const mask: u32 = @intCast(portal_cfg_mask);
        // if (mask != 0) {
        //     peripherals.GPIOA.CFGHR.raw = (peripherals.GPIOA.CFGHR.raw & ~mask) | portal_cfg_value;
        // }

        // enable clocks
        for (0..4) |i| {
            var masks = port_cfg_mask[i * 2] | port_cfg_mask[i * 2 + 1];
            if (masks != 0) {
                const bit = @as(u5, @intCast(i + 2));
                peripherals.RCC.APB2PCENR.raw |= (@as(u32, 1) << bit);
            }
        }

        // Set pins mode.
        for (0..8) |i| {
            const mask = port_cfg_mask[i];
            const value = port_cfg_value[i];
            if (mask != 0) {
                switch (i) {
                    0 => {
                        peripherals.GPIOA.CFGLR.raw = (peripherals.GPIOA.CFGLR.raw & ~mask) | value;
                    },
                    1 => {
                        peripherals.GPIOA.CFGHR.raw = (peripherals.GPIOA.CFGHR.raw & ~mask) | value;
                    },
                    2 => {
                        peripherals.GPIOB.CFGLR.raw = (peripherals.GPIOB.CFGLR.raw & ~mask) | value;
                    },
                    3 => {
                        peripherals.GPIOB.CFGHR.raw = (peripherals.GPIOB.CFGHR.raw & ~mask) | value;
                    },
                    4 => {
                        peripherals.GPIOC.CFGLR.raw = (peripherals.GPIOC.CFGLR.raw & ~mask) | value;
                    },
                    5 => {
                        peripherals.GPIOC.CFGHR.raw = (peripherals.GPIOC.CFGHR.raw & ~mask) | value;
                    },
                    6 => {
                        peripherals.GPIOD.CFGLR.raw = (peripherals.GPIOD.CFGLR.raw & ~mask) | value;
                    },
                    7 => {
                        peripherals.GPIOD.CFGHR.raw = (peripherals.GPIOD.CFGHR.raw & ~mask) | value;
                    },
                    else => {},
                }
            }
        }

        // Enable ADC
        if (adc1 or adc2) {
            assert(clocks.Clocks_freq.adcclk <= 14_000_000);

            setup_adc_pins(config);

            // @compileLog(samptr1);
            // @compileLog(samptr2);
            if (adc1) {
                // enable ADC
                // peripherals.RCC.APB2PCENR.raw |= (@as(u32, 1) << 9);
                peripherals.RCC.APB2PCENR.modify(.{
                    .ADC1EN = 1,
                });

                ADC1.SAMPTR1_CHARGE1.write_raw(samptr1);
                ADC1.SAMPTR2_CHARGE2.write_raw(samptr2);
            }
            if (adc2) {
                // enable ADC
                // peripherals.RCC.APB2PCENR.raw |= (@as(u32, 1) << 10);
                peripherals.RCC.APB2PCENR.modify(.{
                    .ADC2EN = 1,
                });

                ADC2.SAMPTR1_CHARGE1.write_raw(samptr1);
                ADC2.SAMPTR2_CHARGE2.write_raw(samptr2);
            }
        }

        // if (output_gpios != 0)
        //     SIO.GPIO_OE_SET.raw = output_gpios;

        // if (input_gpios != 0) {
        //     inline for (@typeInfo(GlobalConfiguration).Struct.fields) |field|
        //         if (@field(config, field.name)) |pin_config| {
        //             const gpio_num = @intFromEnum(@field(Pin, field.name));
        //             const pull = pin_config.pull orelse continue;
        //             if (comptime pin_config.get_direction() != .in)
        //                 @compileError("Only input pins can have pull up/down enabled");

        //             gpio.set_pull(gpio_num, pull);
        //         };
        // }

        // if (has_adc) {
        //     adc.init();
        // }

        return get_pins(config);
    }
};

pub fn get_pins(comptime config: GlobalConfiguration) Pins(config) {
    // fields in the Pins(config) type should be zero sized, so we just
    // default build them all (wasn't sure how to do that cleanly in
    // `Pins()`
    var ret: Pins(config) = undefined;
    inline for (@typeInfo(Pins(config)).Struct.fields) |field| {
        if (field.default_value) |default_value| {
            @field(ret, field.name) = @as(*const field.field_type, @ptrCast(default_value)).*;
        } else {
            @field(ret, field.name) = .{};
        }
    }

    return ret;
}

pub fn setup_uart_pins(port: serial.Port) void {
    switch (@intFromEnum(port)) {
        // USART1
        0 => {
            // Enable GPIOA for changing PIn config.
            peripherals.RCC.APB2PCENR.modify(.{
                .IOPAEN = 1,
            });
            peripherals.GPIOA.CFGHR.modify(.{
                // PA9 TX
                .CNF9 = 0b10,
                .MODE9 = 0b11,
                // PA10 RX
                .CNF10 = 0b01,
                .MODE10 = 0,
            });
        },
        // USART2
        1 => {
            peripherals.RCC.APB2PCENR.modify(.{
                .IOPAEN = 1,
            });
            peripherals.GPIOA.CFGLR.modify(.{
                // PA2 TX
                .CNF2 = 0b10,
                .MODE2 = 0b11,
                // PA3 RX
                .CNF3 = 0b01,
                .MODE3 = 0,
            });
        },
        // USART3
        2 => {
            //@compileError("Not implimented");
        },
        // UART4
        3 => {
            //@compileError("Not implimented");
        },
    }
}

pub fn setup_adc_pins(comptime config: GlobalConfiguration) void {
    comptime var mask_pa: u32 = 0;
    comptime var mask_pb: u32 = 0;
    comptime var mask_pc: u32 = 0;
    const mask: u32 = 0b1111;
    comptime {
        inline for (@typeInfo(GlobalConfiguration).Struct.fields) |field| {
            if (@field(config, field.name)) |channel_config| {
                _ = channel_config;
                var ch: u5 = @intFromEnum(@field(adc.Channel, field.name));
                switch (ch) {
                    0...7 => {
                        mask_pa = mask_pa | (mask << (ch * 4));
                    },
                    8, 9 => {
                        mask_pb = mask_pb | (mask << ((ch - 8) * 4));
                    },
                    10...15 => {
                        mask_pc = mask_pc | (mask << ((ch - 10) * 4));
                    },
                    16, 17 => {},
                    else => unreachable,
                }
            }
        }
    }
    if (mask_pa > 0) {
        // Enable GPIOA for changing PIn config.
        peripherals.RCC.APB2PCENR.modify(.{
            .IOPAEN = 1,
        });
        peripherals.GPIOA.CFGLR.raw = peripherals.GPIOA.CFGLR.raw & ~mask_pa;
    }
    if (mask_pb > 0) {
        // Enable GPIOB for changing PIn config.
        peripherals.RCC.APB2PCENR.modify(.{
            .IOPBEN = 1,
        });
        peripherals.GPIOA.CFGHR.raw = peripherals.GPIOA.CFGHR.raw & ~mask_pb;
    }
    if (mask_pc > 0) {
        // Enable GPIOC for changing PIn config.
        peripherals.RCC.APB2PCENR.modify(.{
            .IOPCEN = 1,
        });
        peripherals.GPIOC.CFGLR.raw = peripherals.GPIOC.CFGLR.raw & ~mask_pc;
    }
}
