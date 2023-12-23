const std = @import("std");
const comptimePrint = std.fmt.comptimePrint;
const StructField = std.builtin.Type.StructField;

const microzig = @import("microzig");
const ch32v = microzig.hal;
const gpio = ch32v.gpio;
const clocks = ch32v.clocks;
const serial = ch32v.serial;
const adc = ch32v.adc;
const i2c = ch32v.i2c;
const spi = ch32v.spi;
const usbhd = ch32v.usbhd;

const root = @import("root");

const peripherals = microzig.chip.peripherals;
const RCC = peripherals.RCC;
const ADC1 = peripherals.ADC;
const SPI1 = peripherals.SPI1;
const SPI2 = peripherals.SPI2;

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
        direction: gpio.Direction = .in,
        // drive_strength: ?gpio.DriveStrength = null,
        pull: ?gpio.Pull = null,
        level: ?gpio.Level = null,

        // ADC config
        adc: ?adc.Port = null,
        cycles: ?adc.SAMPTR = null,

        // make null for peripherals that use multiple pins.
        // Serial config
        baud_rate: ?u32 = null,
        word_bits: ?serial.WordBits = null,
        stop: ?serial.Stop = null,
        parity: ?serial.Parity = null,

        // I2C config
        i2c_speed: ?i2c.Speed = null,

        // SPI
        cpha: ?u1 = null,
        cpol: ?u1 = null,
        clock_div: ?spi.Clock_div = null,
        bit_order: ?spi.Bit_order = null,

        // USBHD
        usbhd_speed: ?usbhd.Speed = null,
        usbhd_ep_num: ?u3 = null,
        usbhd_buffer_size: ?usbhd.BufferSize = null,
        usbhd_handle_sof: ?bool = null,
    };
};

