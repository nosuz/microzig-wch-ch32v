const std = @import("std"); // for debug
const root = @import("root");

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbd = ch32v.usbd;
const pins = ch32v.pins;
const sdcard = ch32v.sdcard;

pub const BUFFER_SIZE = usbd.BUFFER_SIZE;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USB;

const pin = pins.get_pins(root.pin_config);

// provide device descriptor dat to usbd
// variable name is fixed.
pub const descriptors = @import("msc_sd_descriptors.zig");

const MAX_LUN = 0;

const sd_card = sdcard.SDCARD_DRIVER("spi", "cs");

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

// FIXME: separate requests to common and class spesific.
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
    dCBWDataTransferLength: u32, // big endian
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
    prevent_allow_medium_removal = 0x1e,
    read = 0x28, // READ (10)
    write = 0x2a, // WRITE (10)
    start_stop_unit = 0x1b,
    mode_sense = 0x1a, // MODE SENSE (6) return error status for now.
    _,
};

var cbw: CBW = undefined;
var buffer_index: usize = 0;

const MAX_SECTOR_NUM = 8;
var sector_buffer: [sdcard.SECTOR_SIZE * MAX_SECTOR_NUM]u8 = undefined;

var requested_lba: u32 = 0;
var requested_num: u16 = 0;
var transfered_num: u16 = 0;
var transfer_error: bool = false;

// 13 bytes
const CSW = packed struct(u104) {
    dCSWSignature: u32 = 0x5342_5355,
    dCSWTag: u32,
    dCSWDataResidue: u32 = 0, // default no residue
    bCSWStatus: CSW_STATUS = .good, // default 0: OK
};

const CSW_STATUS = enum(u8) {
    good = 0,
    command_error = 1,
    phase_error = 2,
    _,
};

var in_use_status: u1 = 0;

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
        .EA = 2, // EP2
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

fn send_csw(status: CSW_STATUS) void {
    const csw = CSW{
        .dCSWTag = cbw.dCBWTag,
        .bCSWStatus = status,
    };
    const csw_buffer: [13]u8 = @bitCast(csw);
    for (0..csw_buffer.len) |i| {
        usbd.write_tx(&usbd.ep_buf[1].tx, i, csw_buffer[i]);
    }
    send_data(csw_buffer.len);
    bulk_state = .status;
}

fn send_stuffing() void {
    // SCSI is a big endian and the CH32V is a little endian.
    var stuff_size = cbw.dCBWDataTransferLength - buffer_index;
    if (stuff_size > usbd.BUFFER_SIZE) stuff_size = usbd.BUFFER_SIZE;

    if (stuff_size == 0) {
        send_csw(.command_error);
    } else {
        for (0..stuff_size) |i| {
            usbd.write_tx(&usbd.ep_buf[1].tx, i, 0);
        }
        send_data(stuff_size);
        buffer_index += stuff_size;
        bulk_state = .data;
    }
}

pub fn EP1_IN() void {
    switch (bulk_state) {
        .command => {},
        .data => {
            switch (cbw.CDB_op) {
                .unknown => send_stuffing(),
                .inquiry => {
                    send_csw(.good);
                },
                .read_capacity => {
                    send_csw(.good);
                },
                .request_sense => {
                    send_csw(.good);
                },
                .read => {
                    if (transfered_num == requested_num) {
                        // transfered all, send status
                        send_csw(if (transfer_error) .phase_error else .good);
                    } else {
                        // send next data
                        if (buffer_index == sector_buffer.len) {
                            pin.in_use.toggle();
                            // read new data
                            var read_sector_num = requested_num - transfered_num;
                            if (read_sector_num > MAX_SECTOR_NUM) read_sector_num = MAX_SECTOR_NUM;
                            sd_card.read_multi(requested_lba + transfered_num, sector_buffer[0..(read_sector_num * sdcard.SECTOR_SIZE)]) catch {
                                // SD card read error
                                transfer_error = true;
                            };
                            buffer_index = 0;
                        }
                        // send buffered data
                        for (0..BUFFER_SIZE) |i| {
                            usbd.write_tx(&usbd.ep_buf[1].tx, i, sector_buffer[buffer_index + i]);
                        }
                        send_data(BUFFER_SIZE);
                        buffer_index += BUFFER_SIZE;
                        if ((buffer_index % sdcard.SECTOR_SIZE) == 0) transfered_num += 1;
                    }
                },
                .mode_sense => {
                    send_csw(.good);
                },

                else => {
                    send_stuffing();
                },
            }
        },
        .status => {
            bulk_state = .command;
            pin.in_use.put(in_use_status);
        },
    }

    // reset interrupt flags
    USB.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // 1: double buffer for BULK
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = 0, // 1: flip
        .EA = 1, // EP1
    });
}

