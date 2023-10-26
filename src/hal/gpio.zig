const pins = @import("pins.zig");

pub const Port = enum { PA, PB, PC, PD };

pub const Direction = enum(u1) {
    in,
    out,
};

pub const Pull = enum {
    up,
    down,
};

pub fn GPIO(comptime pin_name: []const u8, comptime direction: Direction) type {
    return switch (direction) {
        .in => struct {
            const pin = pins.parse_pin(pin_name);

            pub inline fn read(self: @This()) u1 {
                _ = self;
                var reg = pin.gpio_port;
                return @field(reg.read(), "IDR" ++ pin.gpio_suffix);
            }
        },
        .out => struct {
            const pin = pins.parse_pin(pin_name);

            pub inline fn read(self: @This()) u1 {
                _ = self;
                var reg = pin.gpio_port_regs.OUTDR;
                return @field(reg.read(), "ODR" ++ pin.gpio_suffix);
            }

            pub inline fn put(self: @This(), value: u1) void {
                _ = self;
                var reg = pin.gpio_port_regs.OUTDR;
                // var reg = @field(pin.gpio_port, "OUTDR");
                var temp = reg.read();
                @field(temp, "ODR" ++ pin.gpio_suffix) = value;
                pin.gpio_port_regs.OUTDR.write(temp); // sw	a2,-2036(a0)
                // reg.write(temp); // sw	a2,8(sp)
            }

            pub inline fn toggle(self: @This()) void {
                _ = self;
                var reg = pin.gpio_port_regs.OUTDR;
                var temp = reg.read();
                var value = @field(temp, "ODR" ++ pin.gpio_suffix);
                @field(temp, "ODR" ++ pin.gpio_suffix) = ~value;
                pin.gpio_port_regs.OUTDR.write(temp); // sw  a3,-2036(a0)
                // reg.write(temp); // sw  a3,12(sp)
            }
        },
    };
}
