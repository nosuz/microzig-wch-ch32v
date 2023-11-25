// http://kevincuzner.com/2018/01/29/bare-metal-stm32-writing-a-usb-driver/

const std = @import("std");
const microzig = @import("microzig");
const descriptors = @import("descriptors.zig");
const serial = @import("serial.zig");

const ch32v = microzig.hal;
// for debug trigger
const root = @import("root");
const pins = ch32v.pins;
const interrupt = ch32v.interrupt;
const time = ch32v.time;
const usbd = ch32v.usbd;

const peripherals = microzig.chip.peripherals;
const USBD = peripherals.USB;
const PFIC = peripherals.PFIC;
const EXTEND = peripherals.EXTEND;

// Number of endpoints
const EP_NUM = 4;
// packet buffer size.
pub const BUFFER_SIZE = 8; // if add 2 bytes, CRC data can grub.

// buffer descriptor table
const BUFFER_DESC = packed struct(u128) {
    ADD_TX: u32, // u16 access not work
    // reserved0: u16 = 0,
    COUNT_TX: u32 = 0,
    // reserved1: u16 = 0,
    ADD_RX: u32, // u16 access not work
    // reserved2: u16 = 0,
    RX_BLOCK: u32,
    // RX_BLOCK: RX_BLOCK,
    // not work
    // COUNT_RX: u10 = 0,
    // NUM_BLOCK: u5,
    // BLSIZE: u1,
    // reserved3: u16 = 0,
};

const RX_BLOCK = packed struct(u32) {
    COUNT_RX: u10 = 0,
    NUM_BLOCK: u5,
    BLSIZE: u1,
    reserved3: u16 = 0,
};

pub fn get_count_rx(ep_btable: BUFFER_DESC) u10 {
    return @as(RX_BLOCK, @bitCast(ep_btable.RX_BLOCK)).COUNT_RX;
}

pub var btable align(8) linksection(".packet_buffer") = [_]BUFFER_DESC{undefined} ** EP_NUM;

// packet buffer address view from
// CPU: USBD
// 0:   0, 1, -, -
// 4:   2, 3, -, -
// 8:   4, 5, -, -
const BUFFER = union {
    tx: [BUFFER_SIZE / 2]u32,
    rx: [BUFFER_SIZE * 2]u8,
};

pub var ep_buf align(4) linksection(".packet_buffer") = [_]BUFFER{
    BUFFER{
        .tx = undefined,
        // .tx = [_]u32{0} ** (BUFFER_SIZE / 2),
        // .rx = [_]u8{0} ** (BUFFER_SIZE * 2),
    },
} ** EP_NUM;

// SETUP packet format
const Recipient = enum(u5) {
    device = 0,
    interface = 1,
    endpoint = 2,
    other = 3,
    _,
};

const RequestType = enum(u2) {
    standard = 0,
    class = 1,
    vendor = 2,
    reserved = 3,
};

const RequestDirection = enum(u1) {
    host2device = 0,
    device2host = 1,
};

const bmRequestType = packed struct(u8) {
    Recipient: Recipient,
    RequestType: RequestType,
    RequestDirection: RequestDirection,
};

const bRequest = enum(u8) {
    CLEAR_FEATURE = 1,
    SET_ADDRESS = 5,
    GET_DESCRIPTOR = 6,
    SET_CONFIGURATION = 9,
    GET_INTERFACE = 10,

    // CDC class specific
    SET_LINE_CODING = 0x20,
    GET_LINE_CODING = 0x21,
    SET_CONTROL_LINE_STATE = 0x22,
    _,
};

const DESCRIPTOR_REQUEST = packed struct(u64) {
    bmRequestType: bmRequestType,
    bRequest: bRequest,
    wValue: u16,
    wIndex: u16,
    wLength: u16,
};

var setup_buffer = [_]u8{0} ** 8;

// response
// STAT_RX, STAT_TX
// DISABLED: 0b00, STALL: 0b01, NAK: 0b10, ACK: 0b11

