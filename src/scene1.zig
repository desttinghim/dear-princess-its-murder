const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const document = @import("document.zig");
const image = @import("image.zig");

const verbose = false;

const geom = zow4.geometry;

const ui = @import("ui.zig");
const Node = ui.Context.Node;

allocator: std.mem.Allocator,
rand: std.rand.Random,
ctx: ui.Context,
desk: usize,
dialog_box: ?usize,

var grabbed: ?struct { handle: usize, diff: geom.Vec2 } = null;
fn handle_grab(ctx: *ui.Context, node: Node, event: zow4.ui.EventData) ?Node {
    const tag: []const u8 = @tagName(node.layout);
    if (verbose) w4.trace(tag.ptr);
    if (node.layout != .Anchor) return null;
    if (!event.pointer.left) return null;
    switch (node.layout) {
        .Anchor => |anchor| {
            // Store the anchor and
            grabbed = .{
                .handle = node.handle,
                .diff = event.pointer.pos - geom.rect.top_left(anchor.margin),
            };
            ctx.bring_to_front(node.handle);
        },
        else => {},
    }
    return null;
}

fn handle_minify(ctx: *ui.Context, node: Node, event: zow4.ui.EventData) ?Node {
    if (!event.pointer.right) return null;
    return toggle_minify(ctx, node);
}

fn toggle_minify(ctx: *ui.Context, node: Node) ?Node {
    if (node.data) |data| {
        if (data == .Document) {
            var new_node = node;
            const is_mini = !data.Document.mini;
            new_node.data.?.Document.mini = is_mini;
            if (ctx.get_ancestor(node.handle, 1)) |ancestor| {
                std.debug.assert(ancestor.layout == .Anchor);
                var ancestor_update = ancestor;
                const old_pos = geom.rect.top_left(ancestor.layout.Anchor.margin);
                // const old_size = geom.rect.size(ancestor.layout.Anchor.margin);
                const size = new_node.data.?.size() + geom.Vec2{ 4, 4 };
                const pos = pos: {
                    if (is_mini) {
                        break :pos data.Document.desk_pos;
                    } else {
                        new_node.data.?.Document.desk_pos = old_pos;
                        break :pos (geom.Vec2{ 80 - @divTrunc(size[0], 2), 8 });
                    }
                };
                ancestor_update.layout.Anchor.margin = .{ pos[0], pos[1], pos[0] + size[0], pos[1] + size[1] };
                _ = ctx.set_node(ancestor_update);
                ctx.bring_to_front(ancestor.handle);
            }
            return new_node;
        }
    }
    return null;
}

fn handle_delete(ctx: *ui.Context, node: Node, _: zow4.ui.EventData) ?Node {
    ctx.remove(node.handle);
    return null;
}

pub fn create_doc(this: *@This(), doc: *const document.Document) !usize {
    const pad = 2;
    const size = geom.Vec2{ doc.cols + pad * 2, doc.lines + pad * 2 };
    // Listen for events on this floating node, since it controls positioning.
    // This node uses the default of
    const rand = this.rand.intRangeLessThanBiased;
    const offset = geom.Vec2{ rand(i32, -40, 40), rand(i32, -40, 40) };
    const pos = (geom.Vec2{ 80, 80 }) - @divTrunc(size, geom.Vec2{ 2, 2 }) + offset;
    const floatnode = Node.anchor(.{ 0, 0, 0, 0 }, .{ pos[0], pos[1], pos[0] + size[0], pos[1] + size[1] });
    var float = try this.ctx.insert(this.desk, floatnode);
    try this.ctx.listen(float, .PointerPress, handle_grab);

    // Capture events and pass them up
    const papernode = Node
        .anchor(.{ 0, 0, 100, 100 }, .{ pad, pad, pad, pad })
        .hasBackground(true)
        .capturePointer(true)
        .eventFilter(.Pass);
    const paper = try this.ctx.insert(float, papernode);

    const contentnode = Node
        .relative()
        .dataValue(.{ .Document = .{ .doc = doc, .mini = true, .desk_pos = pos } })
        .capturePointer(true)
        .eventFilter(.Pass);
    const content = try this.ctx.insert(paper, contentnode);
    try this.ctx.listen(content, .PointerPress, handle_minify);

    return content;
}

pub fn create_dialog(this: *@This(), img: zow4.draw.Blit) !usize {
    if (this.dialog_box) |handle| {
        this.ctx.remove(handle);
    }
    // Positions at bottom with 2px of padding
    this.dialog_box = try this.ctx.insert(null, Node.anchor(.{0, 100, 100, 100}, .{2, -40, -2, -2},).capturePointer(true));
    try this.ctx.listen(this.dialog_box.?, .PointerClick, handle_delete);
    // Positions portrait above the dialog
    const portrait_box = try this.ctx.insert(this.dialog_box, Node.anchor(.{0, 0, 0, 0}, .{0, -36, 36, -2}));
    //
    const content_box = try this.ctx.insert(this.dialog_box, Node.anchor(.{0, 0, 100, 100}, .{2, 2, -2, -2}).hasBackground(true));

    _= try this.ctx.insert(portrait_box, Node.fill().dataValue(.{.Image = img}).hasBackground(true));
    _= try this.ctx.insert(content_box, Node.fill().dataValue(.{.Label = "Words"}));

    return content_box;
}

pub fn init(alloc: std.mem.Allocator, rand: std.rand.Random) !@This() {
    var ctx = try ui.init(alloc);
    var this = @This(){
        .allocator = alloc,
        .rand = rand,
        .ctx = ctx,
        .desk = undefined,
        .dialog_box = null,
    };
    this.desk = try this.ctx.insert(null, Node.relative());
    _ = try this.create_dialog(.{ .style = 0x04, .bmp = &image.bubbles_bmp });

    var doc = try this.create_doc(&document.intro_letter);
    var doc2 = try this.create_doc(&document.love_letter);
    var doc3 = try this.create_doc(&document.controls);
    if (this.ctx.get_node(doc3)) |controls| {
        if (toggle_minify(&this.ctx, controls)) |node| {
            _ = this.ctx.set_node(node);
        }
    }

    _ = doc;
    _ = doc2;
    _ = doc3;

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
            // if (!grab.moved) {
            //     if (verbose) this.ctx.print_debug(this.allocator, log);
            //     this.ctx.bring_to_front(node.handle);
            //     grab.moved = true;
            //     if (verbose) w4.trace("moved");
            // }
            if (!zow4.input.mouse(.left)) grabbed = null;
        }
    }
}
