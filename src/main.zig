const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const image = @import("image.zig");
const ui = @import("ui.zig");
const SceneTitle = @import("scene_title.zig");
var scene_title: SceneTitle = undefined;
const Scene1 = @import("scene1.zig");
var scene1: Scene1 = undefined;

const KB = 1024;
var heap: [24 * KB]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(&heap);
var prng: std.rand.DefaultPrng = undefined;

const Scene = enum { Title, Scene1 };
var scene: Scene = .Title;

const verbose = false;

pub const Runner = struct {
    alloc: std.mem.Allocator,
    rand: std.rand.Random,

    pub fn to_scene(next_scene: Scene) void {
        scene = next_scene;
    }
};

var runner: Runner = .{
    .alloc = fba.allocator(),
    .rand = undefined,
};

export fn start() void {
    if (verbose) w4.trace("[START] begin");

    // w4.SYSTEM_FLAGS.* = w4.SYSTEM_PRESERVE_FRAMEBUFFER;

    prng = std.rand.DefaultPrng.init(0);
    runner.rand = prng.random();

    scene_title = SceneTitle.init(runner) catch |e| {
        switch (e) {
            error.OutOfMemory => zow4.mem.report_memory_usage(fba),
        }
        zow4.panic("Couldn't start scene1");
        unreachable;
    };
    scene1 = Scene1.init(runner) catch |e| {
        switch (e) {
            error.OutOfMemory => zow4.mem.report_memory_usage(fba),
        }
        zow4.panic("Couldn't start scene1");
        unreachable;
    };

    if (verbose) w4.trace("[START] end");
}

export fn update() void {
    if (verbose) w4.trace("[UPDATE] begin");

    switch (scene) {
        .Title => {
            scene_title.update();
        },
        .Scene1 => {
            scene1.update();
        },
    }

    // if (scene) |*scn| {
    //     scn.update();
    // } else {
    //     w4.DRAW_COLORS.* = 0x04;
    //     image.title_bmp.blit(zow4.geometry.Vec2{ 0, 0 }, .{ .bpp = .b1 });
    //     w4.DRAW_COLORS.* = 0x01;
    //     w4.oval(12, 145, 8, 10);
    //     w4.oval(128, 145, 8, 10);
    //     w4.rect(16, 145, 116, 10);
    //     w4.DRAW_COLORS.* = 0x14;
    //     w4.text("Click to Start", 16, 148);
    //     if (zow4.input.mouser(.left)) {
    //         scene = Scene1.init(runner) catch |e| {
    //             switch (e) {
    //                 error.OutOfMemory => zow4.mem.report_memory_usage(fba),
    //             }
    //             zow4.panic("Couldn't start scene1");
    //             unreachable;
    //         };
    //     }
    // }
    zow4.input.update();

    if (verbose) w4.trace("[UPDATE] end");
}

// pub fn Scene(comptime T: anytype) ScenePtrs {
//     if (@hasField(T, "start")) {
//         @compileLog("Scene requires start function", T);
//     }
//     if (@hasField(T, "update")) {
//         @compileLog("Scene requires update function", T);
//     }
//     if (@hasField(T, "end")) {
//         @compileLog("Scene requires end function", T);
//     }
//     return .{
//         .start = @field(T, "start"),
//         .update = @field(T, "update"),
//         .end = @field(T, "end"),
//     };
// }

// pub const ScenePtrs = struct {
//     update: fn (Runner) void,
// };

test "" {}