pub const Function = enum {
    GPIO,
    ADC,
    SERIAL,
    I2C,
    SPI,
    USBHD, // USBHD Device
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
    list(&.{ 2, 3, 9, 10, 26, 27 }), // SERIAL
    list(&.{ 22, 23, 26, 27 }), // I2C
    list(&.{ 5, 6, 7, 29, 30, 31 }), // SPI
    list(&.{ 11, 12 }), // USBHD
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
    } else if ((spec[0] == 'P') and (spec[1] >= 'A') and (spec[1] <= 'D')) {
        return struct {
            // pin_num: global pin number
            const pin_number: comptime_int = @intFromEnum(@field(Pin, spec));
            /// 'A'...'I'
            pub const gpio_port_name = spec[1..2];
            pub const gpio_port_num = @intFromEnum(@field(gpio.Port, spec[0..2]));
            pub const gpio_port_regs = @field(peripherals, "GPIO" ++ gpio_port_name);
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

            // Serial
            pub const serial_port_regs = switch (pin_number) {
                9, 10 => peripherals.USART1,
                2, 3 => peripherals.USART2,
                26, 27 => peripherals.USART3,
                else => undefined,
            };
            pub const serial_port = switch (pin_number) {
                9, 10 => serial.Port.USART1,
                2, 3 => serial.Port.USART2,
                26, 27 => serial.Port.USART3,
                else => unreachable,
            };

            // I2C
            pub const i2c_port_regs = switch (pin_number) {
                22, 23 => peripherals.I2C1,
                26, 27 => peripherals.I2C2,
                else => undefined,
            };
            pub const i2c_port: i2c.Port = switch (pin_number) {
                22, 23 => .I2C1,
                26, 27 => .I2C2,
                else => undefined,
            };

            pub const spi_port_regs = switch (pin_number) {
                5, 6, 7 => peripherals.SPI1,
                29, 30, 31 => peripherals.SPI2,
                else => undefined,
            };
            pub const spi_port: spi.Port = switch (pin_number) {
                5, 6, 7 => .SPI1,
                29, 30, 31 => .SPI2,
                else => undefined,
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

                pin_field.name = pin_config.name orelse field.name;
                if (pin_config.function == .GPIO) {
                    pin_field.type = gpio.GPIO(field.name, pin_config.direction);
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
                    pin_field.type = adc.ADC(field.name, pin_config.adc orelse adc.Port.ADC1);
                } else if (pin_config.function == .SERIAL) {
                    pin_field.type = serial.SERIAL(field.name);
                } else if (pin_config.function == .I2C) {
                    pin_field.type = i2c.I2C(field.name);
                } else if (pin_config.function == .SPI) {
                    pin_field.type = spi.SPI(field.name);
                } else if (pin_config.function == .USBHD) {
                    // make copy by the name "__usbhd__"
                    const usbhd_pin_field = StructField{
                        .is_comptime = false,
                        .default_value = null,

                        // initialized below:
                        .name = "__usbhd__",
                        .type = usbhd.USBHD(pin_config),
                        .alignment = @alignOf(field.type),
                    };
                    fields = fields ++ &[_]StructField{usbhd_pin_field};

                    pin_field.type = usbhd.USBHD(pin_config);
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
        comptime var port_cfg_default = [_]u32{ 0, 0, 0, 0 };

        // ADC
        comptime var adc_cfg = [_]adc.Port.Configuration{
            adc.Port.Configuration{},
        };

        // Serail
        comptime var uart_cfg = [_]serial.Port.Configuration{
            serial.Port.Configuration{},
            serial.Port.Configuration{},
            serial.Port.Configuration{},
            serial.Port.Configuration{},
        };

        // I2C
        comptime var i2c_cfg = [_]i2c.Port.Configuration{
            i2c.Port.Configuration{},
            i2c.Port.Configuration{},
        };

        // SPI
        comptime var spi_cfg = [_]spi.Port.Configuration{
            spi.Port.Configuration{},
            spi.Port.Configuration{},
        };

        // USBHD
        comptime var usbhd_cfg = usbhd.Configuration{};

        // validate selected function
        comptime {
            inline for (@typeInfo(GlobalConfiguration).Struct.fields) |field|
                if (@field(config, field.name)) |pin_config| {
                    const pin = parse_pin(field.name);
                    if (0 == function_table[@intFromEnum(pin_config.function)][pin.pin_number])
                        @compileError(comptimePrint("{s} cannot be configured for {}", .{ field.name, pin_config.function }));

                    if (pin_config.function == .GPIO) {
                        const index = switch (pin.gpio_port_pin_num) {
                            0...7 => @as(u3, pin.gpio_port_num) * 2,
                            8...15 => @as(u3, pin.gpio_port_num) * 2 + 1,
                            else => unreachable,
                        };
                        const shift_num = switch (pin.gpio_port_pin_num) {
                            0...7 => pin.gpio_port_pin_num * 4,
                            8...15 => (pin.gpio_port_pin_num - 8) * 4,
                            else => unreachable,
                        };

                        port_cfg_mask[index] |= 0b1111 << shift_num;
                        switch (pin_config.direction) {
                            .in => {
                                // MODE
                                port_cfg_value[index] |= 0b00 << shift_num;
                                // CFG
                                port_cfg_value[index] |= 0b01 << (shift_num + 2);
                                // OUTDR
                                if (pin_config.pull) |pull| {
                                    if (pull == gpio.Pull.up)
                                        port_cfg_default[pin.gpio_port_num] |= (1 << pin.gpio_port_pin_num);
                                }
                            },
                            .out => {
                                // MODE
                                port_cfg_value[index] |= 0b11 << shift_num;
                                // CFG
                                port_cfg_value[index] |= 0b00 << (shift_num + 2);
                                // OUTDR
                                if (pin_config.level) |level| {
                                    if (level == gpio.Level.high)
                                        port_cfg_default[pin.gpio_port_num] |= (1 << pin.gpio_port_pin_num);
                                }
                            },
                        }
                    } else if (pin_config.function == .ADC) {
                        if (root.__Clocks_freq.adcclk > 14_000_000)
                            @compileError(comptimePrint("ADC clock freq. is over 14Mhz.: {}", .{root.__Clocks_freq.adcclk}));

                        if (pin.adc_channel_num < 16) {
                            const index = switch (pin.gpio_port_pin_num) {
                                0...7 => @as(u3, pin.gpio_port_num) * 2,
                                8...15 => @as(u3, pin.gpio_port_num) * 2 + 1,
                                else => unreachable,
                            };
                            const shift_num = switch (pin.gpio_port_pin_num) {
                                0...7 => pin.gpio_port_pin_num * 4,
                                8...15 => (pin.gpio_port_pin_num - 8) * 4,
                                else => unreachable,
                            };

                            port_cfg_mask[index] |= 0b1111 << shift_num;
                            // MMODE: input
                            port_cfg_value[index] |= 0b00 << shift_num;
                            // CFG: analog input
                            port_cfg_value[index] |= 0b00 << (shift_num + 2);
                        }

                        if (pin_config.adc) |_| {
                            adc_cfg[0].setup = true;

                            const adc_ch = pin.adc_channel_num;
                            var val = 0;
                            if (pin_config.cycles) |cycles| {
                                val = @intFromEnum(cycles);
                            }
                            switch (adc_ch) {
                                0...9 => {
                                    adc_cfg[0].samptr2 |= val << (adc_ch * 3);
                                },
                                10...16 => {
                                    adc_cfg[0].samptr1 |= val << (adc_ch - 10) * 3;
                                },
                                else => {},
                            }
                        }
                    } else if (pin_config.function == .SERIAL) {
                        const index = switch (pin.gpio_port_pin_num) {
                            0...7 => @as(u3, pin.gpio_port_num) * 2,
                            8...15 => @as(u3, pin.gpio_port_num) * 2 + 1,
                            else => unreachable,
                        };
                        const shift_num = switch (pin.gpio_port_pin_num) {
                            0...7 => pin.gpio_port_pin_num * 4,
                            8...15 => (pin.gpio_port_pin_num - 8) * 4,
                            else => unreachable,
                        };

                        port_cfg_mask[index] |= 0b1111 << shift_num;
                        switch (pin.pin_number) {
                            // TX
                            2, 9, 26, 42 => {
                                // MODE: output max. 10MHz
                                port_cfg_value[index] |= 0b10 << shift_num;
                                // CFG: alternative push-pull
                                port_cfg_value[index] |= 0b10 << (shift_num + 2);
                            },
                            //RX
                            3, 10, 27, 43 => {
                                // MODE
                                port_cfg_value[index] |= 0b00 << shift_num;
                                // CFG
                                port_cfg_value[index] |= 0b01 << (shift_num + 2);
                            },
                            else => unreachable,
                        }

                        if (pin_config.baud_rate == 0) {
                            @compileLog(field.name);
                            @compileError("Baud rate should greater than 0.");
                        }
                        if (pin_config.baud_rate) |baud_rate| {
                            uart_cfg[@intFromEnum(pin.serial_port)].baud_rate = baud_rate;
                        }
                        if (pin_config.word_bits) |word_bits| {
                            uart_cfg[@intFromEnum(pin.serial_port)].word_bits = word_bits;
                        }
                        if (pin_config.stop) |stop| {
                            uart_cfg[@intFromEnum(pin.serial_port)].stop = stop;
                        }
                        if (pin_config.parity) |parity| {
                            uart_cfg[@intFromEnum(pin.serial_port)].parity = parity;
                        }
                        uart_cfg[@intFromEnum(pin.serial_port)].setup = true;
                    } else if (pin_config.function == .I2C) {
                        const i2c_base_freq = root.__Clocks_freq.pclk1 / 1000_000; // MHz
                        if ((i2c_base_freq < 2) or (i2c_base_freq > 36))
                            @compileError(comptimePrint("PCLK1 freq. should be between 2MHz and 36Mhz.: {}", .{root.__Clocks_freq.pclk1}));

                        switch (pin.pin_number) {
                            22, 23 => {
                                if (config.PB6) |port| {
                                    if (port.function != .I2C) {
                                        @compileError("PB6 is used for SPI. Not available for other functions.");
                                    }
                                }
                                if (config.PB7) |port| {
                                    if (port.function != .I2C) {
                                        @compileError("PB7 is used for SPI. Not available for other functions.");
                                    }
                                }
                            },
                            26, 27 => {
                                if (config.PB10) |port| {
                                    if (port.function != .I2C) {
                                        @compileError("PB10 is used for SPI. Not available for other functions.");
                                    }
                                }
                                if (config.PB11) |port| {
                                    if (port.function != .I2C) {
                                        @compileError("PB11 is used for SPI. Not available for other functions.");
                                    }
                                }
                            },
                            else => unreachable,
                        }

                        const index = switch (pin.gpio_port_pin_num) {
                            0...7 => @as(u3, pin.gpio_port_num) * 2,
                            8...15 => @as(u3, pin.gpio_port_num) * 2 + 1,
                            else => unreachable,
                        };
                        const shift_num = switch (pin.gpio_port_pin_num) {
                            0...7 => pin.gpio_port_pin_num * 4,
                            8...15 => (pin.gpio_port_pin_num - 8) * 4,
                            else => unreachable,
                        };

                        port_cfg_mask[index] |= 0b1111 << shift_num;
                        // MODE: output max. 10MHz
                        port_cfg_value[index] |= 0b01 << shift_num;
                        // CFG: alternative open-drain
                        port_cfg_value[index] |= 0b11 << (shift_num + 2);

                        if (pin_config.i2c_speed) |speed| {
                            i2c_cfg[@intFromEnum(pin.i2c_port)].speed = speed;
                        }
                        i2c_cfg[@intFromEnum(pin.i2c_port)].setup = true;
                    } else if (pin_config.function == .SPI) {
                        switch (pin.pin_number) {
                            5, 6, 7 => {
                                if (config.PA5) |port| {
                                    if (port.function != .SPI) {
                                        @compileError("PA5 is used for SPI. Not available for other functions.");
                                    }
                                }
                                if (config.PA6) |port| {
                                    if (port.function != .SPI) {
                                        @compileError("PA6 is used for SPI. Not available for other functions.");
                                    }
                                }
                                if (config.PA7) |port| {
                                    if (port.function != .SPI) {
                                        @compileError("PA7 is used for SPI. Not available for other functions.");
                                    }
                                }
                            },
                            29, 30, 31 => {
                                if (config.PB13) |port| {
                                    if (port.function != .SPI) {
                                        @compileError("PB13 is used for SPI. Not available for other functions.");
                                    }
                                }
                                if (config.PB14) |port| {
                                    if (port.function != .SPI) {
                                        @compileError("PB14 is used for SPI. Not available for other functions.");
                                    }
                                }
                                if (config.PB15) |port| {
                                    if (port.function != .SPI) {
                                        @compileError("PB15 is used for SPI. Not available for other functions.");
                                    }
                                }
                            },
                            else => unreachable,
                        }

                        const index = switch (pin.gpio_port_pin_num) {
                            0...7 => @as(u3, pin.gpio_port_num) * 2,
                            8...15 => @as(u3, pin.gpio_port_num) * 2 + 1,
                            else => unreachable,
                        };
                        const shift_num = switch (pin.gpio_port_pin_num) {
                            0...7 => pin.gpio_port_pin_num * 4,
                            8...15 => (pin.gpio_port_pin_num - 8) * 4,
                            else => unreachable,
                        };

                        port_cfg_mask[index] |= 0b1111 << shift_num;
                        switch (pin.pin_number) {
                            5, 29 => {
                                // MODE: output max. 50MHz
                                port_cfg_value[index] |= 0b11 << shift_num;
                                // CFG: alternative push-pull
                                port_cfg_value[index] |= 0b10 << (shift_num + 2);
                            },
                            6, 30 => {
                                // MODE: input
                                port_cfg_value[index] |= 0b00 << shift_num;
                                // CFG: float input (or pull-up input: 0b10, OUTDR for pull-up)
                                port_cfg_value[index] |= 0b01 << (shift_num + 2);
                            },
                            7, 31 => {
                                // MODE: output max. 50MHz
                                port_cfg_value[index] |= 0b11 << shift_num;
                                // CFG: alternative push-pull
                                port_cfg_value[index] |= 0b10 << (shift_num + 2);
                            },
                            else => unreachable,
                        }

                        if (pin_config.clock_div) |clock_div| {
                            spi_cfg[@intFromEnum(pin.spi_port)].clock_div = clock_div;
                        }
                        if (pin_config.cpha) |cpha| {
                            spi_cfg[@intFromEnum(pin.spi_port)].cpha = cpha;
                        }
                        if (pin_config.cpol) |cpol| {
                            spi_cfg[@intFromEnum(pin.spi_port)].cpol = cpol;
                        }
                        // if (pin_config.word_length) |word_length| {
                        //     spi_cfg[@intFromEnum(pin.spi_port)].word_length = word_length;
                        // }
                        if (pin_config.bit_order) |bit_order| {
                            spi_cfg[@intFromEnum(pin.spi_port)].bit_order = bit_order;
                        }
                        spi_cfg[@intFromEnum(pin.spi_port)].setup = true;
                    } else if (pin_config.function == .USBHD) {
                        // Ref. 3.3.5.6 USB clock
                        switch (root.__Clocks_freq.pllclk) {
                            48_000_000, 72_000_000 => {},
                            else => @compileError(comptimePrint("PLL clock freq. should be 48MHz or 72MHz.: {}", .{root.__Clocks_freq.pllclk})),
                        }

                        // make sure both PA11 and PA12 are USBHD or null
                        if (config.PA11) |port| {
                            if (port.function != .USBHD) {
                                @compileError("PA11 is used for USBHD. Not available for other functions.");
                            }
                        }
                        if (config.PA12) |port| {
                            if (port.function != .USBHD) {
                                @compileError("PA12 is used for USBHD. Not available for other functions.");
                            }
                        }

                        // check bus speed and buffer size.
                        if ((pin_config.usbhd_speed == .Low_speed) and (pin_config.usbhd_buffer_size == .byte_64)) {
                            @compileError("USBHD: 8 bytes is enough for low-speed devices buffer size.");
                        }

                        // Set PA11 and PA12 as GPIO out and set 0.
                        // But there pins are automatically connected to the USBHD when the USBHD is enabled.
                        const usbhd_gpio_port_index = @intFromEnum(gpio.Port.PA) * 2 + 1; // +1 is for port pins 8-15
                        const usbhd_shift_num_base = (11 - 8) * 4; // PA11 = 11
                        for (0..2) |i| {
                            port_cfg_mask[usbhd_gpio_port_index] |= 0b1111 << (usbhd_shift_num_base + 4 * i);
                            // MODE: output max. 50MHz
                            port_cfg_value[usbhd_gpio_port_index] |= 0b11 << (usbhd_shift_num_base + 4 * i);
                            // CFG: general push-pull
                            port_cfg_value[usbhd_gpio_port_index] |= 0b00 << ((usbhd_shift_num_base + 4 * i) + 2);
                        }
                        // set Low level
                        // default level after reset is Low and accept them.
                        // port_cfg_default[0] &= ~(0b11 << 11);

                        if (pin_config.usbhd_speed) |speed| {
                            usbhd_cfg.speed = speed;
                        }
                        usbhd_cfg.setup = true;
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
                RCC.APB2PCENR.raw |= (@as(u32, 1) << bit);
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
        // set default value or pull-up/down
        for (0..4) |i| {
            if ((port_cfg_mask[i * 2] + port_cfg_mask[i * 2 + 1]) != 0)
                peripherals.GPIOA.OUTDR.raw = port_cfg_default[i];
        }

        // Enable ADC
        if (adc_cfg[0].setup) {
            // enable ADC
            // RCC.APB2PCENR.raw |= (@as(u32, 1) << 9);
            RCC.APB2PCENR.modify(.{
                .ADCEN = 1,
            });

            ADC1.SAMPTR1.write_raw(adc_cfg[0].samptr1);
            ADC1.SAMPTR2.write_raw(adc_cfg[0].samptr2);
        }

        // Enable Serial
        serial.Configs.USART1 = uart_cfg[0];
        serial.Configs.USART2 = uart_cfg[1];
        serial.Configs.USART3 = uart_cfg[2];
        for (0..4) |i| {
            if (uart_cfg[i].setup) {
                switch (i) {
                    0 => {
                        RCC.APB2PCENR.modify(.{
                            .USART1EN = 1,
                        });
                    },
                    1 => {
                        RCC.APB1PCENR.modify(.{
                            .USART2EN = 1,
                        });
                    },
                    2 => {
                        RCC.APB1PCENR.modify(.{
                            .USART3EN = 1,
                        });
                    },
                    else => unreachable,
                }

                const regs = serial.Port.get_regs(@enumFromInt(i));
                regs.BRR.write_raw(root.__Clocks_freq.pclk2 / uart_cfg[i].baud_rate);

                // Enable USART, Tx, and Rx
                regs.CTLR1.modify(.{
                    .UE = 1,
                    .TE = 1,
                    .RE = 1,
                });
            }
        }

        // Enable I2C
        const i2c_base_freq = root.__Clocks_freq.pclk1 / 1000_000; // MHz
        for (0..3) |i| {
            if (i2c_cfg[i].setup) {
                // supply clocks.
                switch (i) {
                    0 => {
                        RCC.APB1PCENR.modify(.{
                            .I2C1EN = 1,
                        });
                    },
                    1 => {
                        RCC.APB1PCENR.modify(.{
                            .I2C2EN = 1,
                        });
                    },
                    else => {},
                }

                const regs = i2c.Port.get_regs(@enumFromInt(i));
                regs.CTLR2.modify(.{
                    .FREQ = @as(u6, @truncate(i2c_base_freq)),
                });

                // CCR values are referred to STM32F4xx (M0090 Rev 19) datasheet
                switch (i2c_cfg[i].speed) {
                    .standard => {
                        // Thigh = CCR * TPCLK1
                        // Tlow = CCR * TPCLK1
                        // (1 / 100kHz) * (1 / 2) = CCR * (1 / PCLK1)
                        const ccr = 5 * i2c_base_freq;
                        regs.CKCFGR.modify(.{
                            .F_S = 0,
                            .CCR = @as(u12, @truncate(ccr)),
                        });
                    },
                    .fast => {
                        if (i2c_base_freq < 10) {
                            // If DUTY = 0:
                            // Thigh = CCR * TPCLK1
                            // Tlow = 2 * CCR * TPCLK1
                            // (1 / 400kHz) * (1 / 3) = CCR * (1 / PCLK1)

                            const ccr = (i2c_base_freq * 10) / 12;
                            regs.CKCFGR.modify(.{
                                .F_S = 1,
                                .DUTY = 0,
                                .CCR = @as(u12, @truncate(ccr)),
                            });
                        } else {
                            // Thigh = 9 * CCR * TPCLK1
                            // Tlow = 16 * CCR * TPCLK1
                            // (1 / 400kHz) * (9 /25) = 9 * CCR * (1 / PCLK1)
                            // base_freq must be >10HHz
                            const ccr = (i2c_base_freq * 10) / 12;
                            regs.CKCFGR.modify(.{
                                .F_S = 1,
                                .DUTY = 1,
                                .CCR = @as(u12, @truncate(ccr)),
                            });
                        }
                    },
                }

                // enable I2C
                regs.CTLR1.modify(.{
                    .PE = 1,
                });
            }
        }

        // SPI
        for (0..3) |i| {
            if (spi_cfg[i].setup) {
                // Why SSI must set 1?
                // I found good explanation on stack overflow.
                // Setting nss_soft in Master (SPI)
                //  https://stackoverflow.com/questions/48849942/setting-nss-soft-in-master-spi

                switch (i) {
                    0 => {
                        // supply clocks to SPI.
                        RCC.APB2PCENR.modify(.{
                            .SPI1EN = 1,
                        });
                        SPI1.CTLR1.modify(.{
                            .BR = @intFromEnum(spi_cfg[0].clock_div),
                            .CPHA = spi_cfg[i].cpha,
                            .CPOL = spi_cfg[i].cpol,
                            // Control CS by software or GPIO
                            .SSM = 1,
                            .SSI = 1,
                            // .DFF = spi_cfg[i].word_length, // 0: 8 bits, 1: 16 bits
                            .LSBFIRST = @intFromEnum(spi_cfg[0].bit_order), // 0: MSB first, 1: LSB first
                            .MSTR = 1,
                            .SPE = 1,
                        });
                    },
                    1 => {
                        // supply clocks to SPI.
                        RCC.APB1PCENR.modify(.{
                            .SPI2EN = 1,
                        });
                        SPI2.CTLR1.modify(.{
                            .BR = @intFromEnum(spi_cfg[1].clock_div),
                            .CPHA = spi_cfg[i].cpha,
                            .CPOL = spi_cfg[i].cpol,
                            // Control CS by software or GPIO
                            .SSM = 1,
                            .SSI = 1,
                            // .DFF = spi_cfg[i].word_length, // 0: 8 bits, 1: 16 bits
                            .LSBFIRST = @intFromEnum(spi_cfg[1].bit_order), // 0: MSB first, 1: LSB first
                            .MSTR = 1,
                            .SPE = 1,
                        });
                    },
                    else => {},
                }
            }
        }

        // Enable USBHD
        if (usbhd_cfg.setup) {
            if (!root.__Clocks_freq.use_pll) {
                // PLL start
                // RCC_CFGR0
                RCC.CFGR0.modify(.{
                    .PLLMUL = @intFromEnum(root.__Clocks_freq.pll_multiplex),
                    .PLLXTPRE = if (root.__Clocks_freq.pll_src == .HSE_div2) 1 else 0,
                    .PLLSRC = switch (root.__Clocks_freq.pll_src) {
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
            }
            switch (root.__Clocks_freq.pllclk) {
                48_000_000 => {
                    RCC.CFGR0.modify(.{
                        .USBPRE = 1,
                    });
                },
                72_000_000 => {
                    RCC.CFGR0.modify(.{
                        .USBPRE = 0,
                    });
                },
                else => unreachable, // PLL freq must 48, 72 MHz.
            }
            // supply clocks to USBHD.
            RCC.AHBPCENR.modify(.{
                .USBHDEN = 1,
            });
            // reset USBHD
            RCC.AHBRSTR.modify(.{
                .USBHDRST = 1,
            });
            for (0..50000) |_| {
                asm volatile ("" ::: "memory");
            }
            RCC.AHBRSTR.modify(.{
                .USBHDRST = 0,
            });
            // route USBHD to PA11 and PA12
            peripherals.EXTEND.EXTEND_CTR.modify(.{
                .USBHDIO = 1,
                // .USBDLS // for USBHD (CH32F103)
            });
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
