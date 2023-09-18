const std = @import("std");
const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const PFIC = peripherals.PFIC;

pub fn sleep_ms(duration: u16) void {
    // STK_CTLR
    PFIC.STK_CTLR.modify(.{
        .MODE = 1, // 1: downcount, 0: upcount
        .STCLK = 0, // 1: HCLK, 0: HCLK/8
        .STE = 0,
    });

    PFIC.STK_SR.modify(.{
        .CNTIF = 0,
    });

    // STK_CNTL STK_CNTH
    var count: u64 = microzig.hal.rcc.Clocks.hclk_freq / 8 / 1000 * duration;
    PFIC.STK_CNTL.write_raw(@intCast(count & 0xffff_ffff));
    PFIC.STK_CNTH.write_raw(@intCast(count >> 32));

    // start SysTick
    PFIC.STK_CTLR.modify(.{
        .STE = 1,
    });

    // wait
    // while (PFIC.STK_SR.read().CNTIF == 0) {} // makes inifit loop
    var i: u32 = 0;
    while (PFIC.STK_SR.read().CNTIF == 0) : (i += 1) {
        @import("std").mem.doNotOptimizeAway(i);
    }

    // start SysTick
    PFIC.STK_CTLR.modify(.{
        .STE = 0,
    });
}
