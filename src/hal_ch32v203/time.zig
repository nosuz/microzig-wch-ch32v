const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const PFIC = peripherals.PFIC;
const RTC = peripherals.RTC;

const root = @import("root");

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
    const count: u64 = root.__Clocks_freq.hclk / 8 / 1000 * duration;
    PFIC.STK_CNTL.write_raw(@intCast(count & 0xffff_ffff));
    PFIC.STK_CNTH.write_raw(@intCast(count >> 32));

    // start SysTick
    PFIC.STK_CTLR.modify(.{
        .STE = 1,
    });

    // wait
    // while (PFIC.STK_SR.read().CNTIF == 0) {} // makes inifit loop
    while (PFIC.STK_SR.read().CNTIF == 0) {
        asm volatile ("" ::: "memory");
    }

    // stop SysTick
    PFIC.STK_CTLR.modify(.{
        .STE = 0,
    });
}

pub fn get_uptime() u32 {
    // return ms from power-on
    // wait sync
    RTC.CTLRL.modify(.{
        .RSF = 0,
    });
    while (RTC.CTLRL.read().RSF == 0) {
        asm volatile ("" ::: "memory");
    }
    var cntl1 = RTC.CNTL.read().CNTL;
    var cnth = RTC.CNTH.read().CNTH;
    var cntl2 = RTC.CNTL.read().CNTL;
    // check over flow
    if (cntl2 < cntl1) cnth = RTC.CNTH.read().CNTH;
    return (@as(u32, cnth) << 16) + cntl2;
}
