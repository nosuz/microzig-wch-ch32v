const std = @import("std");
const microzig = @import("microzig");

fn root_dir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

const hal_path = std.fmt.comptimePrint("{s}/hal.zig", .{root_dir()});

pub const ch32v103c8 = microzig.Chip{
    .name = "CH32V103xx",
    .source = .{ .path = std.fmt.comptimePrint("{s}/chips/CH32V103xx.zig", .{root_dir()}) },
    .hal = .{ .path = hal_path },
    .cpu = microzig.cpus.riscv32_imac,
    .memory_regions = &.{
        .{ .offset = 0x0800_0000, .length = 64 * 1024, .kind = .flash },
        .{ .offset = 0x2000_0000, .length = 20 * 1024, .kind = .ram },
    },
};

pub const ch32v203c8 = microzig.Chip{
    .name = "CH32V20xxx",
    .source = .{ .path = std.fmt.comptimePrint("{s}/chips/CH32V20xxx.zig", .{root_dir()}) },
    .hal = .{ .path = hal_path },
    .cpu = microzig.cpus.riscv32_imac,
    .memory_regions = &.{
        .{ .offset = 0x0800_0000, .length = 64 * 1024, .kind = .flash },
        .{ .offset = 0x2000_0000, .length = 20 * 1024, .kind = .ram },
    },
};
