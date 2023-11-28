const std = @import("std"); // allocator
const root = @import("root"); // for debug

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbd = ch32v.usbd;
const pins = ch32v.pins;
const rb = ch32v.ring_buffer;
const time = ch32v.time;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USB;

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
//         .EP_TYPE = 0b11, // INTERRUPT
//         .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
//         .CTR_TX = 0,
//         .DTOG_TX = set_tog_tx2, // 1: flip
//         .STAT_TX = set_tx2_disable, // 1: flip
//         .EA = 2, // EP0
//     });

//     // disable endpoint3
//     const ep3r = USB.EP3R.read();
//     // set DTOG to 0
//     const set_tog_tx3 = ep3r.DTOG_TX ^ 0;
//     const set_tog_rx3 = ep3r.DTOG_RX ^ 0;
//     // set STAT to DISABLED
//     const set_rx3_disable = ep3r.STAT_RX ^ 0b00;
//     const set_tx3_disable = ep3r.STAT_TX ^ 0b00;
//     USB.EP3R.write(.{
//         .CTR_RX = 0,
//         .DTOG_RX = set_tog_rx3, // 1: flip; don't care for single buffer
//         .STAT_RX = set_rx3_disable, // 1: flip
//         .SETUP = 0,
//         .EP_TYPE = 0b11, // INTERRUPT
//         .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
//         .CTR_TX = 0,
//         .DTOG_TX = set_tog_tx3, // 1: flip
//         .STAT_TX = set_tx3_disable, // 1: flip
//         .EA = 3, // EP0
//     });

//     // disable endpoint4
//     const ep4r = USB.EP4R.read();
//     // set DTOG to 0
//     const set_tog_tx4 = ep4r.DTOG_TX ^ 0;
//     const set_tog_rx4 = ep4r.DTOG_RX ^ 0;
//     // set STAT to DISABLED
//     const set_rx4_disable = ep4r.STAT_RX ^ 0b00;
//     const set_tx4_disable = ep4r.STAT_TX ^ 0b00;
//     USB.EP4R.write(.{
//         .CTR_RX = 0,
//         .DTOG_RX = set_tog_rx4, // 1: flip; don't care for single buffer
//         .STAT_RX = set_rx4_disable, // 1: flip
//         .SETUP = 0,
//         .EP_TYPE = 0b11, // INTERRUPT
//         .EP_KIND = 0, // on EP_TYPE is CONTROL, EP_KIND works as STATUS_OUT and set 1 to expect OUT.
//         .CTR_TX = 0,
//         .DTOG_TX = set_tog_tx4, // 1: flip
//         .STAT_TX = set_tx4_disable, // 1: flip
//         .EA = 4, // EP0
//     });
// }