pub fn EP2_OUT() void {
    switch (bulk_state) {
        .command => {
            var buf: [31]u8 = undefined;
            for (0..buf.len) |i| {
                buf[i] = usbd.read_rx(&usbd.ep_buf[2].rx, i);
            }

            cbw = @bitCast(buf);
            buffer_index = 0;
            switch (cbw.CDB_op) {
                .inquiry => {
                    for (0..descriptors.InquiryResponse.len) |i| {
                        usbd.write_tx(&usbd.ep_buf[1].tx, i, descriptors.InquiryResponse[i]);
                    }
                    send_data(descriptors.InquiryResponse.len);
                    bulk_state = .data;
                },
                .test_unit_ready => {
                    send_csw(.good);
                },
                .read_capacity => {
                    var cap_param = [8]u8{ 0, 0, 0, 0, 0, 0, 2, 0 };
                    const vol_size = sd_card.volume_size() catch 0;
                    if (vol_size == 0) {
                        send_stuffing();
                    } else {
                        // READ CAPACITY returns LAST LBA address. not a volume size.
                        const last_lba = @as(u32, @truncate(vol_size / sdcard.SECTOR_SIZE)) - 1;
                        for (0..4) |i| {
                            cap_param[i] = @truncate(last_lba >> @truncate(8 * (3 - i)));
                        }
                        // set reply data
                        for (0..cap_param.len) |i| {
                            usbd.write_tx(&usbd.ep_buf[1].tx, i, cap_param[i]);
                        }
                        send_data(cap_param.len);
                        bulk_state = .data;
                    }
                },
                .prevent_allow_medium_removal => {
                    // indicate in use
                    in_use_status = @truncate((cbw.CDB_args >> 24) & 0x1);
                    pin.in_use.put(in_use_status);
                    send_csw(.good);
                },
                .request_sense => {
                    const res_sense = [18]u8{ 0x70, 0x00, 0x05, 0x00, 0x00, 0x00, 0x00, 0x0a, 0x00, 0x00, 0x00, 0x00, 0x24, 0x00, 0x00, 0x00, 0x00, 0x00 };
                    // set reply data
                    for (0..res_sense.len) |i| {
                        usbd.write_tx(&usbd.ep_buf[1].tx, i, res_sense[i]);
                    }
                    send_data(res_sense.len);
                    bulk_state = .data;
                },
                .read => {
                    // store current LED status
                    in_use_status = pin.in_use.read();

                    requested_lba = @byteSwap(@as(u32, @truncate(cbw.CDB_args >> 8)));
                    requested_num = @byteSwap(@as(u16, @truncate(cbw.CDB_args >> 48)));
                    transfered_num = 0;
                    // std.log.debug("lba: {X}, num:{d}", .{ requested_lba, requested_num });

                    var read_sector_num = requested_num;
                    if (read_sector_num > MAX_SECTOR_NUM) read_sector_num = MAX_SECTOR_NUM;
                    if (sd_card.read_multi(requested_lba, sector_buffer[0..(read_sector_num * sdcard.SECTOR_SIZE)])) {
                        // send sector data
                        for (0..BUFFER_SIZE) |i| {
                            usbd.write_tx(&usbd.ep_buf[1].tx, i, sector_buffer[i]);
                        }
                        send_data(BUFFER_SIZE);
                        buffer_index = BUFFER_SIZE;
                        transfer_error = false;
                        bulk_state = .data;
                    } else |_| {
                        // read error
                        send_stuffing();
                    }
                },
                .write => {
                    // store current LED status
                    in_use_status = pin.in_use.read();

                    requested_lba = @byteSwap(@as(u32, @truncate(cbw.CDB_args >> 8)));
                    requested_num = @byteSwap(@as(u16, @truncate(cbw.CDB_args >> 48)));
                    transfered_num = 0;
                    buffer_index = 0;
                    transfer_error = false;
                    bulk_state = .data;
                },
                .start_stop_unit => {
                    send_csw(.good);
                },
                .mode_sense => {
                    for (0..descriptors.ModeSenseResponse_CardReader.len) |i| {
                        usbd.write_tx(&usbd.ep_buf[1].tx, i, descriptors.ModeSenseResponse_CardReader[i]);
                    }
                    send_data(descriptors.ModeSenseResponse_CardReader.len);
                    bulk_state = .data;
                },
                else => {
                    send_stuffing();
                },
            }
        },
        .data => {
            switch (cbw.CDB_op) {
                .write => {
                    for (0..BUFFER_SIZE) |i| {
                        sector_buffer[buffer_index + i] = usbd.read_rx(&usbd.ep_buf[2].rx, i);
                    }
                    buffer_index += BUFFER_SIZE;

                    const received_num = transfered_num + @as(u16, @truncate(buffer_index / sdcard.SECTOR_SIZE));
                    if ((received_num == requested_num) or (buffer_index == sector_buffer.len)) {
                        pin.in_use.toggle();
                        // write to SD card
                        if (sd_card.write_multi(requested_lba + transfered_num, sector_buffer[0..buffer_index])) {
                            //
                        } else |_| {
                            transfer_error = true;
                        }
                        transfered_num = received_num;
                        buffer_index = 0;
                    }

                    if (transfered_num == requested_num) {
                        // all data were reciened
                        send_csw(if (transfer_error) .phase_error else .good);
                    }
                },
                else => {},
            }
        },
        .status => {},
    }

    // reset interrupt flags and resume recieving
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
