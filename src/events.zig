const std = @import("std");
const features = @import("features.zig");

pub fn emit(comptime ev: @Type(.EnumLiteral), args: anytype) void {
    // call all the event handlers
    inline for (@typeInfo(features).Struct.decls) |decl| {
        const T = @field(features, decl.name);
        if (@hasDecl(T, "handleEvent")) {
            @field(T, "handleEvent")(ev, args) catch |err| {
                std.log.err("Event handler for {} errored: {}", .{ decl.name, err });
            };
        }
    }
}
