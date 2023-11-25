const std = @import("std");
const microzig = @import("microzig");
const usb = @import("usbd.zig");

const ch32v = microzig.hal;
// for debug trigger
const root = @import("root");
const pins = ch32v.pins;
const rb = ch32v.ring_buffer;

const peripherals = microzig.chip.peripherals;
const USBD = peripherals.USB;
const RTC = peripherals.RTC;

const Capacity = 128;
const Tx_Buffer = rb.RingBuffer(0, u8, Capacity){};
const Rx_Buffer = rb.RingBuffer(1, u8, Capacity){};

var IN_TX_TRANSACTION = false;
var CONNECTED = false;

// Please help: with format a string with numbers or allocator instance in microzig. #132
// https://github.com/ZigEmbeddedGroup/microzig/issues/132#issuecomment-1662976196
var fmt_buffer: [1024]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(fmt_buffer[0..]);
const allocator = fba.allocator();

pub fn configure_eps() void {
    usb.btable[1].COUNT_TX = 0;

    const ep1r = USBD.EP1R.read();
    // set DTOG to 0
    // Interrupt transfer start from DATA0 and toggle each transfer.
    const set_tog_tx1 = ep1r.DTOG_TX ^ 0;
    // set STAT to ACK
    const set_rx1_disabled = ep1r.STAT_RX ^ 0b00; // DISABLED
    const set_tx1_ack = ep1r.STAT_TX ^ 0b11; // ACK
    USBD.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx1_disabled, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = set_tog_tx1, // 1: flip; auto toggled
        .STAT_TX = set_tx1_ack, // 1: flip
        .EA = 1, // EP1
    });

    // BULK OUT
    const ep2r = USBD.EP2R.read();
    // set DTOG to 0
    const set_tog_rx2 = ep2r.DTOG_RX ^ 0;
    // set STAT to ACK
    const set_rx2_ack = ep2r.STAT_RX ^ 0b11; // ACK
    const set_tx2_disabled = ep2r.STAT_TX ^ 0b00; // DISABLED
    USBD.EP2R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = set_tog_rx2, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx2_ack, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx2_disabled, // 1: flip
        .EA = 2, // EP1
    });

    // BULK IN
    const ep3r = USBD.EP3R.read();
    // set DTOG to 0
    const set_tog_tx3 = ep3r.DTOG_TX ^ 0;
    // set STAT to NAK
    const set_rx3_disabled = ep3r.STAT_RX ^ 0b00; // DISABLED
    const set_tx3_nak = ep3r.STAT_TX ^ 0b10; // NAK for now.
    USBD.EP3R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx3_disabled, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = set_tog_tx3, // 1: flip; auto toggled
        .STAT_TX = set_tx3_nak, // 1: flip
        .EA = 3, // EP1
    });
}

pub fn EP1_IN() void {
    const ep1r = USBD.EP1R.read();
    // set STAT to ACK
    const set_tx1_ack = ep1r.STAT_TX ^ 0b11; // ACK
    USBD.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx1_ack, // 1: flip
        .EA = 1, // EP1
    });
}

pub fn EP3_IN() void {
    set_ep3_tx_data();
}

pub fn EP2_OUT() void {
    const ep2r = USBD.EP2R.read();

    // FIXME: need to respose NAK before full to avoid loose data
    // response NAK if buffer full
    const expected: u2 = if (Rx_Buffer.is_full()) 0b10 else 0b11;
    if (!Rx_Buffer.is_full()) {
        for (0..usb.get_count_rx(usb.btable[2])) |i| {
            Rx_Buffer.write(usb.read_rx(&usb.ep_buf[2].rx, i)) catch {};
        }
    }
    // set STAT to ACK
    const set_rx2_stat = ep2r.STAT_RX ^ expected; // ACK
    USBD.EP2R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx2_stat, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = 0, // 1: flip
        .EA = 2, // EP1
    });
}

pub fn start_tx() void {
    if (Tx_Buffer.is_empty() or IN_TX_TRANSACTION) return;

    set_ep3_tx_data();
}

fn set_ep3_tx_data() void {
    const pin = pins.get_pins(root.pin_config);
    pin.led.toggle();
    var tx_count: u32 = 0;
    for (0..usb.BUFFER_SIZE) |i| {
        const chr = Tx_Buffer.read() catch {
            break;
        };
        usb.write_tx(&usb.ep_buf[3].tx, i, chr);
        tx_count += 1;
    }
    // set next data length
    usb.btable[3].COUNT_TX = tx_count;

    IN_TX_TRANSACTION = if (tx_count > 0) true else false;
    const expected: u2 = if (tx_count > 0) 0b11 else 0b10;
    const ep3r = USBD.EP3R.read();
    // set STAT to ACK
    const set_tx3_stat = ep3r.STAT_TX ^ expected; // ACK or NAK
    USBD.EP3R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx3_stat, // 1: flip
        .EA = 3, // EP1
    });
}

pub fn read() u8 {
    return Rx_Buffer.read_block();
}

pub fn write(chr: u8) void {
    // discard data if connection is closed.
    if (CONNECTED) Tx_Buffer.write_block(chr);
}

pub fn print(comptime fmt: []const u8, args: anytype) !void {
    if (CONNECTED) {
        const string = try std.fmt.allocPrint(
            allocator,
            fmt,
            args,
        );
        defer allocator.free(string);

        for (string) |byte| {
            Tx_Buffer.write_block(byte);
        }
    }
}

pub fn is_readable() bool {
    return !Rx_Buffer.is_empty();
}

pub fn is_writeable() bool {
    return !Tx_Buffer.is_full();
}

pub fn set_connection_state(state: bool) void {
    CONNECTED = state;
}

pub fn is_connected() bool {
    return CONNECTED;
}

pub fn log(
    // RTC required
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime "[{}.{:0>3}] " ++ level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (CONNECTED) {
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
        if (cntl2 < cntl1) cnth = RTC.CNTH.read().CNTH;
        const current_time = (@as(u32, cnth) << 16) + cntl2;
        const seconds = current_time / 1000;
        const microseconds = current_time % 1000;

        print(prefix ++ format ++ "\r\n", .{ seconds, microseconds } ++ args) catch {};
    }
}

pub fn log_no_timestamp(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (CONNECTED) {
        print(prefix ++ format ++ "\r\n", args) catch {};
    }
}
