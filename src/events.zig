const std = @import("std");
const features = @import("features.zig");

pub fn emit(comptime ev: @Type(.EnumLiteral), args: anytype) void {
    inline for (@typeInfo(features).Struct.decls) |decl| {
        const feature = &@field(features, decl.name);
        const Feature = @TypeOf(feature.*);
        const handlerName = "handle" ++ @tagName(ev);
        if (@hasDecl(Feature, handlerName)) {
            @call(.auto, @field(Feature, handlerName), .{feature} ++ args) catch |err| {
                std.log.err("Event handler for {} errored: {}", .{ decl.name, err });
            };
        }
    }
}
