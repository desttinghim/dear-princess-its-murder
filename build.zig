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

    const dearPrincess = try addWasm4Cart(b, "dear-princess", "src/main.zig");
    // dearPrincess.addPackage(pkgs.wasm4);
    dearPrincess.addPackage(pkgs.zow4);
    try z4.addWasm4RunStep(b, "run", dearPrincess);
    const dearPrincess_opt = try z4.addWasmOpt(b, "dear-princess", dearPrincess);
    _ = dearPrincess_opt;

    const main_tests = b.addTest("src/main.zig");
    main_tests.setBuildMode(mode);

    const test_step = b.step("test", "Run library tests");
    test_step.dependOn(&main_tests.step);
}

pub fn addWasm4Cart(b: *std.build.Builder, name: []const u8, path: []const u8) !*std.build.LibExeObjStep {
    const mode = b.standardReleaseOptions();
    const lib = b.addSharedLibrary(name, path, .unversioned);

    lib.addPackage(pkgs.wasm4);

    lib.setBuildMode(mode);
    lib.setTarget(.{ .cpu_arch = .wasm32, .os_tag = .freestanding });
    lib.import_memory = true;
    lib.initial_memory = 65536;
    lib.max_memory = 65536;
    lib.stack_size = 14752;

    // Export WASM-4 symbols
    lib.export_symbol_names = &[_][]const u8{ "start", "update" };

    lib.install();

    return lib;
}
