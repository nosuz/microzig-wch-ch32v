const microzig = @import("microzig");

const root = @import("root");

const MAX_LEN = root.usbd_class.BUFFER_SIZE;

const VENDER_ID_H: u8 = 0x66;
const VENDER_ID_L: u8 = 0x66;

const PRODUCT_ID_H: u8 = 0x56;
const PRODUCT_ID_L: u8 = 0x78;

const DEV_DESC = [18]u8{
    18, // size of descriptor
    0x01, // device descriptor (0x01)
    0x00, // USB 2.0 in BCD
    0x02,
    0, // class code. 0: defined in interface
    0, // subclass. 0: unused
    0, // protocol. 0: unused
    MAX_LEN, // max packet size for endpoint 0
    VENDER_ID_L, // vender ID
    VENDER_ID_H,
    PRODUCT_ID_L, // product ID
    PRODUCT_ID_H,
    0, // device version in BCD
    1,
    1, // index for manufacture string
    2, // index for product string
    3, // index for serial number string
    1, // number of possible configs
};

const CONFIG_DESC = [34]u8{
    // configuration descriptor
    9, // size of descriptor
    0x02, // configuration descriptor (0x02)
    34, // total length: conf(9) + iface(9) + hid(9) + ep1(7)
    0,
    1, // num of ifaces
    1, // num of configs
    0, // no config string
    0x80, // device attrib: bus powered, no remote wakeup
    49, // max power by 2mA: 49 * 2mA = 98mA

    // interface descriptor
    9, // size of descriptor
    0x04, // interface descriptor (0x04)
    0, // iface #
    0, // Alt string
    2, // num of endpoints
    0x03, // HID class
    0, // no subclass
    1, // iface protrol: keyboard
    4, // index of interface string

    // HID descriptor
    9, // size of descriptor
    0x21, // hid descriptor (0x21)
    0x10, // hid version
    0x01,
    0, // no country code
    1, // num of descriptor
    34, // descriptor type: report
    67, // report descriptor length
    0,

    // // endpoint 1 OUT descriptor
    // 7, // size of descriptor
    // 0x05, // descriptor type: endpoint
    // 0x01, // endpoint address: endpoint 1 OUT
    // 0x03, // transfer type: interrupt
    // MAX_LEN as u8, // max packet size
    // 0,
    // 10, // polling interval in ms

    // endpoint 1 IN descriptor
    7, // size of descriptor
    0x05, // descriptor type: endpoint
    0x81, // endpoint address: endpoint 1 IN
    0x03, // transfer type: interrupt
    MAX_LEN, // max packet size
    0,
    10, // polling interval in ms
};

const RPT_DESC = [67]u8{
    0x05,
    0x01, // USAGE_PAGE (Generic Desktop),
    0x09,
    0x06, // USAGE (Keyboard),
    0xa1,
    0x01, // COLLECTION (Application),
    0x75,
    0x01, // 　REPORT_SIZE (1),
    0x95,
    0x08, // 　REPORT_COUNT (8),
    0x05,
    0x07, // 　USAGE_PAGE (Key Codes),
    0x1a,
    0xe0,
    0x00, // 　USAGE_MINIMUM (224),
    0x2a,
    0xe7,
    0x00, // 　USAGE_MAXIMUM (231),
    0x15,
    0x00, // 　LOGICAL_MINIMUM (0),
    0x25,
    0x01, // 　LOGICAL_MAXIMUM (1),
    0x81,
    0x02, // 　INPUT (Data,Var,Abs), ;Modifier byte
    0x95,
    0x01, // 　REPORT_COUNT (1),
    0x75,
    0x08, // 　REPORT_SIZE (8),
    0x81,
    0x01, // 　INPUT (Cnst,Ary,Abs), ;Reserved byte
    0x95,
    0x05, // 　REPORT_COUNT (5),
    0x75,
    0x01, // 　REPORT_SIZE (1),
    0x05,
    0x08, // 　USAGE_PAGE (LED),
    0x19,
    0x01, // 　USAGE_MINIMUM (1),
    0x29,
    0x05, // 　USAGE_MAXIMUM (5),
    0x91,
    0x02, // 　OUTPUT (Data,Var,Abs), ;LED report
    0x95,
    0x01, // 　REPORT_COUNT (1),
    0x75,
    0x03, // 　REPORT_SIZE (3),
    0x91,
    0x01, // 　OUTPUT (Cnst,Ary,Abs), ;LED report padding
    0x95,
    0x06, // 　REPORT_COUNT (6),
    0x75,
    0x08, // 　REPORT_SIZE (8),
    0x15,
    0x00, // 　LOGICAL_MINIMUM (0),
    0x26,
    0xff,
    0x00, // 　LOGICAL_MAXIMUM(255),
    0x05,
    0x07, // 　USAGE_PAGE (Key Codes),
    0x19,
    0x00, // 　USAGE_MINIMUM (0),
    0x2a,
    0xff,
    0x00, // 　USAGE_MAXIMUM (255),
    0x81,
    0x00, // 　INPUT (Data,Ary,Abs),
    0xc0, // END_COLLECTION
    // Total:67 Bytes, 0x0043 (swapped: 0x4300)
};

const LANG_IDS = [4]u8{
    4, // length
    0x03, // string descriptor (0x03)
    0x09, // 0x0409 English (United States)
    0x04,
    // 0x11, // 0x0411 Japanese
    // 0x04,
};

const STR_1 = [12]u8{
    12, // length
    0x03, // string descriptor (0x03)
    'n',
    0,
    'o',
    0,
    's',
    0,
    'u',
    0,
    'z',
    0,
};

const STR_2 = [18]u8{
    18, // length
    0x03, // string descriptor (0x03)
    'C',
    0,
    'H',
    0,
    '3',
    0,
    '2',
    0,
    'V',
    0,
    '1',
    0,
    '0',
    0,
    '3',
    0,
};

const STR_3 = [12]u8{
    12, // length
    0x03, // string descriptor (0x03)
    '1',
    0,
    '.',
    0,
    '2',
    0,
    '.',
    0,
    '3',
    0,
};

const STR_4 = [22]u8{
    22, // length
    0x03, // string descriptor (0x03)
    'h',
    0,
    'i',
    0,
    'd',
    0,
    ' ',
    0,
    's',
    0,
    'a',
    0,
    'm',
    0,
    'p',
    0,
    'l',
    0,
    'e',
    0,
};

pub const DESCRIPTORS = [_][*]const u8{
    &DEV_DESC,
    &CONFIG_DESC,
    &LANG_IDS,
    &STR_1,
    &STR_2,
    &STR_3,
    &STR_4,

    // HID class specific descriptor
    &RPT_DESC,
};
// can't get length from [*]u8
pub const DESCRIPTORS_LENGTH = [_]usize{
    DEV_DESC.len,
    CONFIG_DESC.len,
    LANG_IDS.len,
    STR_1.len,
    STR_2.len,
    STR_3.len,
    STR_4.len,

    // HID class specific descriptor
    RPT_DESC.len,
};

pub const DescriptorIndex = enum(u4) {
    device = 0,
    configuration = 1,
    lang_id = 2,
    string1 = 3,
    string2 = 4,
    string3 = 5,
    string4 = 6,

    // HID class specific descriptor
    report = 7,
};
