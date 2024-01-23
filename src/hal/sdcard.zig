const microzig = @import("microzig");
const root = @import("root");

const ch32v = microzig.hal;
const spi = ch32v.spi;
const time = ch32v.time;
const pins = ch32v.pins;

pub const SECTOR_SIZE = 512;

const SDError = error{
    InitError,
    ReadError,
    WriteError,
    CardError,
    CrcError,
};

const CMD0 = [_]u8{ 0b01_000000 + 0, 0, 0, 0, 0, 0b1001010_1 }; // need correct CRC7 (0x4A << 1 | 1 = 0x95)
const CMD8 = [_]u8{ 0x40 + 8, 0, 0, 1, 0xAA, 0x87 }; // need correct CRC7
// https://userweb.alles.or.jp/chunichidenko/sdif27.html
const CMD9 = [_]u8{ 0x40 + 9, 0, 0, 0, 0, 0xAF }; // ask CSD; recieve data packet 16 bytes + CRC
const CMD10 = [_]u8{ 0x40 + 10, 0, 0, 0, 0, 0x1B }; // ask CID; recieve data packet 16 bytes + CRC
const CMD16 = [_]u8{ 0x40 + 16, 0, 0, 2, 0, 0x15 }; // set block length to 512 bytes for SDCD not for SDHC and SDXC
const CMD58 = [_]u8{ 0x40 + 58, 0, 0, 0, 0, 0xFD };
const CMD59 = [_]u8{ 0x40 + 59, 0, 0, 0, 1, 0x83 }; // turn ON CRC; off by default

// Pre-command for ACMD
const CMD55 = [_]u8{ 0x40 + 55, 0, 0, 0, 0, 0x65 };
// Table 7-4 : Application Specific Commands used/reserved by SD Memory Card - SPI Mode
const ACMD41 = [_]u8{ 0x40 + 41, 0b0100_0000, 0, 0, 0, 0x77 };

const CMD17 = [_]u8{ 0x40 + 17, 0, 0, 0, 0, 1 }; // single read
const CMD18 = [_]u8{ 0x40 + 18, 0, 0, 0, 0, 1 }; // multiple read
const CMD12 = [_]u8{ 0x40 + 12, 0, 0, 0, 0, 0x61 }; // stop read

const ACMD23 = [_]u8{ 0x40 + 23, 0, 0, 0, 0, 1 }; // pre-define number of write blocks
const CMD24 = [_]u8{ 0x40 + 24, 0, 0, 0, 0, 1 }; // single write
const CMD25 = [_]u8{ 0x40 + 25, 0, 0, 0, 0, 1 }; // multiple write
// const CMD13 = [_]u8{ 0x40 + 13, 0, 0, 0, 0, 1 }; // get status