// XOR with expected bits pattern  will make bits pattern to make it.
// Want to set:
// If 1, 1 ^ 1 -> 0 and no flip.
// If 0, 0 ^ 1 -> 1 and flip bit and make 1.
// Want to clear:
// If 1, 1 ^ 0 -> 1 and flip bit and make 0.
// If 0, 0 ^ 0 -> 0 and no flip.

const USB_STATE = enum {
    none,
    std_get_descriptor,
    std_set_address, // no data transaction
    std_set_configuration, // no data transaction
    cls_get_interface,
    cls_set_configuration, // no data transaction
    cls_set_line_coding,
    cls_set_line_control_state,
};

var usb_state: USB_STATE = .none;
// return STALL if null
var descriptor: ?descriptors.DescriptorIndex = .device;

// record last sent point
var next_point: u32 = 0;

const bCharFormat = enum(u8) {
    one_stop_bit = 0,
    one_half_stop_bits = 1,
    two_stop_bits = 2,
};

const bParityType = enum(u8) {
    one = 0,
    odd = 1,
    even = 2,
    mark = 3,
    space = 4,
};

const LineCodingFormat = packed struct(u56) {
    dwDTERate: u32,
    bCharFormat: bCharFormat,
    bParityType: bParityType,
    bDataBits: u8,
};

pub fn init() void {
    // 21.2.2 Functional configuration
    // 2) Module initialization

    // Second
    // if (USBD.CNTR.read().FRES == 1) {
    // enable interupt
    USBD.CNTR.modify(.{
        .PDWN = 0, // RO?
    });
    time.sleep_ms(1);

    // calc BLSIZE and NUM_BLOCK based on the BUFFER_SIZE
    const blsize = switch (BUFFER_SIZE) {
        0...62 => 0,
        else => 1,
    };
    const num_block = switch (BUFFER_SIZE) {
        0...62 => BUFFER_SIZE / 2,
        else => BUFFER_SIZE / 32 - 1,
    };

    // set packet buffer description table
    // 0x80004c8
    const rx_block = RX_BLOCK{
        .BLSIZE = @as(u1, blsize),
        .NUM_BLOCK = @as(u5, num_block),
    };

    for (0..EP_NUM) |i| {
        btable[i] = .{
            .ADD_TX = (@intFromPtr(&ep_buf[i].tx) - usbd.SRAM_BASE) / 2,
            .ADD_RX = (@intFromPtr(&ep_buf[i].rx) - usbd.SRAM_BASE) / 2,
            .RX_BLOCK = @as(u32, @bitCast(rx_block)),
            // not work
            // .RX_BLOCK = RX_BLOCK{
            //     .BLSIZE = @as(u1, blsize),
            //     .NUM_BLOCK = @as(u5, num_block),
            // },
            // not work
            // .BLSIZE = @as(u1, blsize),
            // .NUM_BLOCK = @as(u5, num_block),
        };
    }

    // set BTABLE
    USBD.BTABLE.write(.{
        .reserved3 = 0, // btable is aligned on 8 bytes.
        //  Buffer table
        .BTABLE = @as(u13, @truncate((@intFromPtr(&btable) - usbd.SRAM_BASE) >> 3)),
        .padding = 0,
    });

    USBD.DADDR.write(.{
        .ADD = 0, // Reset device address
        .EF = 1, // enable endpoint transfer
        .padding = 0,
    });
    // }

    // enable interupt
    USBD.CNTR.modify(.{
        .FRES = 0, // release from reset state
        .CTRM = 1, // enable correct transafer interrupt
        .SOFM = 1, // enable SOF interrupt
        .RESETM = 1, // enable reset interrupt
    });

    // must place afeter CNTR.FRES released
    reset_endpoints();

    // finally
    // clear status
    USBD.ISTR.raw = 0;
    // USB_HP_CAN1_TX = 35
    // const USB_HP_INT = @intFromEnum(interrupt.Interrupts_ch32v203.USB_HP_CAN1_TX);
    // USB_LP_CAN1_RX0 = 36
    const USB_LP_INT = @intFromEnum(interrupt.Interrupts_ch32v203.USB_LP_CAN1_RX0);
    // clear pending interrupt
    PFIC.IPRR2.raw |= (1 << (USB_LP_INT - 32));
    // open interrupt. Enabling global interupt is required.
    PFIC.IENR2.raw |= (1 << (USB_LP_INT - 32));

    // enable pull-up
    EXTEND.EXTEND_CTR.modify(.{
        .USBDPU = 1,
    });
}

