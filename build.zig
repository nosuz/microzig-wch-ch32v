const std = @import("std");
const Builder = std.build.Builder;
const LazyPath = std.build.LazyPath;

// the hardware support package should have microzig as a dependency
const microzig = @import("microzig");

pub const chips = @import("src/chips.zig");
pub const boards = @import("src/boards.zig");

const linkerscript_path = root() ++ "ch32v.ld";

pub const BuildOptions = struct {
    optimize: std.builtin.OptimizeMode,
};

pub const Ch32vExecutableOptions = struct {
    name: []const u8,
    source_file: LazyPath,
    optimize: std.builtin.OptimizeMode = .ReleaseSmall,

    board: boards.Board = boards.suzuduino_uno_v1,
};

pub fn addCh32vExecutable(
    builder: *Builder,
    opts: Ch32vExecutableOptions,
) *microzig.EmbeddedExecutable {
    var exe = microzig.addEmbeddedExecutable(builder, .{
        .name = opts.name,
        .source_file = opts.source_file,
        .backing = .{
            // .chip = chips.ch32v103c8,
            // .chip = chips.ch32v203c8,
            .board = opts.board.inner,
        },
        .optimize = opts.optimize,
        .linkerscript_source_file = .{ .path = linkerscript_path },
    });
    exe.addObjectFile(.{ .path = "libinit.a" });
    return exe;
}

pub fn build(b: *Builder) !void {
    const optimize = b.standardOptimizeOption(.{});

    // const args_dep = b.dependency("args", .{});
    // const args_mod = args_dep.module("args");

    var examples = Examples.init(b, optimize);
    examples.install(b);
}

fn root() []const u8 {
    return comptime (std.fs.path.dirname(@src().file) orelse ".") ++ "/";
}

pub const Examples = struct {
    blinky: *microzig.EmbeddedExecutable,
    blinky2: *microzig.EmbeddedExecutable,
    blinky_sleep: *microzig.EmbeddedExecutable,
    blinky_clocks: *microzig.EmbeddedExecutable,
    serial: *microzig.EmbeddedExecutable,
    serial_log: *microzig.EmbeddedExecutable,
    timer_interrupt: *microzig.EmbeddedExecutable,

    pub fn init(b: *Builder, optimize: std.builtin.OptimizeMode) Examples {
        var ret: Examples = undefined;
        inline for (@typeInfo(Examples).Struct.fields) |field| {
            const path = comptime root() ++ "examples/" ++ field.name ++ ".zig";

            @field(ret, field.name) = addCh32vExecutable(b, .{
                .name = field.name,
                .source_file = .{ .path = path },
                .optimize = optimize,
            });
        }

        return ret;
    }

    pub fn install(examples: *Examples, b: *Builder) void {
        inline for (@typeInfo(Examples).Struct.fields) |field| {
            b.installArtifact(@field(examples, field.name).inner);
        }
    }
};
