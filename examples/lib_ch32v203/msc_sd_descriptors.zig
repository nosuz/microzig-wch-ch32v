const microzig = @import("microzig");

const root = @import("root");

const MAX_LEN = root.usbd_class.BUFFER_SIZE;

const VENDER_ID_H: u8 = 0x66;
const VENDER_ID_L: u8 = 0x66;

const PRODUCT_ID_H: u8 = 0x56;
const PRODUCT_ID_L: u8 = 0x78;

pub const DEV_DESC = [18]u8{
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

const USB_DESC_TYPE_CONFIGURATION: u8 = 0x02; // bDescriptorType: Configuration
const USB_DESC_TYPE_INTERFACE: u8 = 0x04; // bDescriptorType: Interface
const CS_INTERFACE: u8 = 0x24;
const USB_DESC_TYPE_ENDPOINT: u8 = 0x05;

const EP_IN: u8 = 0x80;
const EP_OUT: u8 = 0x00;

const MSC_IN_EP: u8 = 1;
const MSC_OUT_EP: u8 = 2;

pub const CONFIG_DESC = [32]u8{
    //Configuration Descriptor
    0x09, // bLength: Configuration Descriptor size
    USB_DESC_TYPE_CONFIGURATION, // bDescriptorType: Configuration
    // wTotalLength:no of returned bytes
    32, // or length of CONFIG_DESC
    0x00,
    0x01, // bNumInterfaces: 1 interface
    0x01, // bConfigurationValue: Configuration value
    0x00, // iConfiguration: Index of string descriptor describing the configuration
    0x80, // bmAttributes: bus powered(0x80), self power (0xc0)
    0x49, // MaxPower 146 mA

    //Interface Descriptor
    0x09, // bLength: Interface Descriptor size
    USB_DESC_TYPE_INTERFACE, // bDescriptorType: Interface
    // Interface descriptor type
    0x00, // bInterfaceNumber: Number of Interface
    0x00, // bAlternateSetting: Alternate setting
    0x02, // bNumEndpoints: One endpoints used
    0x08, // bInterfaceClass: Mass Storage Class
    0x06, // bInterfaceSubClass: SCSI transparent command set
    0x50, // bInterfaceProtocol: Bulk-Only Transport
    0x00, // iInterface:

    // MSC descriptor
    //Endpoint 1 Descriptor
    0x07, // bLength: Endpoint Descriptor size
    USB_DESC_TYPE_ENDPOINT, // bDescriptorType: Endpoint
    MSC_IN_EP + EP_IN, // bEndpointAddress
    0x10, // bmAttributes: Bulk
    MAX_LEN, // wMaxPacketSize:
    0,
    0x10, // bInterval: 10ms

    // endpoint 2 IN descriptor
    0x07, // bLength: Endpoint Descriptor size
    USB_DESC_TYPE_ENDPOINT, // bDescriptorType: Endpoint
    MSC_OUT_EP + EP_OUT, // bEndpointAddress
    0x10, // bmAttributes: Bulk
    MAX_LEN, // wMaxPacketSize:
    0,
    0x0, // bInterval: none
};

pub const LANG_IDS = [4]u8{
    4, // length
    0x03, // string descriptor (0x03)
    0x09, // 0x0409 English (United States)
    0x04,
    // 0x11, // 0x0411 Japanese
    // 0x04,
};

pub const STR_1 = [12]u8{
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

pub const STR_2 = [18]u8{
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
    '2',
    0,
    '0',
    0,
    '3',
    0,
};

pub const STR_3 = [12]u8{
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

pub const STR_4 = [20]u8{
    20, // length
    0x03, // string descriptor (0x03)
    'm',
    0,
    's',
    0,
    'c',
    0,
    ' ',
    0,
    'c',
    0,
    'l',
    0,
    'a',
    0,
    's',
    0,
    's',
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
};

pub const DescriptorIndex = enum(u4) {
    device = 0,
    configuration = 1,
    lang_id = 2,
    string1 = 3,
    string2 = 4,
    string3 = 5,
    string4 = 6,
};