pub fn read_rx(ptr: []u8, offset: u32) u8 {
    const x = offset / 2;
    const y = offset % 2;
    return ptr[x * 4 + y];
}

pub fn read_tx(ptr: []u32, offset: u32) u8 {
    var val = ptr[offset / 2];

    if (offset % 2 == 1) {
        val = val >> 8;
    }

    return @as(u8, @truncate(val & 0xff));
}

// Writing a byte at even address might might write the same value atthe lower odd address.
// Thus, use read-modify-write to word access.
pub fn write_tx(ptr: []u32, offset: u32, val: u8) void {
    const x = offset / 2;
    var tmp = ptr[x];

    switch (offset % 2) {
        0 => {
            tmp = (tmp & 0xff00) | val;
        },
        1 => {
            tmp = (tmp & 0x00ff) | (@as(u32, val) << 8);
        },
        else => unreachable,
    }

    ptr[x] = tmp;
}

pub fn usbd_handler() void {
    // const pin = pins.get_pins(root.pin_config);
    // pin.led.toggle();

    const istr = USBD.ISTR.read();
    if (istr.RESET == 1) {
        // reset
        reset_endpoints();
    } else if (istr.SOF == 1) {
        // SOF
        serial.start_tx();
    } else if (istr.CTR == 1) {
        switch (istr.EP_ID) {
            0 => { // endpoint 0
                const epr = USBD.EP0R.read();
                if (epr.CTR_RX == 1) { // OUT or SETUP
                    if (epr.SETUP == 1) { // SETUP
                        EP0_CONTROL_SETUP();
                    } else { // OUT
                        EP0_CONTROL_OUT();
                    }
                } else if (epr.CTR_TX == 1) { // IN
                    EP0_CONTROL_IN();
                }
            },
            1 => { // endpoint 1
                serial.EP1_IN();
            },
            2 => { // endpoint2
                // OUT
                serial.EP2_OUT();
            },
            3 => { // endpoint 3
                // IN
                serial.EP3_IN();
            },
            else => {},
        }
    }

    USBD.ISTR.raw = 0;
}

fn reset_endpoints() void {
    USBD.DADDR.modify(.{
        .ADD = 0, // Reset device address
    });

    // setup endpoint0
    const ep0r = USBD.EP0R.read();
    // set DTOG to 0
    const set_tog_tx0 = ep0r.DTOG_TX ^ 0;
    const set_tog_rx0 = ep0r.DTOG_RX ^ 0;
    // set STAT_RX to ACK
    const set_rx0_ack = ep0r.STAT_RX ^ 0b11;
    const set_tx0_nak = ep0r.STAT_TX ^ 0b10;
    USBD.EP0R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = set_tog_rx0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx0_ack, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b01, // CONTROL
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = set_tog_tx0, // 1: flip
        .STAT_TX = set_tx0_nak, // 1: flip
        .EA = 0, // EP0
    });

    // disable endpoint1
    const ep1r = USBD.EP1R.read();
    // set DTOG to 0
    const set_tog_tx1 = ep1r.DTOG_TX ^ 0;
    const set_tog_rx1 = ep1r.DTOG_RX ^ 0;
    // set STAT to DISABLED
    const set_rx1_disable = ep1r.STAT_RX ^ 0b00;
    const set_tx1_disable = ep1r.STAT_TX ^ 0b00;
    USBD.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = set_tog_rx1, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx1_disable, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = set_tog_tx1, // 1: flip
        .STAT_TX = set_tx1_disable, // 1: flip
        .EA = 1, // EP0
    });
}

