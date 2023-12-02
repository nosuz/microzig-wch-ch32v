const microzig = @import("microzig");
const peripherals = microzig.chip.peripherals;
const PFIC = peripherals.PFIC;
const RTC = peripherals.RTC;

const root = @import("root");

pub fn sleep_ms(duration: u16) void {
    // Max around 65 sec.

    // STK_CTLR stop
    PFIC.STK_CTLR.modify(.{
        .STE = 0,
    });

    // STK_CNTL STK_CNTH
    const STK_CNTL = 0xE000F004;
    const STK_CNTH = 0xE000F008;
    const count: u64 = root.__Clocks_freq.hclk / 8 / 1000 * duration;
    const set_count: u32 = @truncate(0xffff_ffff - count + 1);
    // PFIC.STK_CNTL.write_raw(@intCast(0xffff_ffff - count + 1));
    // PFIC.STK_CNTH.write_raw(0);
    // CNTL and CNTH can modify only each bytes.
    const cntl: [*]volatile u8 = @ptrFromInt(STK_CNTL);
    const cnth: [*]volatile u8 = @ptrFromInt(STK_CNTH);
    for (0..4) |i| {
        cntl[i] = @truncate((set_count >> @as(u5, @truncate((i * 8)))) & 0xff);
        cnth[i] = 0;
    }

    // start SysTick
    PFIC.STK_CTLR.modify(.{
        .STE = 1,
    });

    // wait overflow u32
    while (PFIC.STK_CNTH.raw == 0) {
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
