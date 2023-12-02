const std = @import("std"); // allocator
const root = @import("root"); // for debug

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbd = ch32v.usbd;
const pins = ch32v.pins;
const rb = ch32v.ring_buffer;
const time = ch32v.time;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USBHD;

// provide device descriptor dat to usbd
// variable name is fixed.
pub const descriptors = @import("cdc_acm_descriptors.zig");

const SERIAL_BUFFER_SIZE = 128;
const Tx_Buffer = rb.RingBuffer(0, u8, SERIAL_BUFFER_SIZE){};
const Rx_Buffer = rb.RingBuffer(1, u8, SERIAL_BUFFER_SIZE){};

// TODO: consider race-condition
var IN_TX_TRANSACTION = false;
var CONNECTED = false;

// Please help: with format a string with numbers or allocator instance in microzig. #132
// https://github.com/ZigEmbeddedGroup/microzig/issues/132#issuecomment-1662976196
var fmt_buffer: [1024]u8 = undefined;
var fba = std.heap.FixedBufferAllocator.init(fmt_buffer[0..]);
const allocator = fba.allocator();

// add device class specific requests.
pub const bRequest = enum(u8) {
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

// add state for device class specific requests.
pub const USB_REQUESTS = enum {
    none,
    get_descriptor,
    set_address, // no data transaction
    set_configuration, // no data transaction
    get_interface,
    // CDC class specific
    set_line_coding,
    set_line_control_state,
};

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

// handle device specific endpoints
pub fn packet_handler(ep_id: u4) void {
    switch (ep_id) {
        1 => { // endpoint 1
            EP1_IN();
        },
        2 => { // endpoint2
            // OUT
            EP2_OUT();
        },
        3 => { // endpoint 3
            // IN
            EP3_IN();
        },
        // unkown endpoints
        else => {},
    }
}

// device specific reset handler
// called at USB bus is reset state.
pub fn reset_endpoints() void {
    // endpoint 1 IN
    USB.R8_UEP4_1_MOD.write_raw(0);

    USB.R8_UEP1_CTRL__R8_UH_SETUP.modify(.{
        .RB_UEP_R_TOG__RB_UH_PRE_PID_EN = 0,
        .RB_UEP_T_TOG__RB_UH_SOF_EN = 0,
        .MASK_UEP_R_RES = 0b10, // NAK
        .MASK_UEP_T_RES = 0b10, // NAK
        .RB_UEP_AUTO_TOG = 1,
    });
    USB.R8_UEP1_T_LEN = 0;

    // endpoint 2 OUT
    USB.R8_UEP2_3_MOD__R8_UH_EP_MOD.write_raw(0);

    USB.R8_UEP2_CTRL__R8_UH_RX_CTRL.modify(.{
        .RB_UEP_R_TOG__RB_UH_R_TOG = 0,
        .RB_UEP_T_TOG = 0,
        .MASK_UEP_R_RES = 0b10, // NAK
        .MASK_UEP_T_RES = 0b10, // NAK
        .RB_UEP_AUTO_TOG__RB_UH_R_AUTO_TOG = 1,
    });
    USB.R8_UEP2_T_LEN__R8_UH_EP_PID.write_raw(0);

    // endpoint 3 IN
    // already set at endpoint 2
    // USB.R8_UEP2_3_MOD__R8_UH_EP_MOD.write_raw(0);

    USB.R8_UEP3_CTRL__R8_UH_TX_CTRL.modify(.{
        .RB_UEP_R_TOG = 0,
        .RB_UEP_T_TOG = 0,
        .MASK_UEP_R_RES = 0b10, // NAK
        .MASK_UEP_T_RES = 0b10, // NAK
        .RB_UEP_AUTO_TOG = 1,
    });
    USB.R8_UEP3_T_LEN__R8_UH_TX_LEN = 0;
}

// configure device. called by SET_CONFIGURATION request.
pub fn set_configuration(setup_value: u16) void {
    _ = setup_value;

    // endpoint 1 IN
    USB.R16_UEP1_DMA = @truncate(@intFromPtr(&usbd.ep_buf[1]));

    USB.R8_UEP4_1_MOD.modify(.{
        .RB_UEP1_RX_EN = 0,

        .RB_UEP1_TX_EN = 1,
        .RB_UEP1_BUF_MOD = 0, // Single buffer
    });

    // endpoint 2 OUT endpoint 3 IN
    USB.R16_UEP2_DMA__R16_UH_RX_DMA = @truncate(@intFromPtr(&usbd.ep_buf[2]));
    USB.R16_UEP3_DMA__R16_UH_TX_DMA = @truncate(@intFromPtr(&usbd.ep_buf[3]));

    USB.R8_UEP2_3_MOD__R8_UH_EP_MOD.modify(.{
        .RB_UEP2_RX_EN__RB_UH_EP_RX_EN = 1, // IN
        .RB_UEP2_TX_EN = 0,
        .RB_UEP2_BUF_MOD__RB_UH_EP_RBUF_MOD = 0, // Single buffer

        .RB_UEP3_RX_EN = 0,
        .RB_UEP3_TX_EN__RB_UH_EP_TX_EN = 1, // OUT
        .RB_UEP3_BUF_MOD__RB_UH_EP_TBUF_MOD = 0, // Single buffer
    });
}

// called recieved SOF packet.
// define if custom SOF packet handler is required.
pub fn SOF() void {
    start_tx();
}

// dispatch device class specific GET_DESCRIPTOR request
// pub fn DISPATCH_DESCRIPTOR(setup_value: u16) ?descriptors.DescriptorIndex {
//     return switch (setup_value) {
//         else => null,
//     };
// }

// handle device class specific SETUP requests.
pub fn CLASS_REQUEST() void {
    // device class specific requests
    const setup_data = @as(usbd.DESCRIPTOR_REQUEST, @bitCast(usbd.setup_buf));

    switch (setup_data.bRequest) {
        .GET_INTERFACE => {
            usbd.usb_request = .get_interface;
            usbd.EP0_expect_IN(0);
        },
        .SET_CONFIGURATION => {
            usbd.usb_request = .set_configuration;
            usbd.EP0_expect_OUT();
        },
        .SET_LINE_CODING => {
            usbd.usb_request = .set_line_coding;
            usbd.EP0_expect_OUT();
        },
        .SET_CONTROL_LINE_STATE => {
            usbd.usb_request = .set_line_control_state;
            // SETUP value is flow control
            const con_state = if ((setup_data.wValue & 0x01) == 0) false else true;
            set_connection_state(con_state);
            usbd.EP0_expect_IN(0);
        },
        else => {},
    }
}

// handle device class specific EP0 control in packet
// define if custom EP0_CONTROL_IN packet handler is required.
// pub fn EP0_CONTROL_IN() void {
//     switch (usbd.usb_request) {
//         .get_interface => {},
//         else => unreachable,
//     }
//     usbd.EP0_expect_IN(0);
// }

// handle device class specific EP0 control out packet
// define if custom EP0_CONTROL_OUT packet handler is required.
pub fn EP0_CONTROL_OUT() void {
    switch (usbd.usb_request) {
        .set_line_coding => {
            // set serial config
            // LineCodingFormat is 7 bytes.
            var _buffer = [_]u8{0} ** 7;
            const ep0_buf = &usbd.ep_buf[0];
            for (0..7) |i| {
                _buffer[i] = ep0_buf[i];
            }
            _ = @as(LineCodingFormat, @bitCast(_buffer));
        },
        .set_line_control_state => {
            // connected
        },
        else => unreachable,
    }

    usbd.EP0_expect_IN(0);
}

pub fn EP1_IN() void {
    // set next data length
    USB.R8_UEP1_T_LEN = 0;

    USB.R8_UEP1_CTRL__R8_UH_SETUP.modify(.{
        .MASK_UEP_T_RES = 0b00, // ACK
    });
}

pub fn EP3_IN() void {
    set_ep3_tx_data();
}

pub fn EP2_OUT() void {
    // FIXME: need to respose NAK before full to avoid loose data
    // response NAK if buffer full
    if (!Rx_Buffer.is_full()) {
        const buf = &usbd.ep_buf[2];
        for (0..USB.R16_USB_RX_LEN) |i| {
            Rx_Buffer.write(buf[i]) catch {};
        }
    }
    USB.R8_UEP2_CTRL__R8_UH_RX_CTRL.modify(.{
        .MASK_UEP_R_RES = 0b00, // ACK
    });
}

fn set_ep3_tx_data() void {
    const pin = pins.get_pins(root.pin_config);
    pin.led.toggle();
    var tx_count: u32 = 0;
    const buf = &usbd.ep_buf[3];
    for (0..usbd.BUFFER_SIZE) |i| {
        const chr = Tx_Buffer.read() catch {
            break;
        };
        buf[i] = chr;
        tx_count += 1;
    }
    // set next data length
    USB.R8_UEP3_T_LEN__R8_UH_TX_LEN = @truncate(tx_count);

    USB.R8_UEP3_CTRL__R8_UH_TX_CTRL.modify(.{
        .MASK_UEP_T_RES = 0b00, // ACK
    });
}

pub fn write_str(comptime fmt: []const u8, args: anytype) !void {
    if (CONNECTED) {
        const string = try std.fmt.allocPrint(
            allocator,
            fmt,
            args,
        );
        defer allocator.free(string);

        for (string) |byte| {
            Tx_Buffer.write_block(byte);
        }
    }
}

pub fn log(
    // RTC required
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime "[{}.{:0>3}] " ++ level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (CONNECTED) {
        const current_time = time.get_uptime();
        const seconds = current_time / 1000;
        const microseconds = current_time % 1000;

        write_str(prefix ++ format ++ "\r\n", .{ seconds, microseconds } ++ args) catch {};
    }
}

pub fn log_no_timestamp(
    comptime level: std.log.Level,
    comptime scope: @TypeOf(.EnumLiteral),
    comptime format: []const u8,
    args: anytype,
) void {
    const level_prefix = comptime level.asText();
    const prefix = comptime level_prefix ++ switch (scope) {
        .default => ": ",
        else => " (" ++ @tagName(scope) ++ "): ",
    };

    if (CONNECTED) {
        write_str(prefix ++ format ++ "\r\n", args) catch {};
    }
}

fn set_connection_state(state: bool) void {
    CONNECTED = state;
}

pub fn start_tx() void {
    if (Tx_Buffer.is_empty() or IN_TX_TRANSACTION) return;

    set_ep3_tx_data();
}

pub fn USBD(comptime config: pins.Pin.Configuration) type {
    return struct {
        speed: usbd.Speed = config.usbd_speed orelse .Low_speed,
        ep_num: u3 = config.usbd_ep_num orelse 1,
        buffer_size: usbd.BufferSize = config.usbd_buffer_size orelse .byte_8,
        handle_sof: bool = config.usbd_handle_sof orelse false,

        // mandatory or call directly usbd.init()
        pub fn init(self: @This()) void {
            usbd.init(self.speed);
        }

        pub fn read(self: @This()) u8 {
            _ = self;
            return Rx_Buffer.read_block();
        }

        pub fn write(self: @This(), chr: u8) void {
            _ = self;
            // discard data if connection is closed.
            if (CONNECTED) Tx_Buffer.write_block(chr);
        }

        pub fn print(self: @This(), comptime fmt: []const u8, args: anytype) !void {
            _ = self;
            write_str(fmt, args);
        }

        pub fn is_readable(self: @This()) bool {
            _ = self;
            return !Rx_Buffer.is_empty();
        }

        pub fn is_writeable(self: @This()) bool {
            _ = self;
            return !Tx_Buffer.is_full();
        }

        pub fn is_connected(self: @This()) bool {
            _ = self;
            return CONNECTED;
        }
    };
}