fn EP0_expect_IN(length: u32) void {
    // set next data length
    btable[0].COUNT_TX = length;

    const epr = USBD.EP0R.read();

    // 1 ^ 1 -> 0, 0 ^ 1 -> 1 then flip and (0 -> 1)
    // make bit pattern to make expected status.
    const set_rx_ack = epr.STAT_RX ^ 0b11; // For not all data is required
    const set_tx_ack = epr.STAT_TX ^ 0b11;
    USBD.EP0R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; auto toggled
        .STAT_RX = set_rx_ack, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b01, // CONTROL
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx_ack, // 1: flip
        .EA = 0, // EP0
    });
}

fn EP0_expect_STATUS_OUT() void {
    const epr = USBD.EP0R.read();

    // 1 ^ 1 -> 0, 0 ^ 1 -> 1 then flip and (0 -> 1)
    // make bit pattern to make expected status.
    const set_rx_ack = epr.STAT_RX ^ 0b11;
    const set_tx_nak = epr.STAT_TX ^ 0b10;
    USBD.EP0R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; auto toggled
        .STAT_RX = set_rx_ack, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b01, // CONTROL
        .EP_KIND = 1, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx_nak, // 1: flip
        .EA = 0, // EP0
    });
}

fn EP0_expect_DATA_OUT() void {
    const epr = USBD.EP0R.read();

    // 1 ^ 1 -> 0, 0 ^ 1 -> 1 then flip and (0 -> 1)
    // make bit pattern to make expected status.
    const set_rx_ack = epr.STAT_RX ^ 0b11;
    const set_tx_nak = epr.STAT_TX ^ 0b10;
    USBD.EP0R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; auto toggled
        .STAT_RX = set_rx_ack, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b01, // CONTROL
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx_nak, // 1: flip
        .EA = 0, // EP0
    });
}

fn EP0_STALL_IN() void {
    const epr = USBD.EP0R.read();

    // send STALL
    btable[0].COUNT_TX = 0;
    // make bit pattern to make 0b01
    const set_rx_stall = epr.STAT_RX ^ 0b01;
    const set_tx_stall = epr.STAT_TX ^ 0b01;
    USBD.EP0R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip
        .STAT_RX = set_rx_stall, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b01, // CONTROL
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip
        .STAT_TX = set_tx_stall, // 1: flip
        .EA = 0, // EP0
    });
}

fn EP0_clear_interupt() void {
    USBD.EP0R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; hardware set 1 by SETUP
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b01, // CONTROL
        .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; hardware set 1 by SETUP
        .STAT_TX = 0b00, // 1: flip
        .EA = 0, // EP0
    });
}

