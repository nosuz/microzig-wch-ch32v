const std = @import("std");
const microzig = @import("microzig");

fn root_dir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const svd_ch32v103_path = std.fmt.comptimePrint("{s}/chips/CH32V103xx.zig", .{root_dir()});
const svd_ch32v203_path = std.fmt.comptimePrint("{s}/chips/CH32V20xxx.zig", .{root_dir()});

const hal_ch32v103_path = std.fmt.comptimePrint("{s}/hal_ch32v103.zig", .{root_dir()});
const hal_ch32v203_path = std.fmt.comptimePrint("{s}/hal_ch32v203.zig", .{root_dir()});

pub const ch32v103c8 = microzig.Chip{
    .name = "CH32V103xx", // device name in SVD
    .source = .{ .path = svd_ch32v103_path },
    .hal = .{ .path = hal_ch32v103_path },
    .cpu = microzig.cpus.riscv32_imac,
    .memory_regions = &.{
        .{ .offset = 0x0800_0000, .length = 64 * 1024, .kind = .flash },
        .{ .offset = 0x2000_0000, .length = 20 * 1024, .kind = .ram },
    },
};

pub const ch32v203c8 = microzig.Chip{
    .name = "CH32V20xxx", // device name in SVD
    .source = .{ .path = svd_ch32v203_path },
    .hal = .{ .path = hal_ch32v203_path },
    .cpu = microzig.cpus.riscv32_imac,
    .memory_regions = &.{
        .{ .offset = 0x0800_0000, .length = 64 * 1024, .kind = .flash },
        .{ .offset = 0x2000_0000, .length = 20 * 1024, .kind = .ram },
    },
};

pub const ch32v203k8 = microzig.Chip{
    .name = "CH32V20xxx", // device name in SVD
    .source = .{ .path = svd_ch32v203_path },
    .hal = .{ .path = hal_ch32v203_path },
    .cpu = microzig.cpus.riscv32_imac,
    .memory_regions = &.{
        .{ .offset = 0x0800_0000, .length = 64 * 1024, .kind = .flash },
        .{ .offset = 0x2000_0000, .length = 20 * 1024, .kind = .ram },
    },
};
