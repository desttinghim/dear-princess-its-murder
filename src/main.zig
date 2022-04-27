const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const image = @import("image.zig");
const document = @import("document.zig");
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
var scene: Scene = .Scene1;

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

    prng = std.rand.DefaultPrng.init(0);
    runner.rand = prng.random();

    document.Highlight.init(fba.allocator()) catch |e| {
        switch (e) {
            error.OutOfMemory => zow4.mem.report_memory_usage(fba),
        }
        zow4.panic("Couldn't start scene1");
    };

    scene_title = SceneTitle.init(runner) catch |e| {
        switch (e) {
            error.OutOfMemory => zow4.mem.report_memory_usage(fba),
        }
        zow4.panic("Couldn't start scene1");
    };
    scene1 = Scene1.init(runner) catch |e| {
        switch (e) {
            error.OutOfMemory => zow4.mem.report_memory_usage(fba),
        }
        zow4.panic("Couldn't start scene1");
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
            scene1.update() catch unreachable;
        },
    }

    zow4.input.update();

    if (verbose) w4.trace("[UPDATE] end");
}

test "" {}
