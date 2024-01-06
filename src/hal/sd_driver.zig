const microzig = @import("microzig");

const ch32v = microzig.hal;
const spi = ch32v.spi;
const time = ch32v.time;

const SECTOR_SIZE = 512;

const SDError = error{
    InitError,
    ReadError,
    WriteError,
    CardError,
};

const CMD0 = [_]u8{ 0b01_000000 + 0, 0, 0, 0, 0, 0b1001010_1 }; // need correct CRC7
const CMD8 = [_]u8{ 0x40 + 8, 0, 0, 1, 0xAA, 0x87 }; // need correct CRC7
// https://userweb.alles.or.jp/chunichidenko/sdif27.html
const CMD9 = [_]u8{ 0x40 + 9, 0, 0, 0, 0, 1 }; // ask CSD; recieve data packet 16 bytes + CRC
const CMD10 = [_]u8{ 0x40 + 10, 0, 0, 0, 0, 1 }; // ask CSD; recieve data packet 16 bytes + CRC
const CMD16 = [_]u8{ 0x40 + 16, 0, 0, 2, 0, 1 }; // set block length to 512 bytes for SDCD not for SDHC and SDXC
const CMD58 = [_]u8{ 0x40 + 58, 0, 0, 0, 0, 1 };
// const CMD59 = [_]u8{ 0x40 + 59, 0, 0, 0, 0, 1 }; // turn off CRC; off by default

// Pre-command for ACMD
const CMD55 = [_]u8{ 0x40 + 55, 0, 0, 0, 0, 1 };
// Table 7-4 : Application Specific Commands used/reserved by SD Memory Card - SPI Mode
const ACMD41 = [_]u8{ 0x40 + 41, 0b0100_0000, 0, 0, 0, 1 };

const CMD17 = [_]u8{ 0x40 + 17, 0, 0, 0, 0, 1 }; // single read
const CMD18 = [_]u8{ 0x40 + 18, 0, 0, 0, 0, 1 }; // multiple read
const CMD12 = [_]u8{ 0x40 + 12, 0, 0, 0, 0, 1 }; // stop read

const CMD24 = [_]u8{ 0x40 + 24, 0, 0, 0, 0, 1 }; // single write
const CMD25 = [_]u8{ 0x40 + 25, 0, 0, 0, 0, 1 }; // multiple write
// const CMD13 = [_]u8{ 0x40 + 13, 0, 0, 0, 0, 1 }; // get status

