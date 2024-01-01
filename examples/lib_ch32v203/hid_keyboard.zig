// const std = @import("std"); // for debug
const root = @import("root"); // for debug

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbd = ch32v.usbd;
const pins = ch32v.pins;
const rb = ch32v.ring_buffer;

pub const BUFFER_SIZE = usbd.BUFFER_SIZE;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USB;

// provide device descriptor dat to usbd
// variable name is fixed.
pub const descriptors = @import("hid_keyboard_descriptors.zig");

const KEYBUFFER_SIZE = 32;

// add device class specific requests.
pub const bRequest = enum(u8) {
    CLEAR_FEATURE = 1,
    SET_ADDRESS = 5,
    GET_DESCRIPTOR = 6,
    SET_CONFIGURATION = 9,
    // class specific requests
    GET_INTERFACE = 10,
    _,
};

// add state for device class specific requests.
pub const USB_REQUESTS = enum {
    none,
    set_address, // no data transaction
    get_descriptor,
    set_configuration, // no data transaction
    get_interface,
    // add device specific state
};

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

const KeyBuffer = rb.RingBuffer(0, KeyboardData, KEYBUFFER_SIZE){};

const LedStatus = packed struct(u8) {
    NumLock: u1 = 0,
    CapsLock: u1 = 0,
    ScrollLock: u1 = 0,
    Compose: u1 = 0,
    Kana: u1 = 0,
    reserved: u3 = 0,
};

// handle device specific endpoints
pub fn packet_handler(ep_id: u4) void {
    switch (ep_id) {
        1 => { // endpoint 1
            const ep1r = USB.EP1R.read();
            if (ep1r.CTR_TX == 1) { // IN
                EP1_IN();
            }
        },
        // unkown endpoints
        else => {},
    }
}

// device specific reset handler
// called at USB bus is reset state.
// pub fn reset_endpoints() void {
//     // disable endpoint1
//     const ep1r = USB.EP1R.read();
//     // set DTOG to 0
//     const set_tog_tx1 = ep1r.DTOG_TX ^ 0;
//     const set_tog_rx1 = ep1r.DTOG_RX ^ 0;
//     // set STAT to DISABLED
//     const set_rx1_disable = ep1r.STAT_RX ^ 0b00;
//     const set_tx1_disable = ep1r.STAT_TX ^ 0b00;
//     USB.EP1R.write(.{
//         .CTR_RX = 0,
//         .DTOG_RX = set_tog_rx1, // 1: flip; don't care for single buffer
//         .STAT_RX = set_rx1_disable, // 1: flip
//         .SETUP = 0,
//         .EP_TYPE = 0b11, // INTERRUPT
//         .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
//         .CTR_TX = 0,
//         .DTOG_TX = set_tog_tx1, // 1: flip
//         .STAT_TX = set_tx1_disable, // 1: flip
//         .EA = 1, // EP0
//     });
// }

// configure device. called by SET_CONFIGURATION request.
pub fn set_configuration(setup_value: u16) void {
    _ = setup_value;

    usbd.btable[1].COUNT_TX = 0;

    const epr = USB.EP1R.read();
    // set DTOG to 0
    // Interrupt transfer start from DATA0 and toggle each transfer.
    const set_tog_tx = epr.DTOG_TX ^ 0;
    // set STAT to NAK
    const set_rx_disabled = epr.STAT_RX ^ 0b00; // DISABLED
    const set_tx_nak = epr.STAT_TX ^ 0b10; // NAK for now.
    USB.EP1R.write(.{
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

// called recieved SOF packet.
// define if custom SOF packet handler is required.
// pub fn SOF() void {}

// dispatch device class specific GET_DESCRIPTOR request
pub fn DISPATCH_DESCRIPTOR(setup_value: u16) ?descriptors.DescriptorIndex {
    return switch (setup_value) {
        0x2200 => .report, // return report descriptor
        else => null,
    };
}

// handle device class specific SETUP requests.
pub fn CLASS_REQUEST(setup_data: usbd.DESCRIPTOR_REQUEST) void {
    // device class specific requests
    if (setup_data.bmRequestType.RequestType == .class) {
        switch (setup_data.bRequest) {
            .GET_INTERFACE => {
                usbd.usb_request = .get_interface;
                usbd.EP0_expect_IN(0);
            },
            .SET_CONFIGURATION => {
                usbd.usb_request = .set_configuration;
                usbd.EP0_expect_DATA_OUT();
            },
            else => {
                usbd.EP0_clear_interupt();
            },
        }
    } else {
        usbd.EP0_clear_interupt();
    }
}

// handle device class specific EP0 control in packet
// pub fn EP0_CONTROL_IN() void {
//     switch (usbd.usb_request) {
//         .get_interface => {
//             usbd.EP0_expect_IN(0);
//         },
//         .set_configuration => {
//             usbd.EP0_expect_IN(0);
//         },
//         else => unreachable,
//     }
// }

// handle device class specific EP0 control out packet
pub fn EP0_CONTROL_OUT() void {
    switch (usbd.usb_request) {
        .set_configuration => {
            update_keybaod_led(usbd.read_rx(&usbd.ep_buf[0].rx, 0));
            usbd.EP0_expect_IN(0);
        },
        else => {
            usbd.EP0_expect_DATA_OUT();
        },
    }
}

// handle device class specific endpoint packets.
fn EP1_IN() void {
    while (KeyBuffer.read()) |key_data| {
        // skip dummy data
        if (key_data._reserved > 0) continue;

        // set another data
        const data = @as([8]u8, @bitCast(key_data));
        for (0..8) |i| {
            usbd.write_tx(&usbd.ep_buf[1].tx, i, data[i]);
        }
        EP1_expect_IN(8);
        break;
    } else |_| {
        EP1_clear_interrupt();
    }
}

fn EP1_expect_IN(length: u32) void {
    // set next data length
    usbd.btable[1].COUNT_TX = length;

    const epr = USB.EP1R.read();

    // 1 ^ 1 -> 0, 0 ^ 1 -> 1 then flip and (0 -> 1)
    // make bit pattern to make expected status.
    const set_tx_ack = epr.STAT_TX ^ 0b11;
    USB.EP1R.write(.{
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
    USB.EP1R.write(.{
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

pub fn update_keybaod_led(status: u8) void {
    const pin = pins.get_pins(root.pin_config);
    const led_status = @as(LedStatus, @bitCast(status));
    pin.led.put(led_status.CapsLock);
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

pub fn USBD(comptime config: pins.Pin.Configuration) type {
    return struct {
        speed: usbd.Speed = config.usbd_speed orelse .Low_speed,
        ep_num: u3 = config.usbd_ep_num orelse 1,
        buffer_size: usbd.BufferSize = config.usbd_buffer_size orelse .byte_8,
        handle_sof: bool = config.usbd_handle_sof orelse false,

        // mandatory or call directly usbd.init()
        pub fn init(self: @This()) void {
            _ = self;
            usbd.init();
        }

        // device class specific methods
        pub fn send_keycodes(self: @This(), key_data: KeyboardData) void {
            _ = self;
            if (KeyBuffer.is_empty()) {
                // push dummy data
                const dummy = KeyboardData{
                    ._reserved = 1,
                };
                KeyBuffer.write(dummy) catch {}; // should no fail

                // write data directly into RX buffer
                const data = @as([8]u8, @bitCast(key_data));
                for (0..8) |i| {
                    usbd.write_tx(&usbd.ep_buf[1].tx, i, data[i]);
                }
                EP1_expect_IN(8);
            } else {
                KeyBuffer.write_block(key_data);
            }
        }
    };
}
