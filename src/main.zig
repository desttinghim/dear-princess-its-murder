const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

export fn start() void {
    w4.PALETTE.* = .{
        0xFF_FF_FF,
        0xFF_FF_FF,
        0xFF_FF_FF,
        0x00_00_00,
    };
}

export fn update() void {
    w4.DRAW_COLORS.* = 0x04;
    w4.text("Dear Princess -\nIt's Murder She Wrote", 0, 0);
}

test "" {}
