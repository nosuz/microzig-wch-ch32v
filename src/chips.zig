const std = @import("std");
const microzig = @import("microzig");

const Chip = microzig.Chip;
const MemoryRegion = microzig.MemoryRegion;

fn root_dir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

pub const ch32v103c8 = Chip.from_standard_paths(root_dir(), .{
    .name = "CH32V103xx",
    .cpu = microzig.cpus.riscv32_imac,
    .memory_regions = &.{
        MemoryRegion{ .offset = 0x0800_0000, .length = 64 * 1024, .kind = .flash },
        MemoryRegion{ .offset = 0x2000_0000, .length = 20 * 1024, .kind = .ram },
    },
});

pub const ch32v203c8 = Chip.from_standard_paths(root_dir(), .{
    .name = "CH32V20xxx",
    .cpu = microzig.cpus.riscv32_imac,
    .memory_regions = &.{
        MemoryRegion{ .offset = 0x0800_0000, .length = 64 * 1024, .kind = .flash },
        MemoryRegion{ .offset = 0x2000_0000, .length = 20 * 1024, .kind = .ram },
    },
});
