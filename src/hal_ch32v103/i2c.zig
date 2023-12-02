const std = @import("std");
const microzig = @import("microzig");
const ch32v = microzig.hal;
const pins = ch32v.pins;

const peripherals = microzig.chip.peripherals;

const I2cRegs = microzig.chip.types.peripherals.I2C1;
const I2C1 = peripherals.I2C1;
const I2C2 = peripherals.I2C2;

pub const Speed = enum {
    fast, // Max. 100kHz
    standard, // Max. 400kHz
};

pub fn I2C(comptime pin_name: []const u8) type {
    return struct {
        const pin = pins.parse_pin(pin_name);

        const I2cError = error{
            // Bus Error (BERR)
            BusError,
            // Acknowledge Failure (AF)
            Nak,
            // Arbitration Lost (ARLO)
            ArbitrationError,
            // Overrun/ Underrun Error (OVR)
            OverrunError,
            // Packet Check (Crc) check error
            PacketError,
            // Not specify error reason
            UnknownError,
        };

        pub inline fn write(self: @This(), address: u8, bytes: []const u8) I2cError!void {
            _ = self;
            const regs = pin.i2c_port_regs;

            // Reset status register
            regs.STAR1.raw = 0;

            // make START condition
            regs.CTLR1.modify(.{
                .START = 1,
            });
            // wait start transmitted
            while (true) {
                asm volatile ("" ::: "memory");

                const stat = regs.STAR1.read();
                if (stat.SB == 1) break;

                if (stat.PECERR == 1) {
                    return I2cError.PacketError;
                } else if (stat.OVR == 1) {
                    return I2cError.OverrunError;
                } else if (stat.AF == 1) {
                    return I2cError.Nak;
                } else if (stat.ARLO == 1) {
                    return I2cError.ArbitrationError;
                } else if (stat.BERR == 1) {
                    return I2cError.BusError;
                }
            }

            // send ADDRESS with WRITE flag(0)
            regs.DATAR.write(.{
                .DR = (address << 1),
                .padding = 0,
            });
            // Wait transmitted ADDR and RW bit.
            while (true) {
                asm volatile ("" ::: "memory");

                const stat = regs.STAR1.read();
                if (stat.ADDR == 1) break;

                if (stat.PECERR == 1) {
                    return I2cError.PacketError;
                } else if (stat.OVR == 1) {
                    return I2cError.OverrunError;
                } else if (stat.AF == 1) {
                    return I2cError.Nak;
                } else if (stat.ARLO == 1) {
                    return I2cError.ArbitrationError;
                } else if (stat.BERR == 1) {
                    return I2cError.BusError;
                }
            }
            // clear ADDR flag
            // if (regs.STAR2.read().MSL == 0) return I2cError.UnknownError;
            _ = regs.STAR2.raw;

            // send all data
            for (0..bytes.len) |i| {
                while (true) {
                    asm volatile ("" ::: "memory");

                    const stat = regs.STAR1.read();
                    if (stat.TxE == 1) break;

                    if (stat.PECERR == 1) {
                        return I2cError.PacketError;
                    } else if (stat.OVR == 1) {
                        return I2cError.OverrunError;
                    } else if (stat.AF == 1) {
                        return I2cError.Nak;
                    } else if (stat.ARLO == 1) {
                        return I2cError.ArbitrationError;
                    } else if (stat.BERR == 1) {
                        return I2cError.BusError;
                    }
                }

                regs.DATAR.write(.{
                    .DR = bytes[i],
                    .padding = 0,
                });
            }

            // make STOP condition
            // STOP condition is generated after current byre transfer.
            regs.CTLR1.modify(.{
                .STOP = 1,
            });
        }

        // https://blog.orhun.dev/zig-bits-01/
        pub inline fn write_read(self: @This(), address: u8, bytes: []const u8, buffer: []u8) I2cError!void {
            _ = self;
            const regs = pin.i2c_port_regs;

            // Reset status register
            regs.STAR1.raw = 0;

            // make START condition
            regs.CTLR1.modify(.{
                .START = 1,
            });
            // wait start transmitted
            while (true) {
                asm volatile ("" ::: "memory");

                const stat = regs.STAR1.read();
                if (stat.SB == 1) break;

                if (stat.PECERR == 1) {
                    return I2cError.PacketError;
                } else if (stat.OVR == 1) {
                    return I2cError.OverrunError;
                } else if (stat.AF == 1) {
                    return I2cError.Nak;
                } else if (stat.ARLO == 1) {
                    return I2cError.ArbitrationError;
                } else if (stat.BERR == 1) {
                    return I2cError.BusError;
                }
            }

            // send ADDRESS with WRITE flag(0)
            regs.DATAR.write(.{
                .DR = (address << 1),
                .padding = 0,
            });
            // Wait transmitted ADDR and RW bit.
            while (true) {
                asm volatile ("" ::: "memory");

                const stat = regs.STAR1.read();
                if (stat.ADDR == 1) break;

                if (stat.PECERR == 1) {
                    return I2cError.PacketError;
                } else if (stat.OVR == 1) {
                    return I2cError.OverrunError;
                } else if (stat.AF == 1) {
                    return I2cError.Nak;
                } else if (stat.ARLO == 1) {
                    return I2cError.ArbitrationError;
                } else if (stat.BERR == 1) {
                    return I2cError.BusError;
                }
            }
            _ = regs.STAR2.raw;

            // send all data
            for (0..bytes.len) |i| {
                while (true) {
                    asm volatile ("" ::: "memory");

                    const stat = regs.STAR1.read();
                    if (stat.TxE == 1) break;

                    if (stat.PECERR == 1) {
                        return I2cError.PacketError;
                    } else if (stat.OVR == 1) {
                        return I2cError.OverrunError;
                    } else if (stat.AF == 1) {
                        return I2cError.Nak;
                    } else if (stat.ARLO == 1) {
                        return I2cError.ArbitrationError;
                    } else if (stat.BERR == 1) {
                        return I2cError.BusError;
                    }
                }

                regs.DATAR.write(.{
                    .DR = bytes[i],
                    .padding = 0,
                });
            }

            // Wait WRITE complete
            while (true) {
                asm volatile ("" ::: "memory");

                const stat = regs.STAR1.read();
                if (stat.BTF == 1) break;

                if (stat.PECERR == 1) {
                    return I2cError.PacketError;
                } else if (stat.OVR == 1) {
                    return I2cError.OverrunError;
                } else if (stat.AF == 1) {
                    return I2cError.Nak;
                } else if (stat.ARLO == 1) {
                    return I2cError.ArbitrationError;
                } else if (stat.BERR == 1) {
                    return I2cError.BusError;
                }
            }

            // make START again
            regs.CTLR1.modify(.{
                .START = 1,
                .ACK = 1,
            });
            // wait start transmitted
            while (true) {
                asm volatile ("" ::: "memory");

                const stat = regs.STAR1.read();
                if (stat.SB == 1) break;

                if (stat.PECERR == 1) {
                    return I2cError.PacketError;
                } else if (stat.OVR == 1) {
                    return I2cError.OverrunError;
                } else if (stat.AF == 1) {
                    return I2cError.Nak;
                } else if (stat.ARLO == 1) {
                    return I2cError.ArbitrationError;
                } else if (stat.BERR == 1) {
                    return I2cError.BusError;
                }
            }

            // send ADDRESS with WRITE flag(1)
            regs.DATAR.write(.{
                .DR = ((address << 1) | 0b1),
                .padding = 0,
            });
            // Wait transmitted ADDR and RW bit.
            while (true) {
                asm volatile ("" ::: "memory");

                const stat = regs.STAR1.read();
                if (stat.ADDR == 1) break;

                // Make STOP condition before exit
                // (*I2C1::ptr()).ctlr1.modify(|_, w| w.stop().set_bit());

                if (stat.PECERR == 1) {
                    return I2cError.PacketError;
                } else if (stat.OVR == 1) {
                    return I2cError.OverrunError;
                } else if (stat.AF == 1) {
                    return I2cError.Nak;
                } else if (stat.ARLO == 1) {
                    return I2cError.ArbitrationError;
                } else if (stat.BERR == 1) {
                    return I2cError.BusError;
                }
            }
            _ = regs.STAR2.raw;

            // read all data
            const last_index = buffer.len - 1;
            for (0..buffer.len) |i| {
                if (i == last_index) {
                    // Return NACK
                    regs.CTLR1.modify(.{
                        .ACK = 0,
                    });
                }

                // Wait ready to read
                while (true) {
                    asm volatile ("" ::: "memory");

                    const stat = regs.STAR1.read();
                    if (stat.RxNE == 1) break;

                    if (stat.PECERR == 1) {
                        return I2cError.PacketError;
                    } else if (stat.OVR == 1) {
                        return I2cError.OverrunError;
                    } else if (stat.AF == 1) {
                        return I2cError.Nak;
                    } else if (stat.ARLO == 1) {
                        return I2cError.ArbitrationError;
                    } else if (stat.BERR == 1) {
                        return I2cError.BusError;
                    }
                }

                buffer[i] = regs.DATAR.read().DR;
            }

            // make STOP condition
            regs.CTLR1.modify(.{
                .STOP = 1,
            });
        }

        pub inline fn get_port(self: @This()) Port {
            _ = self;
            return pin.i2c_port;
        }
    };
}

pub const Port = enum {
    I2C1,
    I2C2,

    pub const Configuration = struct {
        setup: bool = false,
        speed: Speed = Speed.standard,
    };

    pub fn get_regs(port: Port) *volatile I2cRegs {
        return switch (@intFromEnum(port)) {
            0 => I2C1,
            1 => I2C2,
        };
    }
};
