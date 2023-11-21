const std = @import("std");
const microzig = @import("microzig");
const usb = @import("usbd.zig");

const ch32v = microzig.hal;
// for debug trigger
const root = @import("root");
const pins = ch32v.pins;

const peripherals = microzig.chip.peripherals;
const USBD = peripherals.USB;

const KeyModifier = packed struct {
    left_ctrl: u1 = 0,
    left_shift: u1 = 0,
    left_alt: u1 = 0,
    left_gui: u1 = 0,
    right_ctrl: u1 = 0,
    right_shift: u1 = 0,
    right_alt: u1 = 0,
    right_gui: u1 = 0,
};

const KeyStatus = struct {
    modifier: KeyModifier,
    code: u8,
};

const KeyboardData = packed struct(u64) {
    modifier: KeyModifier = KeyModifier{},
    _reserved: u8 = 0,
    key1: u8 = 0,
    key2: u8 = 0,
    key3: u8 = 0,
    key4: u8 = 0,
    key5: u8 = 0,
    key6: u8 = 0,
};

const LedStatus = packed struct(u8) {
    NumLock: u1 = 0,
    CapsLock: u1 = 0,
    ScrollLock: u1 = 0,
    Compose: u1 = 0,
    Kana: u1 = 0,
    reserved: u3 = 0,
};

pub fn configure_ep1() void {
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
}

pub fn update_keybaod_led(status: u8) void {
    const pin = pins.get_pins(root.pin_config);
    const led_status = @as(LedStatus, @bitCast(status));
    pin.led.put(led_status.CapsLock);
}

pub fn EP1_IN() void {}
