const std = @import("std");

const KB = 1024;
const MB = 1024 * KB;

// TODO: put the wasm4 bundling script here
pub fn main() !void {
    var args = std.process.args();

    _ = args.skip();

    const exe_src = args.next() orelse return error.ExecutableSrc;
    const cart_src = args.next() orelse return error.CartSrc;
    const output = args.next() orelse return error.Output;

    std.log.info("{s} {s} {s}", .{exe_src, cart_src, output});

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();

    const cart_file = try std.fs.openFileAbsolute(cart_src, .{});
    const cart = try cart_file.readToEndAlloc(allocator, 1 * MB);
    defer allocator.free(cart);

    const exe_file = try std.fs.openFileAbsolute(exe_src, .{});
    const exe = try exe_file.readToEndAlloc(allocator, 10 * MB);
    defer allocator.free(exe);

    var data = std.ArrayList(u8).init(allocator);
    defer data.deinit();
    const writer = data.writer();

    try writer.writeAll(exe);
    try writer.writeAll(cart);

    var footer = FileFooter{
        .magic = .{ 'C', 'A', 'R', 'T' },
        .title = undefined,
        .cartLength = @truncate(u32, cart.len),
    };

    _ = try std.fmt.bufPrintZ(&footer.title, "Dear Princess", .{});

    try writer.writeStruct(footer);

    try std.fs.cwd().writeFile(output, data.items);
}

const FileFooter = extern struct {
    /// Should be the 4 byte ASCII string "CART" (1414676803)
    magic: [4]u8,

    /// Window title
    title: [128]u8,

    /// Length of the cart.wasm bytes used to offset backwards from the footer
    cartLength: u32,
};
