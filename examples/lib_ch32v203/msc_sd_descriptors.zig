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
    0x02, // bNumEndpoints: Number of endpoints (exclude endpoint 0)
    0x08, // bInterfaceClass: Mass Storage Class
    0x06, // bInterfaceSubClass: SCSI transparent command set
    0x50, // bInterfaceProtocol: Bulk-Only Transport
    0x00, // iInterface:

    // MSC descriptor
    //Endpoint 1 Descriptor
    0x07, // bLength: Endpoint Descriptor size
    USB_DESC_TYPE_ENDPOINT, // bDescriptorType: Endpoint
    MSC_IN_EP + EP_IN, // bEndpointAddress
    0x02, // bmAttributes: Bulk
    MAX_LEN, // wMaxPacketSize:
    0,
    0x1, // bInterval: 1ms

    // endpoint 2 IN descriptor
    0x07, // bLength: Endpoint Descriptor size
    USB_DESC_TYPE_ENDPOINT, // bDescriptorType: Endpoint
    MSC_OUT_EP + EP_OUT, // bEndpointAddress
    0x02, // bmAttributes: Bulk
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

pub const STR_4 = [0]u8{
    // 20, // length
    // 0x03, // string descriptor (0x03)
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

pub const InquiryResponse = [36]u8{
    0x00, // peripheral device is connected, direct access block device
    0x80, // removable
    0x06, // 4=> SPC-2, 6 => SPC-4
    0x02, // response is in format specified by SPC-2
    0x20, // n-4 = 36-4=32= 0x20
    0x00, // sccs etc.
    0x00, // bque=1 and cmdque=0,indicates simple queueing
    0x00, // 00 obsolete, 0x80 for basic task queueing
    'C', 'H', '3', '2', 'V', 'x', '0', '3', // T10-assigned Vendor ID
    'U', 'S', 'B', ' ', 'M', 'e', 'm', 'o', 'r', 'y', ' ', ' ', ' ', ' ', ' ', ' ', //product ID
    '0', '0', '0', '1', //revision information
};

pub const ModeSenseResponse_UsbMemory = [68]u8{
    // Mode parameter header, last param length 0x43 (67)
    // Mode Data Length: 67
    // Medium Type: 0x00
    // Device-Specific Parameter: 0x00
    // Block Descriptor Length: 0
    0x43, 0x00, 0x00, 0x00,

    // Read/Write Error Recovery Mode Page
    //     0... .... = PS: False
    //     .0.. .... = SPF: False
    //     ..00 0001 = SBC-2 Page Code: Read/Write Error Recovery (0x01)
    //     Page Length: 10
    //     0... .... = AWRE: False
    //     .0.. .... = ARRE: False
    //     ..0. .... = TB: False
    //     ...0 .... = RC: False
    //     .... 0... = EER: False
    //     .... .0.. = PER: False
    //     .... ..0. = DTE: False
    //     .... ...0 = DCR: False
    //     Read Retry Count: 3
    //     Correction Span: 0
    //     Head Offset Count: 0
    //     Data Strobe Offset Count: 0
    //     Write Retry Count: 128
    //     Recovery Time Limit (ms): 0
    0x01, 0x0a, 0x00, 0x03,
    0x00, 0x00, 0x00, 0x00,
    0x80, 0x03, 0x00, 0x00,

    // Flexible Disk Mode Page
    //     0... .... = PS: False
    //     .0.. .... = SPF: False
    //     ..00 0101 = SBC-2 Page Code: Flexible Disk (0x05)
    //     Page Length: 30
    //     Unknown Page
    0x05, 0x1e, 0x13, 0x88,
    0x00, 0x10, 0x3f, 0x00,
    0x00, 0x0f, 0x60, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x05,
    0x1e, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x01, 0x68, 0x00, 0x00,

    // Unknown (0x0000001b) Mode Page
    //     0... .... = PS: False
    //     .0.. .... = SPF: False
    //     ..01 1011 = SBC-2 Page Code: Unknown (0x1b)
    //     Page Length: 10
    //     Unknown Page
    0x1b, 0x0a, 0x00, 0x01,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,

    // Informational Exceptions Control Mode Page
    //     0... .... = PS: False
    //     .0.. .... = SPF: False
    //     ..01 1100 = SPC-2 Page Code: Informational Exceptions Control (0x1c)
    //     Page Length: 6
    //     0... .... = Perf: False
    //     ..0. .... = EBF: False
    //     ...0 .... = EWasc: False
    //     .... 0... = DExcpt: False
    //     .... .0.. = Test: False
    //     .... ...0 = LogErr: False
    //     .... 0101 = MRIE: Generate No Sense (0x5)
    //     Interval Timer: 28
    0x1c, 0x06, 0x00, 0x05,
    0x00, 0x00, 0x00, 0x1c,
};

pub const ModeSenseResponse_CardReader = [36]u8{
    // Mode parameter header, last param length 0x23 (35)
    // Mode Data Length: 35
    // Medium Type: 0x00
    // Device-Specific Parameter: 0x00
    // Block Descriptor Length: 0
    0x23, 0x00, 0x00, 0x00,

    // Caching Mode Page
    //     0... .... = PS: False
    //     .0.. .... = SPF: False
    //     ..00 1000 = SBC-2 Page Code: Caching (0x08)
    //     Page Length: 18
    //     0... .... = IC: False
    //     .0.. .... = ABPF: False
    //     ..0. .... = CAP: False
    //     ...0 .... = Disc: False
    //     .... 0... = Size: False
    //     .... .0.. = WCE: False
    //     .... ..0. = MF: False
    //     .... ...0 = RCD: False
    //     0000 .... = Demand Read Retention Priority: 0
    //     .... 0000 = Write Retention Priority: 0
    //     Disable Pre-fetch Xfer Len: 0
    //     Minimum Pre-Fetch: 0
    //     Maximum Pre-Fetch: 0
    //     Maximum Pre-Fetch Ceiling: 0
    //     0... .... = FSW: False
    //     .0.. .... = LBCSS: False
    //     ..0. .... = DRA: False
    //     ...0 0000 = Vendor Specific: 0
    //     Number of Cache Segments: 0
    //     Cache Segment Size: 0
    //     Non-Cache Segment Size: 0
    0x08, 0x12, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,

    // Informational Exceptions Control Mode Page
    //     0... .... = PS: False
    //     .0.. .... = SPF: False
    //     ..01 1100 = SPC-2 Page Code: Informational Exceptions Control (0x1c)
    //     Page Length: 10
    //     0... .... = Perf: False
    //     ..0. .... = EBF: False
    //     ...0 .... = EWasc: False
    //     .... 0... = DExcpt: False
    //     .... .0.. = Test: False
    //     .... ...0 = LogErr: False
    //     .... 0000 = MRIE: No Reporting of Informational Exception Condition (0x0)
    //     Interval Timer: 0
    //     Report Count: 0
    0x1c, 0x0a, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
    0x00, 0x00, 0x00, 0x00,
};
