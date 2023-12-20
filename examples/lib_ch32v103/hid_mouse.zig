// const std = @import("std"); // for debug
const root = @import("root"); // for debug

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbhd = ch32v.usbhd;
const pins = ch32v.pins;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USBHD_DEVICE;

// provide device descriptor dat to usbhd
// variable name is fixed.
pub const descriptors = @import("hid_mouse_descriptors.zig");

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
// pub fn CLASS_REQUEST() void {
// device class specific requests
// switch (usbhd.setup_data.bRequest) {
//     // .GET_INTERFACE => {
//     //     usbhd.usb_request = .get_interface;
//     //     usbhd.EP0_expect_IN(0);
//     // },
//     else => {},
// }
// }

// handle device class specific EP0 control in packet
// define if custom EP0_CONTROL_IN packet handler is required.
// pub fn EP0_CONTROL_IN() void {
//     switch (usbhd.usb_request) {
//         .get_interface => {},
//         else => unreachable,
//     }
//     usbhd.EP0_expect_IN(0);
// }

// handle device class specific EP0 control out packet
// define if custom EP0_CONTROL_OUT packet handler is required.
// pub fn EP0_CONTROL_OUT() void {
// }

// handle device class specific endpoint packets.
fn EP1_IN() void {
    // sent mouse data
    USB.R16_UEP1_T_LEN = 0;

    USB.R8_UEP1_CTRL.modify(.{
        .MASK_UEP_T_RES = 0b10, // NAK
    });
}

pub fn USBHD(comptime config: pins.Pin.Configuration) type {
    return struct {
        speed: usbhd.Speed = config.usbhd_speed orelse .Low_speed,
        ep_num: u3 = config.usbhd_ep_num orelse 1,
        buffer_size: usbhd.BufferSize = config.usbhd_buffer_size orelse .byte_8,
        handle_sof: bool = config.usbhd_handle_sof orelse false,

        // mandatory or call directly usbhd.init()
        pub fn init(self: @This()) void {
            usbhd.init(self.speed);
        }

        // device class specific methods
        pub fn update(self: @This(), x: i8, y: i8) void {
            _ = self;
            // const pin = pins.get_pins(root.pin_config);
            // pin.led.toggle();

            // // fill send buffer
            const buf = &usbhd.ep_buf[1];
            buf[0] = 0;
            buf[1] = @bitCast(x);
            buf[2] = @bitCast(y);

            USB.R16_UEP1_T_LEN = 3;

            USB.R8_UEP1_CTRL.modify(.{
                .MASK_UEP_T_RES = 0b00, // ACK
            });
        }
    };
}
