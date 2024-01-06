const std = @import("std");
const w = std.os.windows;

export const NvOptimusEnablement: u32 = 1;
export const AmdPowerXpressRequestHighPerformance: u32 = 1;

const LauncherMain = *const fn (?w.HINSTANCE, ?w.HINSTANCE, ?w.LPSTR, c_int) callconv(.C) c_int;

extern "kernel32" fn SetDllDirectoryW(lpPathName: [*:0]const u16) callconv(w.WINAPI) w.BOOL;

pub fn setDllDirectory(path: []const u8) !void {
    const path_w = try w.sliceToPrefixedFileW(null, path);
    if (SetDllDirectoryW(path_w.span().ptr) == 0) {
        return w.unexpectedError(w.kernel32.GetLastError());
    }
}

pub fn main() !void {
    _ = try setDllDirectory("bin");
    var modDll = try std.DynLib.open("gluon.dll");
    const gluonInit = modDll.lookup(*const fn () callconv(.C) bool, "gluonInit").?;

    if (!gluonInit()) return;

    var launcherDll = try std.DynLib.open("bin/launcher.dll");
    const launcherMain = launcherDll.lookup(LauncherMain, "LauncherMain").?;
    _ = launcherMain(null, null, null, 0);
}
