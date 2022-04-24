const w4 = @import("wasm4");
const zow4 = @import("zow4");
const image = @import("image.zig");

const Runner = @import("main.zig").Runner;

runner: Runner,
background: zow4.draw.Blit,

pub fn init(runner: Runner) !@This() {
    return @This(){
        .runner = runner,
        .background = .{ .bmp = &image.title_bmp, .style = 0x04},
    };
}

pub fn deinit() void {}

pub fn update(this: *@This()) void {
    w4.DRAW_COLORS.* = 0x04;
    this.background.blit(zow4.geometry.Vec2{ 0, 0 });
    w4.DRAW_COLORS.* = 0x01;
    w4.oval(12, 145, 8, 10);
    w4.oval(128, 145, 8, 10);
    w4.rect(16, 145, 116, 10);
    w4.DRAW_COLORS.* = 0x14;
    w4.text("Click to Start", 16, 148);
    if (zow4.input.mouser(.left)) {
        Runner.to_scene(.Scene1);
    }
}