pub fn SD_DRIVER(comptime spi_port: anytype, comptime cs_pin: anytype) type {
    return struct {
        var response_r1: [1]u8 = undefined;
        var response_r3: [4]u8 = undefined;
        var response_r7: [4]u8 = undefined;

        pub fn init() SDError!void {
            time.sleep_ms(1);
            // _ = self;

            // send dumy clock
            cs_pin.put(1);
            // spi_port.write(&([_]u8{0xff} ** 10)); // loop is smaller
            for (0..10) |_| {
                spi_port.write(&[1]u8{0xff});
            }
            spi_port.wait_complete();

            time.sleep_ms(1);

            cs_pin.put(0);
            spi_port.write(&CMD0);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }

            time.sleep_ms(1);

            spi_port.write(&CMD8);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            spi_port.read(&response_r7);

            time.sleep_ms(1);

            // FIXME: sometimes fail to init
            // https://stackoverflow.com/questions/76002524/trying-to-initialize-sdhc-card-using-spi-after-sending-cmd55-in-preparation-for
            // https://stackoverflow.com/questions/2365897/initializing-sd-card-in-spi-issues
            // https://stackoverflow.com/questions/69565103/spi-sd-card-32gb-never-passes-cmd55-acmd41-initalization-step
            for (0..2000) |j| {
                spi_port.write(&CMD55);
                for (0..10) |i| {
                    spi_port.read(&response_r1);
                    if ((response_r1[0] & 0x80) == 0) break;
                    if (i == 9) return SDError.InitError;
                }

                spi_port.write(&ACMD41);
                for (0..10) |i| {
                    spi_port.read(&response_r1);
                    if ((response_r1[0] & 0x80) == 0) break;
                    if (i == 9) return SDError.InitError;
                }
                if (response_r1[0] == 0) break;
                if (j == 1999) return SDError.InitError;
                time.sleep_ms(1);
            }

            time.sleep_ms(1);

            spi_port.write(&CMD58);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.InitError;
            }
            spi_port.read(&response_r3);

            spi_port.wait_complete();
            cs_pin.put(1);
            // send dummy
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();
        }

        pub fn cleanup() void {
            spi_port.wait_complete();
            cs_pin.put(1);
            // send dummy
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();
        }

        fn read_data(buffer: []u8) SDError!void {
            while (true) {
                spi_port.read(&response_r1);
                if (response_r1[0] == 0xfe) break; // data token
                if ((response_r1[0] & 0xf0) == 0) return SDError.ReadError;
            }
            spi_port.read(buffer);
            var crc: [2]u8 = undefined;
            spi_port.read(&crc);
        }

        pub fn read_single(addr: usize, buffer: []u8) SDError!void {
            cs_pin.put(0);

            var cmd = CMD17;
            for (0..4) |i| {
                cmd[i + 1] = @truncate(addr >> @as(u5, @truncate(8 * (3 - i))));
            }

            spi_port.write(&cmd);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }

            try read_data(buffer);

            spi_port.wait_complete();
            cs_pin.put(1);
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();
        }

        pub fn read_multi(addr: usize, buffer: []u8) SDError!void {
            const count: usize = buffer.len / SECTOR_SIZE;

            cs_pin.put(0);

            var cmd = CMD18;
            for (0..4) |i| {
                cmd[i + 1] = @truncate(addr >> @as(u5, @truncate(8 * (3 - i))));
            }

            spi_port.write(&cmd);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }

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

            spi_port.wait_complete();
            cs_pin.put(1);
            // send dummy
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();
        }

        fn write_data(token: u8, buffer: []u8) SDError!void {
            const data_token = [_]u8{token};
            spi_port.write(&data_token);
            spi_port.write(buffer);
            const crc = [_]u8{ 0, 0 };
            spi_port.write(&crc);

            spi_port.read(&response_r1);
            if ((response_r1[0] & 0x1f) != 0b00101) return SDError.WriteError;

            // wait while busy
            while (true) {
                spi_port.read(&response_r1);
                // if (response_r1[0] != 0) break;
                if (response_r1[0] == 0xff) break;
            }
        }

        pub fn write_single(addr: usize, buffer: []u8) SDError!void {
            cs_pin.put(0);

            var cmd = CMD24;
            for (0..4) |i| {
                cmd[i + 1] = @truncate(addr >> @as(u5, @truncate(8 * (3 - i))));
            }

            spi_port.write(&cmd);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }
            //send dummy space
            spi_port.write(&[_]u8{0xff});

            try write_data(0xfe, buffer);

            spi_port.wait_complete();
            cs_pin.put(1);
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();
        }

        pub fn write_multi(addr: usize, buffer: []u8) SDError!void {
            const count: usize = buffer.len / SECTOR_SIZE;

            cs_pin.put(0);

            var cmd = CMD25;
            for (0..4) |i| {
                cmd[i + 1] = @truncate(addr >> @as(u5, @truncate(8 * (3 - i))));
            }

            spi_port.write(&cmd);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }

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

            spi_port.wait_complete();
            cs_pin.put(1);
            // send dummy
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();
        }

        pub fn read_cid() SDError!u128 {
            var buffer: [16]u8 = undefined;

            cs_pin.put(0);

            spi_port.write(&CMD10);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }

            try read_data(&buffer);

            spi_port.wait_complete();
            cs_pin.put(1);
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();

            var CID: u128 = 0;
            for (0..buffer.len) |i| {
                CID += @as(u128, buffer[i]) << @as(u7, @truncate(8 * ((buffer.len - 1) - i)));
            }

            return CID;
        }

        pub fn read_csd() SDError!u128 {
            var buffer: [16]u8 = undefined;

            cs_pin.put(0);

            spi_port.write(&CMD9);
            for (0..10) |i| {
                spi_port.read(&response_r1);
                if ((response_r1[0] & 0x80) == 0) break;
                if (i == 9) return SDError.ReadError;
            }

            try read_data(&buffer);

            spi_port.wait_complete();
            cs_pin.put(1);
            spi_port.write(&[_]u8{0xff});
            spi_port.wait_complete();

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
                    size = (C_SIZE + 1) * 512 * 1024;
                },
                else => return SDError.CardError,
            }
            return size;
        }

        pub fn fix_block_len512() SDError!void {
            const size = try sector_size();

            if (size != 512) {
                cs_pin.put(0);

                spi_port.write(&CMD16);
                for (0..10) |i| {
                    spi_port.read(&response_r1);
                    if ((response_r1[0] & 0x80) == 0) break;
                    if (i == 9) return SDError.ReadError;
                }

                spi_port.wait_complete();
                cs_pin.put(1);
                spi_port.write(&[_]u8{0xff});
                spi_port.wait_complete();
            }
        }
    };
}