fn EP0_CONTROL_SETUP() void {
    // const pin = pins.get_pins(root.pin_config);
    // pin.led.toggle();

    const rx_block = @as(RX_BLOCK, @bitCast(btable[0].RX_BLOCK));
    const rx_count = if (rx_block.COUNT_RX <= setup_buffer.len) rx_block.COUNT_RX else setup_buffer.len;
    for (0..rx_count) |i| {
        setup_buffer[i] = read_rx(&ep_buf[0].rx, i);
    }
    // std.log.debug("rx: {s}", .{std.fmt.fmtSliceHexLower(&setup_buffer)});

    const setup_data = @as(DESCRIPTOR_REQUEST, @bitCast(setup_buffer));
    next_point = 0;

    switch (setup_data.bmRequestType.RequestType) {
        .standard => {
            switch (setup_data.bRequest) {
                .GET_DESCRIPTOR => {
                    usb_state = .std_get_descriptor;
                    descriptor = switch (setup_data.wValue) {
                        // return device descriptor
                        0x100 => .device, // return configuration descriptor
                        0x200 => .configuration, // return supporting languages list
                        0x300 => .lang_id,
                        // ignore specified language
                        0x301 => .string1,
                        0x302 => .string2,
                        0x303 => .string3,
                        0x304 => .string4,
                        0x600 => null, // return STALL for qualifier if the device is full-speed
                        else => null,
                    };

                    EP0_CONTROL_IN();
                },
                .SET_ADDRESS => {
                    usb_state = .std_set_address;
                    EP0_expect_IN(0);
                },
                .SET_CONFIGURATION => {
                    // set Endpoint 1
                    usb_state = .std_set_configuration;
                    serial.configure_eps();
                    EP0_expect_IN(0);
                },
                else => {
                    EP0_clear_interupt();
                    // std.log.err("USBD bReq: {}", .{setup_data.bRequest});
                },
            }
        },
        .class => {
            switch (setup_data.bRequest) {
                .GET_INTERFACE => {
                    usb_state = .cls_get_interface;
                    EP0_expect_IN(0);
                },
                .SET_CONFIGURATION => {
                    usb_state = .cls_set_configuration;
                    EP0_expect_DATA_OUT();
                },
                .SET_LINE_CODING => {
                    usb_state = .cls_set_line_coding;
                    EP0_expect_DATA_OUT();
                },
                .SET_CONTROL_LINE_STATE => {
                    usb_state = .cls_set_line_control_state;
                    // SETUP value is flow control
                    const con_state = if ((setup_data.wValue & 0x01) == 0) false else true;
                    serial.set_connection_state(con_state);
                    EP0_expect_IN(0);
                },
                else => {
                    EP0_clear_interupt();
                },
            }
        },
        else => {
            EP0_clear_interupt();
        },
    }
}

fn EP0_CONTROL_IN() void {
    // const pin = pins.get_pins(root.pin_config);
    // pin.led.toggle();

    const setup_data = @as(DESCRIPTOR_REQUEST, @bitCast(setup_buffer));
    switch (usb_state) {
        .std_get_descriptor => {
            if (descriptor) |index| {
                const desc_index = @intFromEnum(index);
                const desc = descriptors.DESCRIPTORS[desc_index];
                var desc_length = descriptors.DESCRIPTORS_LENGTH[desc_index];
                // limit max length under the requested length.
                if (setup_data.wLength < desc_length) desc_length = setup_data.wLength;
                const last_point = if ((desc_length - next_point) > BUFFER_SIZE) next_point + BUFFER_SIZE else desc_length;

                const send_count = last_point - next_point;
                if (send_count == 0) {
                    // no more data
                    // move on to the status transaction
                    EP0_expect_STATUS_OUT();
                } else {
                    // fill send buffer
                    for (0..send_count) |i| {
                        write_tx(&ep_buf[0].tx, i, desc[next_point + i]);
                    }
                    next_point = last_point;
                    EP0_expect_IN(send_count);
                }
            } else {
                EP0_STALL_IN();
            }
        },
        .std_set_address => {
            USBD.DADDR.modify(.{
                .ADD = @as(u7, @truncate(setup_data.wValue)), // Set device address
            });
            EP0_expect_IN(0);
        },
        .std_set_configuration => {
            EP0_expect_IN(0);
        },
        .cls_get_interface => {
            EP0_expect_IN(0);
        },
        else => unreachable,
    }
}

fn EP0_CONTROL_OUT() void {
    switch (usb_state) {
        .cls_set_line_coding => {
            // set serial config
            // LineCodingFormat is 7 bytes.
            var _buffer = [_]u8{0} ** 7;
            for (0..7) |i| {
                _buffer[i] = read_rx(&ep_buf[0].rx, i);
            }
            _ = @as(LineCodingFormat, @bitCast(_buffer));
            EP0_expect_IN(0);
        },
        .cls_set_line_control_state => {
            // connected
            EP0_expect_IN(0);
        },
        else => EP0_expect_IN(0),
    }
}
