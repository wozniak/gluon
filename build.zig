const std = @import("std");
const LazyPath = std.build.LazyPath;

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // TODO: write this functionality ourselves
    const sstlib = b.addStaticLibrary(.{ .target = target, .name = "sst", .optimize = optimize });
    sstlib.addIncludePath(LazyPath.relative("3p/sst"));
    sstlib.addCSourceFiles(.{ .files = &.{
        "3p/sst/x86.c",
    } });

    // no idea for a better way to do this
    const tier0_genlib = b.addSystemCommand(&.{ "zig", "dlltool", "-mi386", "-ddef/tier0.def", "-ltier0.lib" });

    // launcher
    const exe = b.addExecutable(.{
        .name = "gluon",
        .root_source_file = .{ .path = "src/main.zig" },
        .target = target,
        .optimize = optimize,
    });
    b.installArtifact(exe);

    const dll = b.addSharedLibrary(.{
        .name = "libgluon",
        .root_source_file = .{ .path = "src/gluon.zig" },
        .target = target,
        .optimize = optimize,
    });
    dll.linkLibC();
    dll.linkLibrary(sstlib);

    dll.addObjectFile(.{ .path = "tier0.lib" });
    dll.step.dependOn(&tier0_genlib.step);

    dll.addAfterIncludePath(.{ .path = "3p/sst" });
    b.installArtifact(dll);
}
