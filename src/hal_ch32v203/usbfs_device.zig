// http://kevincuzner.com/2018/01/29/bare-metal-stm32-writing-a-usb-driver/

const std = @import("std");
const microzig = @import("microzig");

const root = @import("root");

const ch32v = microzig.hal;
const pins = ch32v.pins;
const interrupt = ch32v.interrupt;
const time = ch32v.time;

const peripherals = microzig.chip.peripherals;
const USB = peripherals.USBFS_DEVICE;
const PFIC = peripherals.PFIC;

pub const Speed = enum(u1) {
    Full_speed = 0,
    Low_speed = 1,
};

pub const BufferSize = enum(u11) {
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

pub fn USBFS(comptime config: pins.Pin.Configuration) type {
    return root.usbd_class.USBFS(config);
}

const pin = pins.get_pins(root.pin_config);
// Number of endpoints
const EP_NUM = pin.__usbfs__.ep_num;
// packet buffer size.
pub const BUFFER_SIZE: u8 = @intFromEnum(pin.__usbfs__.buffer_size);

pub var ep_buf: [EP_NUM][BUFFER_SIZE]u8 align(4) = undefined;

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

// can copy by WORD from ep0 buffer
pub var setup_data: DESCRIPTOR_REQUEST align(4) = undefined;

pub var usb_request: root.usbd_class.USB_REQUESTS = .none;
var usb_standard_request: bool = true;
// return STALL if null
var descriptor: ?root.usbd_class.descriptors.DescriptorIndex = .device;

// // record last sent point
var next_point: u32 = 0;

pub fn init() void {
    USB.USBHD_BASE_CTRL.modify(.{
        // disbale USB
        .RB_UC_HOST_MODE = 0,
        .USBHD_UC_LOW_SPEED = @intFromEnum(pin.__usbfs__.speed),
        .USBHD_UC_SYS_CTRL_MASK = 0b00,
        .USBHD_UC_INT_BUSY = 1,
        .USBHD_UC_RESET_SIE = 0,
        .USBHD_UC_CLR_ALL = 0,
        .USBHD_UC_DMA_EN = 1,
    });

    // not work before setting R8_USB_CTRL
    USB.USBHD_UDEV_CTRL.modify(.{
        .USBHD_UD_PD_DIS = 1, // disable pull-down
        .USBHD_UD_LOW_SPEED = @intFromEnum(pin.__usbfs__.speed),
        .USBHD_UD_PORT_EN = 1,
    });

    // setup EP0
    reset_endpoints();

    // enable interrupts for USB
    USB.R8_USB_INT_EN.modify(.{
        // .RB_UIE_SUSPEND = 1,
        .USBHD_UIE_TRANSFER = 1,
        .USBHD_UIE_BUS_RST = 1,
        .USBHD_UIE_DEV_SOF = @intFromBool(pin.__usbfs__.handle_sof), // enable SOF interrupt,
    });
    USB.R8_USB_INT_FG.write_raw(0x1f); // write 1 to clear

    // CH32V20x_D6: interrupt number on the data sheet can't apply.
    // interrupts #63 and over not workk
    // const USB_HD_INT = @intFromEnum(interrupt.Interrupts.OTG_FS); // 83
    // https://github.com/openwch/ch32v20x/blob/main/C%2B%2B/Use%20MRS%20Create%20C%2B%2B%20project-example/CH32V203C8T6%2B%2B/Startup/startup_ch32v20x_D6.S
    const USB_HD_INT = @intFromEnum(interrupt.Interrupts.TIM8_BRK); // 59
    // clear pending interrupt
    PFIC.IPRR2.raw = (1 << (USB_HD_INT - 32));
    // open interrupt. Enabling global interupt is required.
    PFIC.IENR2.raw = (1 << (USB_HD_INT - 32));

    // enable pull-up
    USB.USBHD_BASE_CTRL.modify(.{
        // disbale USB
        .USBHD_UC_SYS_CTRL_MASK = 0b11,
    });
}

pub fn interrupt_handler() void {
    pin.led.toggle();
    // FIXME: not contained pin.triger
    // pin.triger.toggle();

    const int_flag = USB.R8_USB_INT_FG.read();
    if (int_flag.RB_UIF_BUS_RST == 1) {
        // reset
        reset_endpoints();
    } else if (int_flag.RB_UIF_TRANSFER == 1) {
        const int_status = USB.R8_USB_INT_ST.read();
        const pid = int_status.MASK_UIS_TOKEN;
        // 00 means OUT packet; 01 means SOF packet; 10 means IN packet; 11 means SETUP packet
        const ep_num = int_status.MASK_UIS_ENDP;
        // on SETUP, get wrong ep number
        switch (pid) {
            0b01 => { // SOF
                SOF();
            },
            0b11 => { // SETUP
                EP0_CONTROL_SETUP();
            },
            0b10 => { // IN
                if (ep_num == 0) {
                    if (usb_standard_request) {
                        EP0_CONTROL_IN();
                    } else {
                        class_EP0_CONTROL_IN();
                    }
                } else {
                    // other class specific endpoints
                    root.usbd_class.packet_handler(ep_num);
                }
            },
            0b00 => { //OUT
                if (ep_num == 0) {
                    if (usb_standard_request) {
                        EP0_CONTROL_OUT();
                    } else {
                        class_EP0_CONTROL_OUT();
                    }
                } else {
                    // other class specific endpoints
                    root.usbd_class.packet_handler(ep_num);
                }
            },
        }
    }
    USB.R8_USB_INT_FG.write_raw(0x1f); // write 1 to clear
}

const SOF: fn () void = if (@hasDecl(root.usbd_class, "SOF")) root.usbd_class.SOF else default_SOF;

fn default_SOF() void {}

fn reset_endpoints() void {
    // Reset device address
    USB.R8_USB_DEV_AD.write_raw(0);

    // setup endpoint0
    // set DMA buffer for endpoint0
    USB.R32_UEP0_DMA = @truncate(@intFromPtr(&ep_buf[0]));

    USB.R8_UEP0_T_CTRL.modify(.{
        .MASK_UEP_T_RES = 0b10, // NAK
        .USBHD_UEP_T_TOG = 0,
    });
    USB.R8_UEP0_R_CTRL.modify(.{
        .MASK_UEP_R_RES = 0b00, // ACK
        .USBHD_UEP_R_TOG = 0,
    });
    USB.R8_UEP0_T_LEN = 0;

    // call class specific reset endpoints routine
    reset_class_endpoints();
}

const reset_class_endpoints: fn () void = if (@hasDecl(root.usbd_class, "reset_endpoints")) root.usbd_class.reset_endpoints else default_reset_class_endpoints;

fn default_reset_class_endpoints() void {}

pub fn EP0_expect_IN(length: u32) void {
    // pin.led.toggle();
    // set next data length
    USB.R8_UEP0_T_LEN = @truncate(length);

    const ep0_ctrl = USB.R8_UEP0_T_CTRL.read();
    USB.R8_UEP0_T_CTRL.modify(.{
        .USBHD_UEP_T_TOG = ep0_ctrl.USBHD_UEP_T_TOG ^ 1,
        .MASK_UEP_T_RES = 0b00, // ACK
    });
    USB.R8_UEP0_R_CTRL.modify(.{
        .MASK_UEP_R_RES = 0b10, // NAK
    });
}

pub fn EP0_expect_OUT() void {
    USB.R8_UEP0_T_CTRL.modify(.{
        .MASK_UEP_T_RES = 0b10, // NAK
    });
    const ep0_ctrl = USB.R8_UEP0_R_CTRL.read();
    USB.R8_UEP0_R_CTRL.modify(.{
        .USBHD_UEP_R_TOG = ep0_ctrl.USBHD_UEP_R_TOG ^ 1,
        .MASK_UEP_R_RES = 0b00, // ACK
    });
}

pub fn EP0_STALL_IN() void {
    // set next data length
    USB.R8_UEP0_T_LEN = 0;

    USB.R8_UEP0_T_CTRL.modify(.{
        .MASK_UEP_T_RES = 0b11, // STALL
    });
    USB.R8_UEP0_R_CTRL.modify(.{
        .MASK_UEP_R_RES = 0b10, // NAK
    });
}

fn EP0_CONTROL_SETUP() void {
    // save setup transaction
    setup_data = @bitCast(ep_buf[0][0..8].*);

    USB.R8_UEP0_T_CTRL.modify(.{
        .USBHD_UEP_T_TOG = 0,
        .MASK_UEP_T_RES = 0b10, // NAK
    });
    USB.R8_UEP0_R_CTRL.modify(.{
        .USBHD_UEP_R_TOG = 0,
        .MASK_UEP_R_RES = 0b10, // NAK
    });

    // pin.led.toggle();
    switch (setup_data.bmRequestType.RequestType) {
        .standard => {
            usb_standard_request = true;
            switch (setup_data.bRequest) {
                .GET_DESCRIPTOR => {
                    usb_request = .get_descriptor;
                    next_point = 0;
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
                    // pin.led.toggle();

                    // std.log.err("USB bReq: {}", .{setup_data.bRequest});
                },
            }
        },
        else => {
            usb_standard_request = false;
            CLASS_REQUEST();
        },
    }
}

const DISPATCH_DESCRIPTOR: fn (u16) ?root.usbd_class.descriptors.DescriptorIndex = if (@hasDecl(root.usbd_class, "DISPATCH_DESCRIPTOR")) root.usbd_class.DISPATCH_DESCRIPTOR else default_DISPATCH_DESCRIPTOR;

pub fn default_DISPATCH_DESCRIPTOR(setup_value: u16) ?root.usbd_class.descriptors.DescriptorIndex {
    _ = setup_value;
    return null;
}

const CLASS_REQUEST: fn () void = if (@hasDecl(root.usbd_class, "CLASS_REQUEST")) root.usbd_class.CLASS_REQUEST else default_CLASS_REQUEST;

fn default_CLASS_REQUEST() void {
    switch (setup_data.bRequest) {
        .GET_INTERFACE => {
            usb_request = .get_interface;
            EP0_expect_IN(0);
        },
        // device class specific requests
        else => unreachable,
    }
}

const class_EP0_CONTROL_IN: fn () void = if (@hasDecl(root.usbd_class, "EP0_CONTROL_IN")) root.usbd_class.EP0_CONTROL_IN else default_class_EP0_CONTROL_IN;

fn default_class_EP0_CONTROL_IN() void {
    switch (usb_request) {
        .get_interface => {
            EP0_expect_IN(0);
        },
        else => unreachable,
    }
}

const class_EP0_CONTROL_OUT: fn () void = if (@hasDecl(root.usbd_class, "EP0_CONTROL_OUT")) root.usbd_class.EP0_CONTROL_OUT else default_class_EP0_CONTROL_OUT;

fn default_class_EP0_CONTROL_OUT() void {}

fn EP0_CONTROL_IN() void {
    switch (usb_request) {
        .get_descriptor => {
            if (descriptor) |index| {
                const desc_index = @intFromEnum(index);
                const desc = root.usbd_class.descriptors.DESCRIPTORS[desc_index];
                var desc_length = root.usbd_class.descriptors.DESCRIPTORS_LENGTH[desc_index];
                // limit max length under the requested length.
                if (setup_data.wLength < desc_length) desc_length = setup_data.wLength;

                var send_count = desc_length - next_point;
                if (send_count == 0) {
                    // no more data
                    // move on to the status transaction
                    EP0_expect_OUT();
                } else {
                    if (send_count > BUFFER_SIZE) send_count = BUFFER_SIZE;
                    // fill send buffer
                    for (0..send_count) |i| {
                        ep_buf[0][i] = desc[next_point + i];
                    }
                    next_point += send_count;
                    EP0_expect_IN(send_count);
                }
            } else {
                EP0_STALL_IN();
            }
        },
        .set_address => {
            USB.R8_USB_DEV_AD.write(.{
                .MASK_USB_ADDR = @truncate(setup_data.wValue), // Set device address
                .RB_UDA_GP_BIT = 0,
            });
            EP0_expect_IN(0);
        },
        .set_configuration => {
            EP0_expect_IN(0);
        },
        else => {
            // EP0_clear_interupt();
        },
    }
}

pub fn EP0_CONTROL_OUT() void {
    EP0_expect_IN(0);
}
