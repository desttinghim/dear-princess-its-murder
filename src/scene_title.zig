const w4 = @import("wasm4");
const zow4 = @import("zow4");
const image = @import("image.zig");
const ui = @import("ui.zig");

const Runner = @import("main.zig").Runner;

runner: Runner,
background: zow4.draw.Blit,
ctx: ui.Context,

pub fn init(runner: Runner) !@This() {
    var this = @This(){
        .runner = runner,
        .background = .{ .bmp = &image.title_bmp, .style = 0x04 },
        .ctx = try ui.init(runner.alloc),
    };

    const Node = ui.Context.Node;
    const pos = try this.ctx.insert(null, Node.anchor(.{0,0,100,0}, .{2, 2, -2, 40}));
    {
        const center = try this.ctx.insert(pos, Node.center().hasBackground(true));
        _ = try this.ctx.insert(center, Node.relative().dataValue(.{.Label = " Dear Princess\n\n It's Murder\n  She Wrote"}));
    }

    const pos2 = try this.ctx.insert(null, Node.anchor(.{0,100,100,100}, .{16, -14, -16, -2}));
    {
        const center = try this.ctx.insert(pos2, Node.center().hasBackground(true));
        _ = try this.ctx.insert(center, Node.relative().dataValue(.{.Label = "Click To Start"}));
    }

    this.ctx.layout(.{0,0,160,160});

    return this;
}

pub fn deinit() void {}

pub fn update(this: *@This()) void {
    w4.DRAW_COLORS.* = 0x04;
    this.background.blit(zow4.geometry.Vec2{ 0, 0 });
    this.ctx.paint();
    // w4.DRAW_COLORS.* = 0x04;
    // w4.text("Dear Princess", 80 - (13 * 8) / 2 + 1, 17);
    // w4.text("Dear Princess", 80 - (13 * 8) / 2 - 1, 16);
    // w4.DRAW_COLORS.* = 0x01;
    // w4.text("Dear Princess", 80 - (13 * 8) / 2, 16);
    // w4.DRAW_COLORS.* = 0x01;
    // w4.oval(12, 145, 8, 10);
    // w4.oval(128, 145, 8, 10);
    // w4.rect(16, 145, 116, 10);
    // w4.DRAW_COLORS.* = 0x14;
    // w4.text("Click to Start", 16, 148);
    if (zow4.input.mouser(.left)) {
        Runner.to_scene(.Scene1);
    }
}
