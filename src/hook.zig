const builtin = @import("builtin");
const std = @import("std");
const w = std.os.windows;
const x86 = @cImport(@cInclude("x86.h"));

extern "kernel32" fn FlushInstructionCache(
    hProcess: w.HANDLE,
    lpBaseAddress: ?w.LPCVOID,
    dwSize: w.SIZE_T,
) callconv(w.WINAPI) w.BOOL;

extern "kernel32" fn GetCurrentProcess() callconv(w.WINAPI) w.HANDLE;

fn flushCache() void {
    FlushInstructionCache(GetCurrentProcess(), null, 0);
}

fn ptrOffset(ptr: ?[*]u8, offset: isize) [*]u8 {
    return @ptrFromInt(@intFromPtr(ptr) +% @as(usize, @bitCast(offset)));
}

fn memLoad(comptime T: type, ptr: [*]u8) T {
    return @as(*align(1) T, @ptrCast(ptr)).*;
}

/// returns the slice of the page the passed pointer points to
fn memPage(ptr: *anyopaque) []align(std.mem.page_size) u8 {
    const page: [*]align(std.mem.page_size) u8 =
        @ptrFromInt(@intFromPtr(ptr) & ~@as(usize, std.mem.page_size - 1));
    return page[0..std.mem.page_size];
}

var trampolines: [4096]u8 align(4096) = undefined;
var trampoline: []u8 = trampolines[0..];

var is_init = false;
pub fn hookInline(func_: *const anyopaque, target: *const anyopaque) !*const anyopaque {
    if (!is_init) {
        try std.os.mprotect(&trampolines, 0b111);
        is_init = true;
    }
    const log = std.log.scoped(.hookInline);
    var func: [*]u8 = @ptrCast(@constCast(func_));
    // if we hit a thunk, follow it
    log.debug("hooking {x}, trampoline at {x}", .{@intFromPtr(func), @intFromPtr(trampoline.ptr)});
    while (true) {
        if (func[0] == x86.X86_JMPIW) {
            const offset: isize = memLoad(i32, func + 1);
            func = ptrOffset(func + 5, offset);
            log.debug("hit THUNK: E8 jmp {x}", .{@intFromPtr(func)});
        } else if (func[0] == x86.X86_MISCMW and func[1] & 0x38 == 4 << 3) {
            // on x86 ff /4 is an absolute address so we can just hook it lol
            // but on x64 it's rip-relative
            if (builtin.cpu.arch == .x86) {
                break;
            } else if (builtin.cpu.arch == .x86_64) {
                func = ptrOffset(func + 6, memLoad(i32, func + 2));
            } else unreachable;
            log.debug("hit THUNK: FF /4 jmp {x}", .{@intFromPtr(func)});
        } else break;
    }
    // find inst boundry for at least 5 bytes
    var len: usize = 0;
    var ilen: i32 = 0;
    while (true) {
        ilen = x86.x86_len(func + len);
        if (ilen == -1) {
            return error.UnrecognizedInstruction;
        }
        len += @intCast(ilen);
        if (len >= 5) break;
    }
    // make func writable
    try std.os.mprotect(memPage(func), 0b111);
    defer trampoline = trampoline[len + 6..];
    // copy prologue
    @memcpy(trampoline[0..len], func);
    // set jmp to continuation
    trampoline[len] = x86.X86_JMPIW;
    var diff = @intFromPtr(func) -% @intFromPtr(trampoline.ptr + 5);
    @memcpy(trampoline.ptr + len + 1, std.mem.asBytes(&diff));
    // set jmp to hook
    func[0] = x86.X86_JMPIW;
    diff = @intFromPtr(target) -% @intFromPtr(func + 5);
    @memcpy(func + 1, std.mem.asBytes(&diff));
    return @ptrCast(trampoline.ptr);
}