pub fn SDCARD_DRIVER(comptime spi_port_name: []const u8, comptime cs_pin_name: []const u8) type {
    // const sd = sdcard.SDCARD_DRIVER("spi", "cs");
    const pin = pins.get_pins(root.pin_config);

    const spi_port = @field(pin, spi_port_name);
    const cs_pin = @field(pin, cs_pin_name);

    return struct {
        pub var is_sd: bool = false;

        var response_r1: [1]u8 = undefined;
        var response_r3: [4]u8 = undefined;
        var response_r7: [4]u8 = undefined;

        fn crc7(message: []const u8) u8 {
            // https://bushowhige.blogspot.com/2017/05/blog-post.html
            const poly: u8 = 0b10001001;
            var crc: u8 = 0;
            for (0..message.len) |i| {
                crc ^= message[i];
                for (0..8) |_| {
                    crc = if ((crc & 0x80) > 0) ((crc ^ poly) << 1) else (crc << 1);
                }
            }
            return crc >> 1;
        }

        fn send_with_crc(cmd: []const u8) void {
            var cmd_crc: [6]u8 = undefined;
            for (0..6) |i| {
                cmd_crc[i] = cmd[i];
            }
            cmd_crc[5] = (crc7(cmd[0..(cmd.len - 1)]) << 1) | 0b1;

            spi_port.write(&cmd_crc);
        }

        const ccitt_hash = [_]u16{
            0x0000, 0x1021, 0x2042, 0x3063, 0x4084, 0x50a5, 0x60c6, 0x70e7,
            0x8108, 0x9129, 0xa14a, 0xb16b, 0xc18c, 0xd1ad, 0xe1ce, 0xf1ef,
            0x1231, 0x0210, 0x3273, 0x2252, 0x52b5, 0x4294, 0x72f7, 0x62d6,
            0x9339, 0x8318, 0xb37b, 0xa35a, 0xd3bd, 0xc39c, 0xf3ff, 0xe3de,
            0x2462, 0x3443, 0x0420, 0x1401, 0x64e6, 0x74c7, 0x44a4, 0x5485,
            0xa56a, 0xb54b, 0x8528, 0x9509, 0xe5ee, 0xf5cf, 0xc5ac, 0xd58d,
            0x3653, 0x2672, 0x1611, 0x0630, 0x76d7, 0x66f6, 0x5695, 0x46b4,
            0xb75b, 0xa77a, 0x9719, 0x8738, 0xf7df, 0xe7fe, 0xd79d, 0xc7bc,
            0x48c4, 0x58e5, 0x6886, 0x78a7, 0x0840, 0x1861, 0x2802, 0x3823,
            0xc9cc, 0xd9ed, 0xe98e, 0xf9af, 0x8948, 0x9969, 0xa90a, 0xb92b,
            0x5af5, 0x4ad4, 0x7ab7, 0x6a96, 0x1a71, 0x0a50, 0x3a33, 0x2a12,
            0xdbfd, 0xcbdc, 0xfbbf, 0xeb9e, 0x9b79, 0x8b58, 0xbb3b, 0xab1a,
            0x6ca6, 0x7c87, 0x4ce4, 0x5cc5, 0x2c22, 0x3c03, 0x0c60, 0x1c41,
            0xedae, 0xfd8f, 0xcdec, 0xddcd, 0xad2a, 0xbd0b, 0x8d68, 0x9d49,
            0x7e97, 0x6eb6, 0x5ed5, 0x4ef4, 0x3e13, 0x2e32, 0x1e51, 0x0e70,
            0xff9f, 0xefbe, 0xdfdd, 0xcffc, 0xbf1b, 0xaf3a, 0x9f59, 0x8f78,
            0x9188, 0x81a9, 0xb1ca, 0xa1eb, 0xd10c, 0xc12d, 0xf14e, 0xe16f,
            0x1080, 0x00a1, 0x30c2, 0x20e3, 0x5004, 0x4025, 0x7046, 0x6067,
            0x83b9, 0x9398, 0xa3fb, 0xb3da, 0xc33d, 0xd31c, 0xe37f, 0xf35e,
            0x02b1, 0x1290, 0x22f3, 0x32d2, 0x4235, 0x5214, 0x6277, 0x7256,
            0xb5ea, 0xa5cb, 0x95a8, 0x8589, 0xf56e, 0xe54f, 0xd52c, 0xc50d,
            0x34e2, 0x24c3, 0x14a0, 0x0481, 0x7466, 0x6447, 0x5424, 0x4405,
            0xa7db, 0xb7fa, 0x8799, 0x97b8, 0xe75f, 0xf77e, 0xc71d, 0xd73c,
            0x26d3, 0x36f2, 0x0691, 0x16b0, 0x6657, 0x7676, 0x4615, 0x5634,
            0xd94c, 0xc96d, 0xf90e, 0xe92f, 0x99c8, 0x89e9, 0xb98a, 0xa9ab,
            0x5844, 0x4865, 0x7806, 0x6827, 0x18c0, 0x08e1, 0x3882, 0x28a3,
            0xcb7d, 0xdb5c, 0xeb3f, 0xfb1e, 0x8bf9, 0x9bd8, 0xabbb, 0xbb9a,
            0x4a75, 0x5a54, 0x6a37, 0x7a16, 0x0af1, 0x1ad0, 0x2ab3, 0x3a92,
            0xfd2e, 0xed0f, 0xdd6c, 0xcd4d, 0xbdaa, 0xad8b, 0x9de8, 0x8dc9,
            0x7c26, 0x6c07, 0x5c64, 0x4c45, 0x3ca2, 0x2c83, 0x1ce0, 0x0cc1,
            0xef1f, 0xff3e, 0xcf5d, 0xdf7c, 0xaf9b, 0xbfba, 0x8fd9, 0x9ff8,
            0x6e17, 0x7e36, 0x4e55, 0x5e74, 0x2e93, 0x3eb2, 0x0ed1, 0x1ef0,
        };

        fn crc16(message: []const u8) u16 {
            // CRC16-CCITT
            // https://gist.github.com/rafacouto/59326c90d6a55f86a3ba
            var crc: u16 = 0;
            for (0..message.len) |i| {
                crc = (crc << 8) ^ ccitt_hash[@as(u8, @truncate(((crc >> 8) ^ message[i]) & 0x00FF))];
            }

            return crc;
        }

        pub inline fn activate() void {
            spi_port.wait_complete();
            spi_port.write(&[_]u8{0xff} ** 5);
            cs_pin.put(0);
            // send dummy
            spi_port.write(&[_]u8{0xff});
        }

        pub inline fn deactivate() void {
            spi_port.wait_complete();
            cs_pin.put(1);
            // send dummy
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();
        }

        pub fn init() SDError!void {
            const max_retry = 10;
            for (0..max_retry) |i| {
                if (do_init() catch false) break;
                if (i == (max_retry - 1)) return SDError.InitError;
                time.sleep_ms(1);
            }
        }

        fn do_init() SDError!bool {
            errdefer deactivate();

            time.sleep_ms(1);

            // send dumy clock
            cs_pin.put(1);
            // spi_port.write(&([_]u8{0xff} ** 10)); // loop is smaller
            for (0..10) |_| {
                spi_port.write(&[1]u8{0xff});
            }
            spi_port.wait_complete();

            time.sleep_ms(1);

            // CMD0
            activate();
            spi_port.write(&CMD0);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            if ((response_r1[0] & 0x7F) == 8) return SDError.CrcError;
            deactivate();

            time.sleep_ms(1);

            // CMD8
            activate();
            spi_port.write(&CMD8);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            if ((response_r1[0] & 0x7F) == 8) return SDError.CrcError;
            spi_port.read(&response_r7);
            deactivate();

            time.sleep_ms(1);

            // CMD9, Turn ON CRC
            activate();
            spi_port.write(&CMD59);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            if ((response_r1[0] & 0x7F) == 8) return SDError.CrcError;
            deactivate();

            time.sleep_ms(1);

            // ACMD41
            for (0..2000) |j| {
                activate();
                spi_port.write(&CMD55);
                for (0..10) |i| {
                    spi_port.read(&response_r1);
                    if ((response_r1[0] & 0x80) == 0) break;
                    if (i == 9) return SDError.InitError;
                }
                if ((response_r1[0] & 0x7F) == 8) return SDError.CrcError;

                spi_port.write(&[_]u8{0xff});

                spi_port.write(&ACMD41);
                for (0..10) |i| {
                    spi_port.read(&response_r1);
                    if ((response_r1[0] & 0x80) == 0) break;
                    if (i == 9) return SDError.InitError;
                }
                deactivate();

                switch (response_r1[0] & 0x7F) {
                    0 => break,
                    8 => return SDError.CrcError,
                    else => {},
                }
                if (j == 1999) return SDError.InitError;

                spi_port.write(&[_]u8{0xff});
                time.sleep_ms(1);
            }

            time.sleep_ms(1);

            // CMD58
            activate();
            spi_port.write(&CMD58);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            if ((response_r1[0] & 0x7F) == 8) return SDError.CrcError;
            spi_port.read(&response_r3);
            deactivate();

            // check SD or HC (XC) card.
            if ((response_r3[0] & 0x40) == 0) is_sd = true;

            time.sleep_ms(1);

            // fix access block size to 512
            // CMD16
            activate();
            spi_port.write(&CMD16);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            if ((response_r1[0] & 0x7F) == 8) return SDError.CrcError;

            deactivate();

            return true;
        }

        fn read_data(buffer: []u8) SDError!void {
            while (true) {
                spi_port.read(&response_r1);
                if (response_r1[0] == 0xfe) break; // data token
                if ((response_r1[0] & 0xf0) == 0) return SDError.ReadError;
            }
            spi_port.read(buffer);
            var crc_data: [2]u8 = undefined;
            spi_port.read(&crc_data);

            const crc = (@as(u16, crc_data[0]) << 8) | crc_data[1];
            if (crc != crc16(buffer)) return SDError.CrcError;
        }

        pub fn read_single(lba: usize, buffer: []u8) SDError!void {
            errdefer deactivate();

            activate();
            var cmd = CMD17;
            // conver LBA to address if SD card.
            const addr: usize = if (is_sd) lba * SECTOR_SIZE else lba;
            for (0..4) |i| {
                cmd[i + 1] = @truncate(addr >> @as(u5, @truncate(8 * (3 - i))));
            }

            send_with_crc(&cmd);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }
            if (response_r1[0] != 0) return SDError.ReadError;

            try read_data(buffer);

            deactivate();
        }

        pub fn read_multi(lba: usize, buffer: []u8) SDError!void {
            errdefer deactivate();

            const count: usize = buffer.len / SECTOR_SIZE;

            activate();
            var cmd = CMD18;
            // conver LBA to address if SD card.
            const addr: usize = if (is_sd) lba * SECTOR_SIZE else lba;
            for (0..4) |i| {
                cmd[i + 1] = @truncate(addr >> @as(u5, @truncate(8 * (3 - i))));
            }

            send_with_crc(&cmd);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                // 0x40?
                if (i == 9) return SDError.ReadError;
            }
            if (response_r1[0] != 0) return SDError.ReadError;

            for (0..count) |i| {
                try read_data(buffer[(SECTOR_SIZE * i)..(SECTOR_SIZE * (i + 1))]);

                // FIXME: for debug
                time.sleep_ms(1);
            }

            // stop reading
            spi_port.write(&CMD12);
            spi_port.read(&response_r1); // ignore first byte
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }

            deactivate();
        }

        fn write_data(token: u8, buffer: []const u8) SDError!void {
            const data_token = [_]u8{token};
            spi_port.write(&data_token);
            spi_port.write(buffer);

            const crc = crc16(buffer);
            const crc_data = [_]u8{ @as(u8, @truncate(crc >> 8)), @as(u8, @truncate(crc)) };
            spi_port.write(&crc_data);

            spi_port.read(&response_r1);
            switch (response_r1[0] & 0x1f) {
                0b00101 => {},
                0b01011 => return SDError.CrcError,
                else => return SDError.WriteError,
            }

            // wait while busy
            while (true) {
                spi_port.read(&response_r1);
                // if (response_r1[0] != 0) break;
                if (response_r1[0] == 0xff) break;
            }
        }

        pub fn write_single(lba: usize, buffer: []const u8) SDError!void {
            errdefer deactivate();

            activate();
            var cmd = CMD24;
            // conver LBA to address if SD card.
            const addr: usize = if (is_sd) lba * SECTOR_SIZE else lba;
            for (0..4) |i| {
                cmd[i + 1] = @truncate(addr >> @as(u5, @truncate(8 * (3 - i))));
            }

            send_with_crc(&cmd);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }
            if (response_r1[0] != 0) return SDError.WriteError;

            //send dummy space
            spi_port.write(&[_]u8{0xff});

            try write_data(0xfe, buffer);

            deactivate();
        }

        pub fn write_multi(lba: usize, buffer: []const u8) SDError!void {
            errdefer deactivate();

            const count: usize = buffer.len / SECTOR_SIZE;

            activate();

            // ACMD23 set pre-erased block number before writing
            spi_port.write(&CMD55);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            if (response_r1[0] != 0) return SDError.WriteError;

            spi_port.write(&[_]u8{0xff});

            var cmd23 = ACMD23;
            for (0..4) |i| {
                cmd23[i + 1] = @truncate(count >> @as(u5, @truncate(8 * (3 - i))));
            }

            send_with_crc(&cmd23);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            if (response_r1[0] != 0) return SDError.WriteError;

            spi_port.write(&[_]u8{0xff});

            // CMD25
            var cmd25 = CMD25;
            // conver LBA to address if SD card.
            const addr: usize = if (is_sd) lba * SECTOR_SIZE else lba;
            for (0..4) |i| {
                cmd25[i + 1] = @truncate(addr >> @as(u5, @truncate(8 * (3 - i))));
            }

            send_with_crc(&cmd25);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }
            if (response_r1[0] != 0) return SDError.WriteError;

            //send dummy space
            spi_port.write(&[_]u8{0xff});

            for (0..count) |i| {
                try write_data(0xfc, buffer[(SECTOR_SIZE * i)..(SECTOR_SIZE * (i + 1))]);

                // FIXME: for debug
                time.sleep_ms(1);
            }

            // stop write
            spi_port.write_read(&[_]u8{0xfd}, &response_r1);

            // wait while busy
            while (true) {
                spi_port.read(&response_r1);
                // if (response_r1[0] != 0) break;
                if (response_r1[0] == 0xff) break;
            }

            deactivate();
        }

        // methods for FatFs
        pub fn read(lba: usize, buffer: [*]u8, count: usize) SDError!void {
            try read_multi(lba, buffer[0..(SECTOR_SIZE * count)]);
        }

        pub fn write(lba: usize, buffer: [*]const u8, count: usize) SDError!void {
            try write_multi(lba, buffer[0..(SECTOR_SIZE * count)]);
        }

        pub fn read_cid() SDError!u128 {
            errdefer deactivate();

            var buffer: [16]u8 = undefined;

            // CMD10
            activate();
            spi_port.write(&CMD10);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }
            if ((response_r1[0] & 0x7F) == 8) return SDError.CrcError;

            try read_data(&buffer);

            deactivate();

            var CID: u128 = 0;
            for (0..buffer.len) |i| {
                CID += @as(u128, buffer[i]) << @as(u7, @truncate(8 * ((buffer.len - 1) - i)));
            }

            return CID;
        }

        pub fn read_csd() SDError!u128 {
            errdefer deactivate();

            var buffer: [16]u8 = undefined;

            // CMD9
            activate();
            spi_port.write(&CMD9);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }
            if ((response_r1[0] & 0x7F) == 8) return SDError.CrcError;

            try read_data(&buffer);

            deactivate();

            var CSD: u128 = 0;
            for (0..buffer.len) |i| {
                CSD += @as(u128, buffer[i]) << @as(u7, @truncate(8 * ((buffer.len - 1) - i)));
            }

            return CSD;
        }

        pub fn sector_size() SDError!u16 {
            const csd = try read_csd();
            const size: u16 = @as(u16, 1) <<| ((csd >> 80) & 0x0f);
            return size;
        }

        pub fn volume_size() SDError!u64 {
            const csd = try read_csd();

            // max u32 is 4GB
            var size: u64 = 0;
            switch (csd >> 126) {
                0b00 => {
                    // sector size
                    const READ_BL_LEN = (csd >> 80) & 0xf;
                    const SECT_SIZE = @as(u32, 1) <<| READ_BL_LEN;

                    const C_SIZE = (csd >> 62 & 0xfff);
                    const C_SIZE_MULT = (csd >> 47 & 0b111);
                    const MULT = @as(u32, 1) <<| (C_SIZE_MULT + 2);
                    const BLOCKNR = (C_SIZE + 1) * MULT;

                    size = @truncate(BLOCKNR * SECT_SIZE);
                },
                0b01 => {
                    // this makes max 2TB
                    const C_SIZE: u64 = @truncate((csd >> 48) & 0x3f_ffff);
                    size = (C_SIZE + 1) * SECTOR_SIZE * 1024;
                },
                else => return SDError.CardError,
            }
            return size;
        }
    };
}
