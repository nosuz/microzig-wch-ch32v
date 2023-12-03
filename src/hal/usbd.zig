// http://kevincuzner.com/2018/01/29/bare-metal-stm32-writing-a-usb-driver/

const std = @import("std");
const microzig = @import("microzig");

const root = @import("root");

const ch32v = microzig.hal;
const pins = ch32v.pins;
const clocks = ch32v.clocks;
const interrupt = ch32v.interrupt;
const time = ch32v.time;

const peripherals = microzig.chip.peripherals;
const RCC = peripherals.RCC;
const USB = peripherals.USB;
const PFIC = peripherals.PFIC;
const EXTEND = peripherals.EXTEND;

pub const SRAM_BASE = 0x4000_6000;

pub const Speed = enum(u1) {
    Full_speed = 0,
    Low_speed = 1,
};

pub const BufferSize = enum(u10) {
    byte_8 = 8,
    byte_64 = 64,
};

pub const Configuration = struct {
    setup: bool = false,

    speed: Speed = Speed.Low_speed,
    ep_num: u3 = 1,
    buffer_size: BufferSize = .byte_8,
    handle_sof: bool = false,
};

pub fn USBD(comptime config: pins.Pin.Configuration) type {
    return root.usbd_class.USBD(config);
}

const pin = pins.get_pins(root.pin_config);
// Number of endpoints
const EP_NUM = pin.__usbd__.ep_num;
// packet buffer size.
pub const BUFFER_SIZE = @as(usize, @intFromEnum(pin.__usbd__.buffer_size));

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

pub fn get_rx_count(ep_btable: BUFFER_DESC) u10 {
    return @as(RX_BLOCK, @bitCast(ep_btable.RX_BLOCK)).COUNT_RX;
}

pub var btable align(16) linksection(".packet_buffer") = [_]BUFFER_DESC{undefined} ** EP_NUM;

// packet buffer address view from
// CPU: USB
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

