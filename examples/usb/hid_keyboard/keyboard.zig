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

pub const KeyModifier = packed struct {
    left_ctrl: u1 = 0,
    left_shift: u1 = 0,
    left_alt: u1 = 0,
    left_gui: u1 = 0,
    right_ctrl: u1 = 0,
    right_shift: u1 = 0,
    right_alt: u1 = 0,
    right_gui: u1 = 0,
};

pub const KeyboardData = packed struct(u64) {
    modifier: KeyModifier = KeyModifier{},
    _reserved: u8 = 0,
    key1: u8 = 0,
    key2: u8 = 0,
    key3: u8 = 0,
    key4: u8 = 0,
    key5: u8 = 0,
    key6: u8 = 0,
};

const Capacity = 32;
const KeyBuffer = rb.RingBuffer(KeyboardData, Capacity){};

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
        .EP_KIND = 0, // ignored on INTERRUPT#
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

pub fn EP1_IN() void {
    while (KeyBuffer.read()) |key_data| {
        // skip dummy data
        if (key_data._reserved > 0) continue;

        // set another data
        const data = @as([8]u8, @bitCast(key_data));
        for (0..8) |i| {
            usb.write_tx(&usb.ep_buf[1].tx, i, data[i]);
        }
        EP1_expect_IN(8);
        break;
    } else |_| {
        EP1_clear_interrupt();
    }
}

fn EP1_expect_IN(length: u32) void {
    // set next data length
    usb.btable[1].COUNT_TX = length;

    const epr = USBD.EP1R.read();

    // 1 ^ 1 -> 0, 0 ^ 1 -> 1 then flip and (0 -> 1)
    // make bit pattern to make expected status.
    const set_tx_ack = epr.STAT_TX ^ 0b11;
    USBD.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; auto toggled
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx_ack, // 1: flip
        .EA = 1, // EP1
    });
}

fn EP1_clear_interrupt() void {
    USBD.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; auto toggled
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = 0, // 1: flip
        .EA = 1, // EP1
    });
}

pub fn send_keycodes(key_data: KeyboardData) void {
    if (KeyBuffer.is_empty()) {
        // push dummy data
        const dummy = KeyboardData{
            ._reserved = 1,
        };
        KeyBuffer.write(dummy) catch {}; // should no fail

        // write data directly into RX buffer
        const data = @as([8]u8, @bitCast(key_data));
        for (0..8) |i| {
            usb.write_tx(&usb.ep_buf[1].tx, i, data[i]);
        }
        EP1_expect_IN(8);
    } else {
        // push data into buffer
        while (true) {
            if (KeyBuffer.write(key_data)) {
                break;
            } else |_| {} // busy wait untile write OK
        }
    }
}

pub fn ascii_to_usb_keycode(ascii_code: u8) ?KeyboardData {
    // look Keytop char (Japanese A01/106/109A) and return USB HID Usage ID
    // http://hp.vector.co.jp/authors/VA003720/lpproj/others/kbdjpn.htm
    return switch (ascii_code) {
        'a'...'z' => KeyboardData{
            // Convert lowercase letters (a-z)
            .key1 = ascii_code - 'a' + 4,
        },
        'A'...'Z' => KeyboardData{
            // Convert uppercase letters (A-Z)
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = ascii_code - 'A' + 4,
        },
        '1'...'9' => KeyboardData{
            // Convert numeric digits (1-9)
            .key1 = ascii_code - '1' + 30,
        },
        '0' => KeyboardData{
            // Convert digit 0
            .key1 = 39,
        },
        '\n' => KeyboardData{
            // Convert newline character
            .key1 = 40,
        },
        ' ' => KeyboardData{
            //  Convert space character
            .key1 = 44,
        },
        '!' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 30,
        },
        '"' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 31,
        },
        '#' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 32,
        },
        '$' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 33,
        },
        '%' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 34,
        },
        '&' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 35,
        },
        '\'' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 36,
        },
        '(' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 37,
        },
        ')' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 38,
        },
        '@' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 47,
        },
        '/' => KeyboardData{
            .key1 = 0x38,
        },
        '>' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 0x37,
        },
        '<' => KeyboardData{
            .modifier = KeyModifier{ .left_shift = 1 },
            .key1 = 0x36,
        },
        else => null, // Ignore other characters
    };
}
