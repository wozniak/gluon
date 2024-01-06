const std = @import("std");
const w = std.os.windows;

const ev = @import("events.zig");
const features = @import("features.zig");

export fn gluonInit() callconv(.C) bool {
    init() catch |err| {
        std.log.err("{}", .{err});
        return false;
    };
    return true;
}

fn init() !void {
    // @breakpoint();
    // early init features
    inline for (@typeInfo(features).Struct.decls) |decl| {
        const T = @field(features, decl.name);
        if (@hasDecl(T, "earlyInit")) {
            if (@field(T, "earlyInit")()) |_| {
                std.log.info("Early init: {s}", .{@field(T, "DESCRIPTION")});
            } else |e| {
                std.log.err("Early init FAILED: {s}: {}", .{ @field(T, "DESCRIPTION"), e });
            }
        }
    }
}
