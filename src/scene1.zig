const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const verbose = false;

const geom = zow4.geometry;

const ui = @import("ui.zig");
const Node = ui.Context.Node;

allocator: std.mem.Allocator,
ctx: ui.Context,
desk: usize,

var grabbed: ?struct { handle: usize, diff: geom.Vec2, moved: bool } = null;
fn handle_grab(node: Node, event: zow4.ui.EventData) ?Node {
    const tag: []const u8 =  @tagName(node.layout);
    if (verbose) w4.trace(tag.ptr);
    if (node.layout != .Anchor) return null;
    switch (node.layout) {
        .Anchor => |anchor| {
            // Store the anchor and
            grabbed = .{
                .handle = node.handle,
                .diff = event.pointer.pos - geom.rect.top_left(anchor.margin),
                .moved = false,
            };
        },
        else => {},
    }
    return null;
}

pub fn create_doc(this: *@This()) !usize {
    // Listen for events on this floating node, since it controls positioning.
    // This node uses the default of
    const floatnode = Node
        .anchor(.{ 0, 0, 0, 0 }, .{ 20, 20, 100, 100 })
    ;
    var float = try this.ctx.insert(this.desk, floatnode);
    try this.ctx.listen(float, .PointerPress, handle_grab);

    // Capture events and pass them up
    const node = Node
        .hlist()
        .hasBackground(true)
        .capturePointer(true)
        .eventFilter(.Pass)
    ;
    var doc = try this.ctx.insert(float, node);
    return doc;
}

pub fn init(alloc: std.mem.Allocator) !@This() {
    var ctx = try ui.init(alloc);
    var this = @This(){
        .allocator = alloc,
        .ctx = ctx,
        .desk = undefined,
    };
    this.desk = try this.ctx.insert(null, Node.relative());

    var doc = try this.create_doc();
    _ = try this.ctx.insert(doc, Node.relative().dataValue(.{ .Label = "Hello" }).capturePointer(false).eventFilter(.Pass));

    var doc2 = try this.create_doc();
    _ = try this.ctx.insert(doc2, Node.relative().dataValue(.{ .Label = "Bye" }));

    return this;
}

fn log(string: []const u8) void {
    w4.traceUtf8(string.ptr, string.len);
}

pub fn update(this: *@This()) void {
    // if (zow4.input.mousep(.left)) w4.trace("click");
    ui.update(&this.ctx);
    if (grabbed) |*grab| {
        if (this.ctx.get_node(grab.handle)) |*node| {
            const pos = zow4.input.mousepos() - grab.diff;
            const size = geom.rect.size(node.layout.Anchor.margin);
            node.layout.Anchor.margin = geom.Rect{ pos[0], pos[1], pos[0] + size[0], pos[1] + size[1] };
            if (!this.ctx.set_node(node.*)) w4.trace("[UPDATE] Grab - failed to find node");
            if (!grab.moved) {
                if (verbose) this.ctx.print_debug(this.allocator, log);
                this.ctx.bring_to_front(node.handle);
                grab.moved = true;
                if (verbose) w4.trace("moved");
            }
            if (!zow4.input.mouse(.left)) grabbed = null;
        }
    }
}
