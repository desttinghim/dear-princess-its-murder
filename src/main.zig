const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const ui = @import("ui.zig");
const Scene1 = @import("scene1.zig");

const KB = 1024;
var heap: [24 * KB]u8 = undefined;
var fba: std.heap.FixedBufferAllocator = std.heap.FixedBufferAllocator.init(&heap);

var scene: Scene1 = undefined;

const verbose = false;

export fn start() void {
    if (verbose) w4.trace("[START] begin");

    var scn = Scene1.init(fba.allocator()) catch |e| {
        switch (e) {
            error.OutOfMemory => zow4.mem.report_memory_usage(fba),
        }
        zow4.panic("Couldn't start scene1");
        unreachable;
    };
    scene = scn;

    if (verbose) w4.trace("[START] end");
}

export fn update() void {
    if (verbose) w4.trace("[UPDATE] begin");

    scene.update();

    if (verbose) w4.trace("[UPDATE] end");
}

test "" {}
