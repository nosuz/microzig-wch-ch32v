// const std = @import("std"); // for debug
const root = @import("root"); // for debug

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbhd = ch32v.usbhd;
const pins = ch32v.pins;
const rb = ch32v.ring_buffer;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USBHD_DEVICE;

// provide device descriptor dat to usbhd
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
            EP1_IN();
        },
        // unkown endpoints
        else => {},
    }
}

// device specific reset handler
// called at USB bus is reset state.
pub fn reset_endpoints() void {
    USB.R8_UEP4_1_MOD.write_raw(0);

    USB.R8_UEP1_CTRL.modify(.{
        .RB_UEP_R_TOG = 0,
        .RB_UEP_T_TOG = 0,
        .MASK_UEP_R_RES = 0b10, // NAK
        .MASK_UEP_T_RES = 0b10, // NAK
        .RB_UEP_AUTO_TOG = 1,
    });
    USB.R16_UEP1_T_LEN = 0;
}

// configure device. called by SET_CONFIGURATION request.
pub fn set_configuration(setup_value: u16) void {
    _ = setup_value;

    // set DMA buffer for endpoint1
    USB.R16_UEP1_DMA = @truncate(@intFromPtr(&usbhd.ep_buf[1]));

    // enable endpoint1
    USB.R8_UEP4_1_MOD.modify(.{
        .RB_UEP1_RX_EN = 0,

        .RB_UEP1_TX_EN = 1,
        .RB_UEP1_BUF_MOD = 0, // Single buffer
    });
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
pub fn CLASS_REQUEST() void {
    // device class specific requests
    if (usbhd.setup_data.bmRequestType.RequestType == .class) {
        switch (usbhd.setup_data.bRequest) {
            .GET_INTERFACE => {
                usbhd.usb_request = .get_interface;
                usbhd.EP0_expect_IN(0);
            },
            .SET_CONFIGURATION => {
                usbhd.usb_request = .set_configuration;
                usbhd.EP0_expect_OUT();
            },
            else => {},
        }
    }
}

// handle device class specific EP0 control in packet
pub fn EP0_CONTROL_IN() void {
    switch (usbhd.usb_request) {
        .get_interface => {},
        .set_configuration => {},
        else => unreachable,
    }
    // FIXME: expect IN? or OUT?
    // usbhd.EP0_expect_IN(0);
    usbhd.EP0_expect_OUT();
}

// handle device class specific EP0 control out packet
pub fn EP0_CONTROL_OUT() void {
    switch (usbhd.usb_request) {
        .set_configuration => {
            const ep0_buf = &usbhd.ep_buf[0];
            update_keybaod_led(ep0_buf[0]);
        },
        else => unreachable,
    }
    usbhd.EP0_expect_IN(0);
}

// handle device class specific endpoint packets.
fn EP1_IN() void {
    while (KeyBuffer.read()) |key_data| {
        // skip dummy data
        if (key_data._reserved > 0) continue;

        // set another data
        const buf = &usbhd.ep_buf[1];
        const data: [8]u8 = @bitCast(key_data);
        for (0..8) |i| {
            buf[i] = data[i];
        }
        EP1_expect_IN(8);
        break;
    } else |_| {
        // No keyboard data
        USB.R8_UEP1_CTRL.modify(.{
            .MASK_UEP_T_RES = 0b10, // NAK
        });
    }
}

fn EP1_expect_IN(length: u8) void {
    // set next data length
    USB.R16_UEP1_T_LEN = length;

    USB.R8_UEP1_CTRL.modify(.{
        .MASK_UEP_T_RES = 0b00, // ACK
    });
}

pub fn update_keybaod_led(status: u8) void {
    const pin = pins.get_pins(root.pin_config);
    const led_status: LedStatus = @bitCast(status);
    pin.led.put(led_status.NumLock);
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

pub fn USBHD(comptime config: pins.Pin.Configuration) type {
    return struct {
        speed: usbhd.Speed = config.usbhd_speed orelse .Low_speed,
        ep_num: u3 = config.usbhd_ep_num orelse 1,
        buffer_size: usbhd.BufferSize = config.usbhd_buffer_size orelse .byte_8,
        handle_sof: bool = config.usbhd_handle_sof orelse false,

        // mandatory or call directly usbhd.init()
        pub fn init(self: @This()) void {
            _ = self;
            usbhd.init();
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
                const buf = &usbhd.ep_buf[1];
                const data: [8]u8 = @bitCast(key_data);
                for (0..8) |i| {
                    buf[i] = data[i];
                }
                EP1_expect_IN(8);
            } else {
                KeyBuffer.write_block(key_data);
            }
        }
    };
}
