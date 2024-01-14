// const std = @import("std"); // for debug
const root = @import("root"); // for debug

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbd = ch32v.usbd;
const pins = ch32v.pins;

pub const BUFFER_SIZE = usbd.BUFFER_SIZE;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USB;

// provide device descriptor dat to usbd
// variable name is fixed.
pub const descriptors = @import("msc_sd_descriptors.zig");

const MAX_LUN = 0;

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

const ClassRequest = enum(u8) {
    BULK_ONLY_MASS_STORAGE_RESET = 0xff,
    GET_MAX_LUN = 0xfe,
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

const Bulk_only_state = enum {
    command,
    data,
    status,
};

var bulk_state: Bulk_only_state = .command;

// 31 bytes
const CBW = packed struct(u248) {
    dCBWSignature: u32,
    dCBWTag: u32,
    dCBWDataTransferLength: u32,
    bmCBWFlags: u8,
    //
    bCBWLUN: u4,
    reserved0: u4,
    //
    bCBWCBLength: u5,
    reserved1: u3,
    //
    CDB_op: SCSI_COMMAND,
    // CDB_args: [15]u8, // not allowed
    CDB_args: u120,
};

const SCSI_COMMAND = enum(u8) {
    unknown = 0xff,
    test_unit_ready = 0x00,
    inquiry = 0x12,
    request_sense = 0x03,
    read_capacity = 0x25,
    read = 0x28, // READ (10)
    write = 0x2a, // WRITE (10)
    mode_send = 0x5a, // MODE SENSE (10)
    _,
};

var cbw: CBW = undefined;
var send_index: usize = 0;

// 13 bytes
const CSW = packed struct(u104) {
    dCSWSignature: u32 = 0x5342_5355,
    dCSWTag: u32,
    dCSWDataResidue: u32 = 0, // default no residue
    bCSWStatus: u8 = 0, // default 0: OK
};

// handle device specific endpoints
pub fn packet_handler(ep_id: u4) void {
    switch (ep_id) {
        1 => { // endpoint 1
            EP1_IN();
        },
        2 => { // endpoint 2
            EP2_OUT();
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
//         .EP_TYPE = 0b00, // BULK
//         .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
//         .CTR_TX = 0,
//         .DTOG_TX = set_tog_tx1, // 1: flip
//         .STAT_TX = set_tx1_disable, // 1: flip
//         .EA = 1, // EP0
//     });

//     // disable endpoint2
//     const ep2r = USB.EP2R.read();
//     // set DTOG to 0
//     const set_tog_tx2 = ep2r.DTOG_TX ^ 0;
//     const set_tog_rx2 = ep2r.DTOG_RX ^ 0;
//     // set STAT to DISABLED
//     const set_rx2_disable = ep2r.STAT_RX ^ 0b00;
//     const set_tx2_disable = ep2r.STAT_TX ^ 0b00;
//     USB.EP2R.write(.{
//         .CTR_RX = 0,
//         .DTOG_RX = set_tog_rx2, // 1: flip; don't care for single buffer
//         .STAT_RX = set_rx2_disable, // 1: flip
//         .SETUP = 0,
//         .EP_TYPE = 0b00, // BULK
//         .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
//         .CTR_TX = 0,
//         .DTOG_TX = set_tog_tx2, // 1: flip
//         .STAT_TX = set_tx2_disable, // 1: flip
//         .EA = 2, // EP0
//     });
// }

// configure device. called by SET_CONFIGURATION request.
pub fn set_configuration(setup_value: u16) void {
    _ = setup_value;

    bulk_state = .command;

    usbd.btable[1].COUNT_TX = 0;

    const ep1r = USB.EP1R.read();
    // set DTOG to 0
    // Interrupt transfer start from DATA0 and toggle each transfer.
    const set_tog_tx1 = ep1r.DTOG_TX ^ 0;
    // set STAT
    const set_tx1_nak = ep1r.STAT_TX ^ 0b10; // NAK for now
    const set_rx1_disable = ep1r.STAT_RX ^ 0b00; // disable
    USB.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx1_disable, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // 1: double buffer for BULK
        .CTR_TX = 0,
        .DTOG_TX = set_tog_tx1, // 1: flip; auto toggled
        .STAT_TX = set_tx1_nak, // 1: flip
        .EA = 1, // EP1
    });

    // usbd.btable[2].COUNT_TX = 0;
    const ep2r = USB.EP2R.read();
    // set DTOG to 0
    const set_tog_rx2 = ep2r.DTOG_RX ^ 0;
    // set STAT
    const set_rx2_ack = ep2r.STAT_RX ^ 0b11; // ACK
    const set_tx2_disable = ep2r.STAT_TX ^ 0b00; // DISABLE
    USB.EP2R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = set_tog_rx2, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx2_ack, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // 1: double buffer for BULK
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip
        .STAT_TX = set_tx2_disable, // 1: flip
        .EA = 2, // EP0
    });
}

// called recieved SOF packet.
// define if custom SOF packet handler is required.
// pub fn SOF() void {}

// dispatch device class specific GET_DESCRIPTOR request
// pub fn DISPATCH_DESCRIPTOR(setup_value: u16) ?descriptors.DescriptorIndex {
//     return switch (setup_value) {
//         0x2200 => .report, // return report descriptor
//         else => null,
//     };
// }

