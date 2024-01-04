const std = @import("std"); // allocator
const root = @import("root"); // for debug

const microzig = @import("microzig");
const ch32v = microzig.hal;
const usbfs = ch32v.usbfs;
const pins = ch32v.pins;
const rb = ch32v.ring_buffer;
const time = ch32v.time;

pub const BUFFER_SIZE = usbfs.BUFFER_SIZE;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USBFS_DEVICE;

// provide device descriptor data to usbfs
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

    USB.R8_UEP1_T_CTRL.modify(.{
        .USBHD_UEP_T_TOG = 0,
        .MASK_UEP_T_RES = 0b10, // NAK
        .USBHD_UEP_AUTO_TOG = 1,
    });
    USB.R8_UEP1_R_CTRL.modify(.{
        .USBHD_UEP_R_TOG = 0,
        .MASK_UEP_R_RES = 0b10, // NAK
        .USBHD_UEP_AUTO_TOG = 1,
    });
    USB.R8_UEP1_T_LEN = 0;

    // endpoint 2 OUT
    USB.R8_UEP2_3_MOD.write_raw(0);

    USB.R8_UEP2_R_CTRL.modify(.{
        .USBHD_UEP_R_TOG = 0,
        .MASK_UEP_R_RES = 0b10, // NAK
        .USBHD_UEP_AUTO_TOG = 1,
    });
    USB.R8_UEP2_T_CTRL.modify(.{
        .USBHD_UEP_T_TOG = 0,
        .MASK_UEP_T_RES = 0b10, // NAK
        .USBHD_UEP_AUTO_TOG = 1,
    });
    USB.R8_UEP2_T_LEN = 0;

    // endpoint 3 IN
    // already set at endpoint 2
    // USB.R8_UEP2_3_MOD.write_raw(0);

    USB.R8_UEP3_R_CTRL.modify(.{
        .USBHD_UEP_R_TOG = 0,
        .MASK_UEP_R_RES = 0b10, // NAK
        .USBHD_UEP_AUTO_TOG = 1,
    });
    USB.R8_UEP3_T_CTRL.modify(.{
        .USBHD_UEP_T_TOG = 0,
        .MASK_UEP_T_RES = 0b10, // NAK
        .USBHD_UEP_AUTO_TOG = 1,
    });
    USB.R16_UEP3_T_LEN = 0;
}