pub const DESCRIPTOR_REQUEST = packed struct(u64) {
    bmRequestType: bmRequestType,
    bRequest: root.usbd_class.bRequest,
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

pub var usb_request: root.usbd_class.USB_REQUESTS = .none;
var usb_standard_request: bool = true;
// return STALL if null
var descriptor: ?root.usbd_class.descriptors.DescriptorIndex = .device;

// record last sent point
var next_point: u32 = 0;

const SOF: fn () void = if (@hasDecl(root.usbd_class, "SOF")) root.usbd_class.SOF else default_SOF;

fn default_SOF() void {}

fn addr_by_usbd(value: anytype) u9 {
    // make address seen from USBD
    return @as(u9, @truncate((@intFromPtr(value) - SRAM_BASE) / 2));
}

pub fn init() void {
    // 21.2.2 Functional configuration
    // 2) Module initialization

    // Second
    // if (USB.CNTR.read().FRES == 1) {
    // enable interupt
    USB.CNTR.modify(.{
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
            // set address seen from USBD
            .ADD_TX = addr_by_usbd(&ep_buf[i].tx),
            // set address seen from USBD
            .ADD_RX = addr_by_usbd(&ep_buf[i].tx),
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
    USB.BTABLE.write(.{
        .reserved3 = 0, // btable is aligned on 8 bytes in CPU address.
        //  Buffer table
        // set address seen from USBD
        .BTABLE = addr_by_usbd(&btable) >> 3,
        .padding = 0,
    });

    USB.DADDR.write(.{
        .ADD = 0, // Reset device address
        .EF = 1, // enable endpoint transfer
        .padding = 0,
    });
    // }

    // enable interupt
    USB.CNTR.modify(.{
        .FRES = 0, // release from reset state
        .CTRM = 1, // enable correct transafer interrupt
        .SOFM = @intFromBool(pin.__usbd__.handle_sof), // enable SOF interrupt
        .RESETM = 1, // enable reset interrupt
    });

    // must place afeter CNTR.FRES released
    reset_endpoints();

    // finally
    // clear status
    USB.ISTR.raw = 0;
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

pub fn interrupt_handler() void {
    // const pin = pins.get_pins(root.pin_config);
    // pin.led.toggle();

    const istr = USB.ISTR.read();
    if (istr.RESET == 1) {
        // reset
        reset_endpoints();
    } else if (istr.SOF == 1) {
        // SOF
        SOF();
    } else if (istr.CTR == 1) {
        switch (istr.EP_ID) {
            0 => { // endpoint 0
                const epr = USB.EP0R.read();
                if (epr.CTR_RX == 1) { // OUT or SETUP
                    if (epr.SETUP == 1) { // SETUP
                        EP0_CONTROL_SETUP();
                    } else { // OUT
                        if (usb_standard_request) {
                            EP0_CONTROL_OUT();
                        } else {
                            class_EP0_CONTROL_OUT();
                        }
                    }
                } else if (epr.CTR_TX == 1) { // IN
                    if (usb_standard_request) {
                        EP0_CONTROL_IN();
                    } else {
                        class_EP0_CONTROL_IN();
                    }
                }
            },
            // other class specific endpoints
            else => root.usbd_class.packet_handler(istr.EP_ID),
        }
    }

    USB.ISTR.raw = 0;
}

fn reset_endpoints() void {
    USB.DADDR.modify(.{
        .ADD = 0, // Reset device address
    });

    // setup endpoint0
    const ep0r = USB.EP0R.read();
    // set DTOG to 0
    const set_tog_tx0 = ep0r.DTOG_TX ^ 0;
    const set_tog_rx0 = ep0r.DTOG_RX ^ 0;
    // set STAT_RX to ACK
    const set_rx0_ack = ep0r.STAT_RX ^ 0b11;
    const set_tx0_nak = ep0r.STAT_TX ^ 0b10;
    USB.EP0R.write(.{
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

    reset_class_endpoints();
}

const reset_class_endpoints: fn () void = if (@hasDecl(root.usbd_class, "reset_endpoints")) root.usbd_class.reset_endpoints else default_reset_class_endpoints;

fn default_reset_class_endpoints() void {}

pub fn EP0_expect_IN(length: u32) void {
    // set next data length
    btable[0].COUNT_TX = length;

    const epr = USB.EP0R.read();

    // 1 ^ 1 -> 0, 0 ^ 1 -> 1 then flip and (0 -> 1)
    // make bit pattern to make expected status.
    const set_rx_ack = epr.STAT_RX ^ 0b11; // For not all data is required
    const set_tx_ack = epr.STAT_TX ^ 0b11;
    USB.EP0R.write(.{
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

pub fn EP0_expect_STATUS_OUT() void {
    const epr = USB.EP0R.read();

    // 1 ^ 1 -> 0, 0 ^ 1 -> 1 then flip and (0 -> 1)
    // make bit pattern to make expected status.
    const set_rx_ack = epr.STAT_RX ^ 0b11;
    const set_tx_nak = epr.STAT_TX ^ 0b10;
    USB.EP0R.write(.{
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

pub fn EP0_expect_DATA_OUT() void {
    const epr = USB.EP0R.read();

    // 1 ^ 1 -> 0, 0 ^ 1 -> 1 then flip and (0 -> 1)
    // make bit pattern to make expected status.
    const set_rx_ack = epr.STAT_RX ^ 0b11;
    const set_tx_nak = epr.STAT_TX ^ 0b10;
    USB.EP0R.write(.{
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

pub fn EP0_STALL_IN() void {
    const epr = USB.EP0R.read();

    // send STALL
    btable[0].COUNT_TX = 0;
    // make bit pattern to make 0b01
    const set_rx_stall = epr.STAT_RX ^ 0b01;
    const set_tx_stall = epr.STAT_TX ^ 0b01;
    USB.EP0R.write(.{
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

pub fn EP0_clear_interupt() void {
    USB.EP0R.write(.{
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
    var rx_count = get_rx_count(btable[0]);
    if (rx_count > setup_buffer.len) {
        rx_count = setup_buffer.len;
    }
    for (0..rx_count) |i| {
        setup_buffer[i] = read_rx(&ep_buf[0].rx, i);
    }
    // std.log.debug("count: {}", .{rx_count});
    // std.log.debug("rx: {s}", .{std.fmt.fmtSliceHexLower(&setup_buffer)});
    // std.log.debug("ep0: {s}", .{std.fmt.fmtSliceHexLower(&ep_buf[0].rx)});

    const setup_data = @as(DESCRIPTOR_REQUEST, @bitCast(setup_buffer));
    next_point = 0;

    switch (setup_data.bmRequestType.RequestType) {
        .standard => {
            usb_standard_request = true;
            switch (setup_data.bRequest) {
                .GET_DESCRIPTOR => {
                    usb_request = .get_descriptor;
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
                        else => DISPATCH_DESCRIPTOR(setup_data.wValue),
                    };

                    EP0_CONTROL_IN();
                },
                .SET_ADDRESS => {
                    usb_request = .set_address;
                    EP0_expect_IN(0);
                },
                .SET_CONFIGURATION => {
                    // set Endpoint 1
                    usb_request = .set_configuration;
                    root.usbd_class.set_configuration(setup_data.wValue);
                    EP0_expect_IN(0);
                },
                else => {
                    pin.led.toggle();

                    EP0_clear_interupt();
                    std.log.err("USB bReq: {}", .{setup_data.bRequest});
                },
            }
        },
        else => {
            usb_standard_request = false;
            CLASS_REQUEST(setup_data);
        },
    }
}

const DISPATCH_DESCRIPTOR: fn (u16) ?root.usbd_class.descriptors.DescriptorIndex = if (@hasDecl(root.usbd_class, "DISPATCH_DESCRIPTOR")) root.usbd_class.DISPATCH_DESCRIPTOR else default_DISPATCH_DESCRIPTOR;

pub fn default_DISPATCH_DESCRIPTOR(setup_value: u16) ?root.usbd_class.descriptors.DescriptorIndex {
    _ = setup_value;
    return null;
}

const CLASS_REQUEST: fn (DESCRIPTOR_REQUEST) void = if (@hasDecl(root.usbd_class, "CLASS_REQUEST")) root.usbd_class.CLASS_REQUEST else default_CLASS_REQUEST;

fn default_CLASS_REQUEST(setup_data: DESCRIPTOR_REQUEST) void {
    switch (setup_data.bRequest) {
        .GET_INTERFACE => {
            usb_request = .get_interface;
            EP0_expect_IN(0);
        },
        // device class specific requests
        else => {
            EP0_clear_interupt();
        },
    }
}

const class_EP0_CONTROL_IN: fn () void = if (@hasDecl(root.usbd_class, "EP0_CONTROL_IN")) root.usbd_class.EP0_CONTROL_IN else default_class_EP0_CONTROL_IN;

fn default_class_EP0_CONTROL_IN() void {
    switch (usb_request) {
        .get_interface => {
            EP0_expect_IN(0);
        },
        else => EP0_clear_interupt(),
    }
}

const class_EP0_CONTROL_OUT: fn () void = if (@hasDecl(root.usbd_class, "EP0_CONTROL_OUT")) root.usbd_class.EP0_CONTROL_OUT else default_class_EP0_CONTROL_OUT;

fn default_class_EP0_CONTROL_OUT() void {
    EP0_clear_interupt();
}

fn EP0_CONTROL_IN() void {
    // const pin = pins.get_pins(root.pin_config);
    // pin.led.toggle();

    const setup_data = @as(DESCRIPTOR_REQUEST, @bitCast(setup_buffer));
    switch (usb_request) {
        .get_descriptor => {
            if (descriptor) |index| {
                const desc_index = @intFromEnum(index);
                const desc = root.usbd_class.descriptors.DESCRIPTORS[desc_index];
                var desc_length = root.usbd_class.descriptors.DESCRIPTORS_LENGTH[desc_index];
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
        .set_address => {
            USB.DADDR.modify(.{
                .ADD = @as(u7, @truncate(setup_data.wValue)), // Set device address
            });
            EP0_expect_IN(0);
        },
        .set_configuration => {
            EP0_expect_IN(0);
        },
        else => EP0_clear_interupt(),
    }
}

fn EP0_CONTROL_OUT() void {
    EP0_expect_IN(0);
}
