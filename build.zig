const std = @import("std");

const Pkg = std.build.Pkg;
const FileSource = std.build.FileSource;

const z4 = @import("lib/zow4/build.zig");

const pkgs = struct {
    const zow4 = Pkg{
        .name = "zow4",
        .path = FileSource.relative("lib/zow4/src/zow4.zig"),
        .dependencies = &.{wasm4},
    };

    const wasm4 = Pkg{
        .name = "wasm4",
        .path = FileSource.relative("lib/zow4/src/wasm4.zig"),
        .dependencies = &.{},
    };
};

pub fn build(b: *std.build.Builder) !void {
    // Standard release options allow the person running `zig build` to select
    // between Debug, ReleaseSafe, ReleaseFast, and ReleaseSmall.
    const mode = b.standardReleaseOptions();

    const dearPrincess = try z4.addWasm4Cart(b, "dear-princess", "src/main.zig");
    dearPrincess.addPackage(pkgs.wasm4);
    dearPrincess.addPackage(pkgs.zow4);
    try z4.addWasm4RunStep(b, "run", dearPrincess);
    const dearPrincess_opt = try z4.addWasmOpt(b, "dear-princess", dearPrincess);
    _ = dearPrincess_opt;

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}