// configure device. called by SET_CONFIGURATION request.
pub fn set_configuration(setup_value: u16) void {
    _ = setup_value;

    // endpoint 1 IN
    USB.R32_UEP1_DMA = @truncate(@intFromPtr(&usbfs.ep_buf[1]));

    USB.R8_UEP4_1_MOD.modify(.{
        .RB_UEP1_RX_EN = 0,

        .RB_UEP1_TX_EN = 1,
        .RB_UEP1_BUF_MOD = 0, // Single buffer
    });

    // endpoint 2 OUT endpoint 3 IN
    USB.R32_UEP2_DMA = @truncate(@intFromPtr(&usbfs.ep_buf[2]));
    USB.R32_UEP3_DMA = @truncate(@intFromPtr(&usbfs.ep_buf[3]));

    USB.R8_UEP2_3_MOD.modify(.{
        .RB_UEP2_RX_EN = 1, // OUT
        .RB_UEP2_TX_EN = 0,
        .RB_UEP2_BUF_MOD = 0, // Single buffer

        .RB_UEP3_RX_EN = 0,
        .RB_UEP3_TX_EN = 1, // IN
        .RB_UEP3_BUF_MOD = 0, // Single buffer
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
    switch (usbfs.setup_data.bRequest) {
        .GET_INTERFACE => {
            usbfs.usb_request = .get_interface;
            usbfs.EP0_expect_IN(0);
        },
        .SET_CONFIGURATION => {
            usbfs.usb_request = .set_configuration;
            usbfs.EP0_expect_OUT();
        },
        .SET_LINE_CODING => {
            usbfs.usb_request = .set_line_coding;
            usbfs.EP0_expect_OUT();
        },
        .SET_CONTROL_LINE_STATE => {
            usbfs.usb_request = .set_line_control_state;
            // SETUP value is flow control
            const con_state = if ((usbfs.setup_data.wValue & 0x01) == 0) false else true;
            set_connection_state(con_state);
            usbfs.EP0_expect_IN(0);
        },
        else => {},
    }
}

// handle device class specific EP0 control in packet
// define if custom EP0_CONTROL_IN packet handler is required.
// pub fn EP0_CONTROL_IN() void {
//     switch (usbfs.usb_request) {
//         .get_interface => {},
//         else => unreachable,
//     }
//     usbfs.EP0_expect_IN(0);
// }

// handle device class specific EP0 control out packet
// define if custom EP0_CONTROL_OUT packet handler is required.
pub fn EP0_CONTROL_OUT() void {
    switch (usbfs.usb_request) {
        .set_line_coding => {
            // set serial config
            // LineCodingFormat is 7 bytes.
            var _buffer = [_]u8{0} ** 7;
            const ep0_buf = &usbfs.ep_buf[0];
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

    usbfs.EP0_expect_IN(0);
}

pub fn EP1_IN() void {
    // set next data length
    // USB.R16_UEP1_T_LEN = 0;

    // USB.R8_UEP1_CTRL.modify(.{
    //     .MASK_UEP_T_RES = 0b00, // ACK
    // });
}

pub fn EP3_IN() void {
    set_ep3_tx_data();
}

pub fn EP2_OUT() void {
    // FIXME: need to respose NAK before full to avoid loose data
    // response NAK if buffer full
    if (!Rx_Buffer.is_full()) {
        const buf = &usbfs.ep_buf[2];
        for (0..USB.R16_USB_RX_LEN) |i| {
            Rx_Buffer.write(buf[i]) catch {
                break;
            };
        }
    }
}

fn set_ep3_tx_data() void {
    var tx_count: u8 = 0;
    const buf = &usbfs.ep_buf[3];
    for (0..usbfs.BUFFER_SIZE) |i| {
        const chr = Tx_Buffer.read() catch {
            break;
        };
        buf[i] = chr;
        tx_count += 1;
    }
    // set next data length
    USB.R16_UEP3_T_LEN = tx_count;
    // USBHD doesn't change to NAK automatically. Without set RES, it will keep RES state.
    if (tx_count == 0) {
        // No more data to send
        USB.R8_UEP3_T_CTRL.modify(.{
            .MASK_UEP_T_RES = 0b10, // NAK
        });
    } else {
        USB.R8_UEP3_T_CTRL.modify(.{
            .MASK_UEP_T_RES = 0b00, // ACK
        });
    }
    IN_TX_TRANSACTION = if (tx_count > 0) true else false;
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
    // TODO: enable EP2 and EP3
    if (state) {
        USB.R8_UEP2_R_CTRL.modify(.{
            .MASK_UEP_R_RES = 0b00, // ACK
        });
    } else {
        USB.R8_UEP2_R_CTRL.modify(.{
            .MASK_UEP_R_RES = 0b10, // NAK
        });
    }

    CONNECTED = state;
}

pub fn start_tx() void {
    if (Tx_Buffer.is_empty() or IN_TX_TRANSACTION) return;

    set_ep3_tx_data();
}

pub fn USBFS(comptime config: pins.Pin.Configuration) type {
    return struct {
        speed: usbfs.Speed = config.usbfs_speed orelse .Low_speed,
        ep_num: u3 = config.usbfs_ep_num orelse 1,
        buffer_size: usbfs.BufferSize = config.usbfs_buffer_size orelse .byte_8,
        handle_sof: bool = config.usbfs_handle_sof orelse false,

        // mandatory or call directly usbfs.init()
        pub fn init(self: @This()) void {
            _ = self;
            usbfs.init();
        }

        pub fn read(self: @This()) u8 {
            _ = self;
            return Rx_Buffer.read_block();
        }

        pub fn write_byte(self: @This(), chr: u8) void {
            _ = self;
            // discard data if connection is closed.
            if (CONNECTED) Tx_Buffer.write_block(chr);
        }

        pub fn write(self: @This(), payload: []const u8) WriteError!usize {
            _ = self;
            if (CONNECTED) {
                for (payload) |byte| {
                    Tx_Buffer.write_block(byte);
                }
            }

            return payload.len;
        }

        const WriteError = error{};

        pub const Writer = std.io.Writer(@This(), WriteError, @This().write);
        // https://github.com/ziglang/zig/blob/master/lib/std/io.zig
        // const Reader = std.io.GenericReader(@This(), ReadError, @This().read);

        pub fn writer(self: @This()) Writer {
            return .{
                .context = self,
            };
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
