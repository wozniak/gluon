const std = @import("std");
const w = std.os.windows;

const ev = @import("events.zig");
const features = @import("features.zig");

export fn gluonInit() bool {
    init() catch |err| {
        std.log.err("{}", .{err});
        return false;
    };
    return true;
}

fn init() !void {
    // early init features
    inline for (@typeInfo(features).Struct.decls) |decl| {
        const feature = &@field(features, decl.name);
        const Feature = @TypeOf(feature.*);
        if (@hasDecl(Feature, "earlyInit")) {
            if (feature.earlyInit()) |_| {
                std.log.info("Early init: {s}", .{Feature.description});
            } else |e| {
                std.log.err("Early init FAILED: {s}: {}", .{ Feature.description, e });
            }
        }
    }
}
