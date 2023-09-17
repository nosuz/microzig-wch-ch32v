const std = @import("std");
const microzig = @import("microzig");
const chips = @import("chips.zig");

fn root_dir() []const u8 {
    return std.fs.path.dirname(@src().file) orelse ".";
}

fn board_path(comptime path: []const u8) std.Build.LazyPath {
    return .{
        .path = std.fmt.comptimePrint("{s}/boards/{s}", .{ root_dir(), path }),
    };
}

pub const Board = struct {
    inner: microzig.Board,
};

// https://github.com/verylowfreq/suzuduino-uno-v1
pub const suzuduino_uno_v1 = Board{
    .inner = .{
        .name = "Suzuduino UNO",
        .source = board_path("suzuduino_uno_v1.zig"),
        .chip = chips.ch32v203k8,
    },
};
