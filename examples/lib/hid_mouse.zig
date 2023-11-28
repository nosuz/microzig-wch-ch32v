// const std = @import("std"); // for debug
const root = @import("root"); // for debug

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbd = ch32v.usbd;
const pins = ch32v.pins;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USB;

// provide device descriptor dat to usbd
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
            if (USB.EP1R.read().CTR_TX == 1) { // IN
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
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = set_tog_tx, // 1: flip; auto toggled
        .STAT_TX = set_tx_nak, // 1: flip
        .EA = 1, // EP1
    });
    // std.log.debug("EP1R: 0x{x:0>4}", .{USB.EP1R.raw});
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
// pub fn CLASS_REQUEST(setup_data: usbd.DESCRIPTOR_REQUEST) void {
//     // device class specific requests
//     if (setup_data.bmRequestType.RequestType == .class) {
//         switch (setup_data.bRequest) {
//             // .GET_INTERFACE => {
//             //     usbd.usb_request = .get_interface;
//             //     usbd.EP0_expect_IN(0);
//             // },
//             else => {
//                 usbd.EP0_clear_interupt();
//             },
//         }
//     } else {
//         usbd.EP0_clear_interupt();
//     }
// }

// handle device class specific EP0 control in packet
// define if custom EP0_CONTROL_IN packet handler is required.
// pub fn EP0_CONTROL_IN() void {
//     switch (usbd.usb_request) {
//         .get_interface => {
//             usbd.EP0_expect_IN(0);
//         },
//         else => usbd.EP0_clear_interupt(),
//     }
// }

// handle device class specific EP0 control out packet
// define if custom EP0_CONTROL_OUT packet handler is required.
// pub fn EP0_CONTROL_OUT() void {
//     usbd.EP0_clear_interupt();
// }

// handle device class specific endpoint packets.
fn EP1_IN() void {
    // clear CTR bit
    USB.EP1R.write(.{
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
        pub fn update(self: @This(), x: i8, y: i8) void {
            _ = self;
            const pin = pins.get_pins(root.pin_config);
            pin.led.toggle();

            const epr = USB.EP1R.read();

            // fill send buffer
            usbd.write_tx(&usbd.ep_buf[1].tx, 0, 0); // button
            usbd.write_tx(&usbd.ep_buf[1].tx, 1, @as(u8, @bitCast(x))); // x
            usbd.write_tx(&usbd.ep_buf[1].tx, 2, @as(u8, @bitCast(y))); // y

            usbd.btable[1].COUNT_TX = 3; // mouse data is 3 bytes
            const set_tx = epr.STAT_TX ^ 0b11; // ACK

            // update EP1R
            USB.EP1R.write(.{
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
    };
}
