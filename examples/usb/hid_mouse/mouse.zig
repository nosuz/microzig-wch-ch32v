const std = @import("std");
const microzig = @import("microzig");
const usb = @import("usbd.zig");

const ch32v = microzig.hal;
// for debug trigger
const root = @import("root");
const pins = ch32v.pins;

const peripherals = microzig.chip.peripherals;
const USBD = peripherals.USB;

pub fn configure(ep: u8) void {
    switch (ep) {
        1 => {
            usb.btable[1].COUNT_TX = 0;

            const epr = USBD.EP1R.read();
            // set DTOG to 0
            // Interrupt transfer start from DATA0 and toggle each transfer.
            const set_tog_tx = epr.DTOG_TX ^ 0;
            // set STAT to NAK
            const set_rx_disabled = epr.STAT_RX ^ 0b00; // DISABLED
            const set_tx_nak = epr.STAT_TX ^ 0b10; // NAK for now.
            USBD.EP1R.write(.{
                .CTR_RX = 0,
                .DTOG_RX = 0, // 1: flip; don't care for single buffer
                .STAT_RX = set_rx_disabled, // 1: flip
                .SETUP = 0,
                .EP_TYPE = 0b11, // INTERRUPT
                .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
                .CTR_TX = 0,
                .DTOG_TX = set_tog_tx, // 1: flip; auto toggled
                .STAT_TX = set_tx_nak, // 1: flip
                .EA = 1, // EP1
            });
            // std.log.debug("EP1R: 0x{x:0>4}", .{USBD.EP1R.raw});
        },
        else => {},
    }
}

pub fn EP1_IN() void {
    // clear CTR bit
    USBD.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = 0, // 1: flip
        .EA = 1, // EP1
    });
}

pub fn update(x: i8, y: i8) void {
    const pin = pins.get_pins(root.pin_config);
    pin.led.toggle();

    const epr = USBD.EP1R.read();

    // fill send buffer
    usb.write_tx(&usb.ep_buf[1].tx, 0, 0); // button
    usb.write_tx(&usb.ep_buf[1].tx, 1, @as(u8, @bitCast(x))); // x
    usb.write_tx(&usb.ep_buf[1].tx, 2, @as(u8, @bitCast(y))); // y

    usb.btable[1].COUNT_TX = 3; // mouse data is 3 bytes
    const set_tx = epr.STAT_TX ^ 0b11; // ACK

    // update EP1R
    USBD.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx, // 1: flip
        .EA = 1, // EP1
    });
}
