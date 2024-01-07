const std = @import("std");
const events = @import("../events.zig");
const hook = @import("../hook.zig");
const tier0 = @import("../tier0.zig");
const features = @import("../features.zig");

const log = std.log.scoped(.Init);
const Self = @This();
const w = std.os.windows;

// Sys_LoadModule calls LoadLibraryExA
const LoadLibraryFn = *const fn (w.LPCSTR, ?w.HANDLE, w.DWORD) callconv(w.WINAPI) ?w.HMODULE;

pub const description = "core hooks/logging";

defaultSpewFunc: *const tier0.SpewFn = undefined,
oLoadLibrary: LoadLibraryFn = undefined,

fn spewOutput(spew_type: tier0.SpewType, msg_: [*:0]const u8) callconv(.C) tier0.SpewRetval {
    const conlog = std.log.scoped(.con);
    var msg: []const u8 = std.mem.span(msg_);
    // cut off the \n if it exists (std.log inserts one for us)
    if (msg[msg.len - 1] == '\n') msg.len -= 1;
    switch (spew_type) {
        .message, .log => conlog.info("{s}", .{msg}),
        .warning, .assert => conlog.warn("{s}", .{msg}),
        .err => std.log.err("{s}", .{msg}),
    }
    return features.core.defaultSpewFunc(spew_type, msg_);
}

fn hkLoadLibrary(
    path: w.LPCSTR,
    file: ?w.HANDLE,
    flags: w.DWORD,
) callconv(w.WINAPI) ?w.HMODULE {
    const lib = features.core.oLoadLibrary(path, file, flags);
    const basename = std.fs.path.basename(std.mem.span(path));
    events.emit(.DllLoad, .{basename});
    return lib;
}

pub fn earlyInit(self: *Self) !void {
    var kernel32 = try std.DynLib.open("kernel32.dll");
    const loadLibrary = kernel32.lookup(LoadLibraryFn, "LoadLibraryExA").?;
    self.oLoadLibrary = @ptrCast(try hook.hookInline(loadLibrary, &hkLoadLibrary));
}

pub fn handleDllLoad(self: *Self, dllname: []const u8) !void {
    std.log.scoped(.DllLoad).info("{s}", .{dllname});
    // wait until gameui.dll loads to set the spew func since that is
    // the last thing to load
    if (std.mem.eql(u8, dllname, "gameui.dll")) {
        self.defaultSpewFunc = tier0.GetSpewOutputFunc();
        tier0.SpewOutputFunc(&spewOutput);
    }
}