// configure device. called by SET_CONFIGURATION request.
pub fn set_configuration(setup_value: u16) void {
    _ = setup_value;

    usbd.btable[1].COUNT_TX = 0;

    const ep1r = USB.EP1R.read();
    // set DTOG to 0
    // Interrupt transfer start from DATA0 and toggle each transfer.
    const set_tog_tx1 = ep1r.DTOG_TX ^ 0;
    // set STAT to ACK
    const set_rx1_disabled = ep1r.STAT_RX ^ 0b00; // DISABLED
    const set_tx1_ack = ep1r.STAT_TX ^ 0b11; // ACK
    USB.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx1_disabled, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = set_tog_tx1, // 1: flip; auto toggled
        .STAT_TX = set_tx1_ack, // 1: flip
        .EA = 1, // EP1
    });

    // BULK OUT
    const ep2r = USB.EP2R.read();
    // set DTOG to 0
    const set_tog_rx2 = ep2r.DTOG_RX ^ 0;
    // set STAT to ACK
    const set_rx2_ack = ep2r.STAT_RX ^ 0b11; // ACK
    const set_tx2_disabled = ep2r.STAT_TX ^ 0b00; // DISABLED
    USB.EP2R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = set_tog_rx2, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx2_ack, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx2_disabled, // 1: flip
        .EA = 2, // EP1
    });

    // BULK IN
    const ep3r = USB.EP3R.read();
    // set DTOG to 0
    const set_tog_tx3 = ep3r.DTOG_TX ^ 0;
    // set STAT to NAK
    const set_rx3_disabled = ep3r.STAT_RX ^ 0b00; // DISABLED
    const set_tx3_nak = ep3r.STAT_TX ^ 0b10; // NAK for now.
    USB.EP3R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx3_disabled, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = set_tog_tx3, // 1: flip; auto toggled
        .STAT_TX = set_tx3_nak, // 1: flip
        .EA = 3, // EP1
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
pub fn CLASS_REQUEST(setup_data: usbd.DESCRIPTOR_REQUEST) void {
    // device class specific requests
    switch (setup_data.bRequest) {
        .GET_INTERFACE => {
            usbd.usb_request = .get_interface;
            usbd.EP0_expect_IN(0);
        },
        .SET_CONFIGURATION => {
            usbd.usb_request = .set_configuration;
            usbd.EP0_expect_DATA_OUT();
        },
        .SET_LINE_CODING => {
            usbd.usb_request = .set_line_coding;
            usbd.EP0_expect_DATA_OUT();
        },
        .SET_CONTROL_LINE_STATE => {
            usbd.usb_request = .set_line_control_state;
            // SETUP value is flow control
            const con_state = if ((setup_data.wValue & 0x01) == 0) false else true;
            set_connection_state(con_state);
            usbd.EP0_expect_IN(0);
        },
        else => {
            usbd.EP0_clear_interupt();
        },
    }
}

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
pub fn EP0_CONTROL_OUT() void {
    switch (usbd.usb_request) {
        .set_line_coding => {
            // set serial config
            // LineCodingFormat is 7 bytes.
            var _buffer = [_]u8{0} ** 7;
            for (0..7) |i| {
                _buffer[i] = usbd.read_rx(&usbd.ep_buf[0].rx, i);
            }
            _ = @as(LineCodingFormat, @bitCast(_buffer));
            usbd.EP0_expect_IN(0);
        },
        .set_line_control_state => {
            // connected
            usbd.EP0_expect_IN(0);
        },
        else => usbd.EP0_expect_IN(0),
    }

    usbd.EP0_clear_interupt();
}

pub fn EP1_IN() void {
    const ep1r = USB.EP1R.read();
    // set STAT to ACK
    const set_tx1_ack = ep1r.STAT_TX ^ 0b11; // ACK
    USB.EP1R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b11, // INTERRUPT
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx1_ack, // 1: flip
        .EA = 1, // EP1
    });
}

pub fn EP3_IN() void {
    set_ep3_tx_data();
}

pub fn EP2_OUT() void {
    const ep2r = USB.EP2R.read();

    // FIXME: need to respose NAK before full to avoid loose data
    // response NAK if buffer full
    const expected: u2 = if (Rx_Buffer.is_full()) 0b10 else 0b11;
    if (!Rx_Buffer.is_full()) {
        for (0..usbd.get_rx_count(usbd.btable[2])) |i| {
            Rx_Buffer.write(usbd.read_rx(&usbd.ep_buf[2].rx, i)) catch {};
        }
    }
    // set STAT to ACK
    const set_rx2_stat = ep2r.STAT_RX ^ expected; // ACK
    USB.EP2R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = set_rx2_stat, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = 0, // 1: flip
        .EA = 2, // EP1
    });
}

fn set_ep3_tx_data() void {
    const pin = pins.get_pins(root.pin_config);
    pin.led.toggle();
    var tx_count: u32 = 0;
    for (0..usbd.BUFFER_SIZE) |i| {
        const chr = Tx_Buffer.read() catch {
            break;
        };
        usbd.write_tx(&usbd.ep_buf[3].tx, i, chr);
        tx_count += 1;
    }
    // set next data length
    usbd.btable[3].COUNT_TX = tx_count;

    IN_TX_TRANSACTION = if (tx_count > 0) true else false;
    const expected: u2 = if (tx_count > 0) 0b11 else 0b10;
    const ep3r = USB.EP3R.read();
    // set STAT to ACK
    const set_tx3_stat = ep3r.STAT_TX ^ expected; // ACK or NAK
    USB.EP3R.write(.{
        .CTR_RX = 0,
        .DTOG_RX = 0, // 1: flip; don't care for single buffer
        .STAT_RX = 0, // 1: flip
        .SETUP = 0,
        .EP_TYPE = 0b00, // BULK
        .EP_KIND = 0, // ignored on INTERRUPT
        .CTR_TX = 0,
        .DTOG_TX = 0, // 1: flip; auto toggled
        .STAT_TX = set_tx3_stat, // 1: flip
        .EA = 3, // EP1
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
            _ = self;
            usbd.init();
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
