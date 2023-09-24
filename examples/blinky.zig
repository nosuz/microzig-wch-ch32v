const microzig = @import("microzig");

// `microzig.config`: comptime access to configuration
// `microzig.chip`: access to register definitions, generated code
// `microzig.board`: access to board information
// `microzig.hal`: access to hand-written code for interacting with the hardware
// `microzig.cpu`: access to AVR5 specific functions
const peripherals = microzig.chip.peripherals;

var speed: u32 = 10;

pub fn main() !void {
    // RCC_APB2PCENR.* |= @as(u32, 1 << 2);
    peripherals.RCC.APB2PCENR.modify(.{ .IOPAEN = 1 });
    // GPIOA_CFGHR.* &= ~@as(u32, 0b1111 << 4);
    // GPIOA_CFGHR.* |= @as(u32, 0b0011 << 4);
    const gpioa = peripherals.GPIOA;
    gpioa.CFGHR.modify(.{ .CNF9 = 0b00, .MODE9 = 0b11 });

    while (true) {
        busyloop((speed + 1) * 100_000);
        // busyloop();
        // pub const GPIOA_OUTDR = @as(*volatile u16, @ptrFromInt(0x4001080C));

        // How do I use toggle function?
        // gpioa.OUTDR.toggle(.{.ODR9});

        var val = gpioa.OUTDR.read();
        switch (val.ODR9) {
            0 => gpioa.OUTDR.modify(.{ .ODR9 = 1 }),
            1 => gpioa.OUTDR.modify(.{ .ODR9 = 0 }),
        }
        speed -= 1;
        if (speed == 0) {
            speed = 10;
        }
    }
}

fn busyloop(limit: u32) void {
    // fn busyloop() void {
    //     const limit = 500_000;

    var i: u32 = 0;
    while (i < limit) : (i += 1) {
        asm volatile ("" ::: "memory");
    }
}

// export fn interrupts_handler() void {
//     busyloop();
// }
