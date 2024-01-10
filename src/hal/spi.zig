const std = @import("std");
const microzig = @import("microzig");
const ch32v = microzig.hal;
const pins = ch32v.pins;

pub const Clock_div = enum(u3) {
    PCLK_2 = 0b000,
    PCLK_4 = 0b001,
    PCLK_8 = 0b010,
    PCLK_16 = 0b011,
    PCLK_32 = 0b100,
    PCLK_64 = 0b101,
    PCLK_128 = 0b110,
    PCLK_256 = 0b111,
};

pub const Word_length = enum(u1) {
    eight = 0,
    sixteen = 1,
};

pub const Bit_order = enum(u1) {
    msb_first = 0,
    lsb_first = 1,
};

pub const Port = enum {
    SPI1,
    SPI2,

    pub const Configuration = struct {
        setup: bool = false,

        cpha: u1 = 0, // 0: data sample at the first edge, 1: sample at the second edge.
        cpol: u1 = 0, // 0: low at idle, 1: high at idle.
        clock_div: Clock_div = .PCLK_16,
        // word_length: Word_length = eight,
        bit_order: Bit_order = .msb_first,
    };
};

pub fn SPI(comptime pin_name: []const u8) type {
    return struct {
        const pin = pins.parse_pin(pin_name);

        // const SpiError = error{
        //     // Mode error
        //     Mode,
        //     // CRC error
        //     Crc,
        //     // RX buffer overrun
        //     Overrun,
        //     // Unkown
        //     Unkown,
        // };

        pub inline fn read(self: @This(), buffer: []u8) void {
            const regs = pin.spi_port_regs;

            self.wait_complete();

            for (0..buffer.len) |i| {
                // dummy write
                while (regs.STATR.read().TXE == 0) {
                    asm volatile ("" ::: "memory");
                }
                regs.DATAR.write(.{
                    .DATAR = 0xffff,
                    .padding = 0,
                });

                while (regs.STATR.read().RXNE == 0) {
                    asm volatile ("" ::: "memory");
                }

                buffer[i] = @truncate(regs.DATAR.read().DATAR); // u16
            }
        }

        pub inline fn write(self: @This(), bytes: []const u8) void {
            const regs = pin.spi_port_regs;

            for (0..bytes.len) |i| {
                while (regs.STATR.read().TXE == 0) {
                    asm volatile ("" ::: "memory");
                }
                regs.DATAR.write(.{
                    .DATAR = @as(u16, bytes[i]),
                    .padding = 0,
                });
            }

            // wait transfer complete
            self.wait_complete();
        }

        // pub inline fn write_byte(self: @This(), byte: u8) void {
        //     const regs = pin.spi_port_regs;

        //     while (regs.STATR.read().TXE == 0) {
        //         asm volatile ("" ::: "memory");
        //     }

        //     regs.DATAR.write(.{
        //         .DATAR = @as(u16, @intCast(byte)),
        //         .padding = 0,
        //     });

        //     // wait transfer complete
        //     self.wait_complete();
        // }

        pub inline fn write_read(self: @This(), bytes: []const u8, buffer: []u8) void {
            const regs = pin.spi_port_regs;

            // write
            for (0..bytes.len) |i| {
                while (regs.STATR.read().TXE == 0) {
                    asm volatile ("" ::: "memory");
                }
                regs.DATAR.write(.{
                    .DATAR = @as(u16, bytes[i]),
                    .padding = 0,
                });
            }

            // wait transfer complete
            self.wait_complete();

            // read
            for (0..buffer.len) |i| {
                // dummy write
                while (regs.STATR.read().TXE == 0) {
                    asm volatile ("" ::: "memory");
                }
                regs.DATAR.write(.{
                    .DATAR = 0xffff,
                    .padding = 0,
                });

                while (regs.STATR.read().RXNE == 0) {
                    asm volatile ("" ::: "memory");
                }

                buffer[i] = @truncate(regs.DATAR.read().DATAR); // u16
            }
        }

        pub inline fn is_busy(self: @This()) bool {
            _ = self;
            const regs = pin.spi_port_regs;
            return (regs.STATR.read().BSY == 1);
        }

        pub inline fn wait_complete(self: @This()) void {
            _ = self;
            const regs = pin.spi_port_regs;
            while (regs.STATR.read().BSY == 1) {
                asm volatile ("" ::: "memory");
            }
            // reset RXNE if set
            _ = regs.DATAR.raw;
        }

        pub inline fn set_clock_div(self: @This(), div: Clock_div) void {
            // baud rate should not change during communication.
            self.wait_complete();

            const regs = pin.spi_port_regs;
            regs.CTLR1.modify(.{
                .BR = @intFromEnum(div),
            });
        }
    };
}
