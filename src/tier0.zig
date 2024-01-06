pub const SpewType = enum(c_int) {
    message = 0,
    warning,
    assert,
    err,
    log,
};

pub const SpewRetval = enum(c_int) {
    debugger = 0,
    cont,
    abort,
};

pub const Color = extern struct {
    r: u8,
    g: u8,
    b: u8,
};

pub const SpewFn = fn (SpewType, [*:0]const u8) callconv(.C) SpewRetval;

pub extern fn SpewOutputFunc(func: *const SpewFn) void;
pub extern fn GetSpewOutputFunc() *const SpewFn;
// pub extern fn GetSpewOutputLevel() callconv(.C) c_int;
// pub extern fn GetSpewOutputColor() callconv(.C) *const Color;