// handle device class specific SETUP requests.
pub fn CLASS_REQUEST(setup_data: usbd.DESCRIPTOR_REQUEST) void {
    // device class specific requests
    if (setup_data.bmRequestType.RequestType == .class) {
        // const request = @as(ClassRequest, @bitCast(setup_data.bRequest)); // not work
        const request: ClassRequest = @enumFromInt(@intFromEnum(setup_data.bRequest));
        switch (request) {
            .BULK_ONLY_MASS_STORAGE_RESET => {
                set_configuration(1);
                usbd.usb_request = .set_configuration;
                usbd.EP0_clear_interupt();
            },
            .GET_MAX_LUN => {
                usbd.write_tx(&usbd.ep_buf[0].tx, 0, MAX_LUN);
                usbd.EP0_expect_IN(1);
            },
            else => {
                usbd.EP0_clear_interupt();
            },
        }
    } else {
        usbd.EP0_clear_interupt();
    }
}

fn send_data(length: u32) void {
    usbd.btable[1].COUNT_TX = length;

    const ep1r = USB.EP1R.read();
    // set STAT
    const set_tx1_ack = ep1r.STAT_TX ^ 0b11; // ACK
    USB.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // 1: double buffer for BULK
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx1_ack, // 1: flip
        .EA = 1, // EP1
    });
}

fn send_nak() void {
    const ep1r = USB.EP1R.read();
    // set STAT to ACK
    const set_tx1_nak = ep1r.STAT_TX ^ 0b11; // NAK
    USB.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // 1: double buffer for BULK
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx1_nak, // 1: flip
        .EA = 1, // EP1
    });
}

fn send_stuffing() void {
    // SCSI is a big endian and the CH32V is a little endian.
    const requested_length: u32 = @byteSwap(@as(u32, @truncate(cbw.CDB_args >> 40)));
    // const last_point = if ((requested_length - send_index) > usbd.BUFFER_SIZE) send_index + BUFFER_SIZE else requested_length;
    const stuff_size = if ((requested_length - send_index) > usbd.BUFFER_SIZE) usbd.BUFFER_SIZE else requested_length - send_index;
    if (stuff_size == 0) {
        const csw = CSW{
            .dCSWTag = cbw.dCBWTag,
            .bCSWStatus = 0x01,
        };
        const unkown_op: [13]u8 = @bitCast(csw);
        for (0..unkown_op.len) |i| {
            usbd.write_tx(&usbd.ep_buf[1].tx, i, unkown_op[i]);
        }
        send_data(unkown_op.len);
        send_index = 0;
        bulk_state = .status;
    } else {
        for (0..usbd.BUFFER_SIZE) |i| {
            usbd.write_tx(&usbd.ep_buf[1].tx, i, 0);
        }
        send_data(usbd.BUFFER_SIZE);
        send_index += stuff_size;
        bulk_state = .data;
    }
}

pub fn EP1_IN() void {
    switch (bulk_state) {
        .command => {
            send_nak();
        },
        .data => {
            switch (cbw.CDB_op) {
                .unknown => send_stuffing(),
                .inquiry => {
                    const csw = CSW{
                        .dCSWTag = cbw.dCBWTag,
                    };
                    const buf: [13]u8 = @bitCast(csw);
                    for (0..buf.len) |i| {
                        usbd.write_tx(&usbd.ep_buf[1].tx, i, buf[i]);
                    }
                    send_data(buf.len);
                    bulk_state = .status;
                },
                else => {
                    bulk_state = .command;
                    send_nak();
                },
            }
        },
        .status => {
            bulk_state = .command;
            send_nak();
        },
    }
}

pub fn EP2_OUT() void {
    switch (bulk_state) {
        .command => {
            var buf: [31]u8 = undefined;
            for (0..buf.len) |i| {
                buf[i] = usbd.read_rx(&usbd.ep_buf[2].rx, i);
            }

            cbw = @bitCast(buf);
            switch (cbw.CDB_op) {
                .inquiry => {
                    for (0..descriptors.InquiryResponse.len) |i| {
                        usbd.write_tx(&usbd.ep_buf[1].tx, i, descriptors.InquiryResponse[i]);
                    }
                    send_data(descriptors.InquiryResponse.len);
                    bulk_state = .data;
                },
                .test_unit_ready => {
                    const csw = CSW{
                        .dCSWTag = cbw.dCBWTag,
                    };
                    const test_unit_ready: [13]u8 = @bitCast(csw);
                    for (0..test_unit_ready.len) |i| {
                        usbd.write_tx(&usbd.ep_buf[1].tx, i, test_unit_ready[i]);
                    }
                    send_data(test_unit_ready.len);
                    bulk_state = .status;
                },
                else => {
                    send_stuffing();
                },
            }
        },
        .data => {},
        .status => {},
    }

    const ep2r = USB.EP2R.read();
    // set STAT to ACK
    const set_rx2_ack = ep2r.STAT_RX ^ 0b11; // ACK
    USB.EP2R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx2_ack, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // 1: double buffer for BULK
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = 0, // 1: flip
        .EA = 2, // EP2
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
    };
}
