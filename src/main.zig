const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const image = @import("image.zig");
const ui = @import("ui.zig");
const Scene1 = @import("scene1.zig");

const KB = 1024;
var heap: [24 * KB]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(&heap);
var prng: std.rand.DefaultPrng = undefined;

var scene: ?Scene1 = null;

const verbose = false;

export fn start() void {
    if (verbose) w4.trace("[START] begin");

    // w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;

    prng = std.rand.DefaultPrng.init(0);

    if (verbose) w4.trace("[START] end");
}

export fn update() void {
    if (verbose) w4.trace("[UPDATE] begin");

    if (scene) |*scn| {
        scn.update();
    } else {
        w4.DRAW_COLORS.* = 0x04;
        image.title_bmp.blit(zow4.geometry.Vec2{ 0, 0 }, .{ .bpp = .b1 });
        w4.DRAW_COLORS.* = 0x01;
        w4.oval(12, 145, 8, 10);
        w4.oval(128, 145, 8, 10);
        w4.rect(16, 145, 116, 10);
        w4.DRAW_COLORS.* = 0x14;
        w4.text("Click to Start", 16, 148);
        if (zow4.input.mouser(.left)) {
            scene = Scene1.init(fba.allocator(), prng.random()) catch |e| {
                switch (e) {
                    error.OutOfMemory => zow4.mem.report_memory_usage(fba),
                }
                zow4.panic("Couldn't start scene1");
                unreachable;
            };
        }
        zow4.input.update();
    }

    if (verbose) w4.trace("[UPDATE] end");
}

test "" {}
