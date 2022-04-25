const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const document = @import("document.zig");
const image = @import("image.zig");

const Runner = @import("main.zig").Runner;

const verbose = false;

const geom = zow4.geometry;

const ui = @import("ui.zig");
const Node = ui.Context.Node;

allocator: std.mem.Allocator,
rand: std.rand.Random,
ctx: ui.Context,
desk: usize,
hud: usize,
dialog_box: ?usize,

const HighlightState = union(enum) { hover, start: struct { line: usize, col: usize, handle: usize }, release };

var grabbed: ?struct { handle: usize, diff: geom.Vec2 } = null;
var highlight = false;
var highlight_state: HighlightState = .hover;
fn handle_grab(ctx: *ui.Context, node: Node, event: zow4.ui.EventData) ?Node {
    if (!highlight) {
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
    }
    return null;
}

fn toggle_highlight(_: *ui.Context, _: Node, _: zow4.ui.EventData) ?Node {
    highlight = !highlight;
    grabbed = null;
    return null;
}

fn handle_highlight(ctx: *ui.Context, node: Node, event: zow4.ui.EventData) ?Node {
    _ = ctx;
    _ = node;
    if (highlight) {
        if (node.data == null) return null;
        if (node.data.? != .Document) return null;
        std.debug.assert(node.data.? == .Document);

        const doc = node.data.?.Document.doc;

        const state = highlight_state;
        switch (state) {
            .hover => {
                if (event._type == .PointerPress) {
                    w4.trace("start");
                    const col = @intCast(usize, @divTrunc(event.pointer.pos[0] - node.bounds[0], 8));
                    const line = @intCast(usize, @divTrunc(event.pointer.pos[1] - node.bounds[1], 8));
                    if (doc.slice_from_col_line(col, line)) |index| {
                        highlight_state = .{ .start = .{ .line = line, .col = col, .handle = node.handle } };
                        w4.traceUtf8(index.ptr, index.len);
                    }
                }
            },
            .start => |histart| {
                if (event._type == .PointerRelease) {
                    if (node.handle != histart.handle) {
                        return null;
                    }
                    const col = @intCast(usize, @divTrunc(event.pointer.pos[0] - node.bounds[0], 8));
                    const line = @intCast(usize, @divTrunc(event.pointer.pos[1] - node.bounds[1], 8));
                    if (doc.slice_from_col_line_2(histart.col, histart.line, col, line)) |ptr| {
                        highlight_state = .hover;
                        w4.traceUtf8(ptr.ptr, ptr.len);
                    } else {
                        w4.trace("couldn't get slice");
                    }
                }
            },
            .release => {},
        }
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

fn handle_dialog(ctx: *ui.Context, node: Node, _: zow4.ui.EventData) ?Node {
    ctx.remove(node.handle);
    if (frame_ptr) |f| {
        resume f;
    }
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
    // TODO: move this to the paper node. It will require functions for
    // querying children
    try this.ctx.listen(content, .PointerPress, handle_minify);
    try this.ctx.listen(content, .PointerPress, handle_highlight);
    try this.ctx.listen(content, .PointerRelease, handle_highlight);

    return content;
}

pub fn create_dialog(this: *@This(), img: zow4.draw.Blit, text: []const u8) !usize {
    if (this.dialog_box) |handle| {
        this.ctx.remove(handle);
    }
    // Positions at bottom with 2px of padding
    this.dialog_box = try this.ctx.insert(this.hud, Node.anchor(
        .{ 0, 100, 100, 100 },
        .{ 2, -40, -2, -2 },
    ));
    try this.ctx.listen(this.dialog_box.?, .PointerClick, handle_dialog);
    // Positions portrait above the dialog
    const portrait_box = try this.ctx.insert(this.dialog_box, Node.anchor(.{ 0, 0, 0, 0 }, .{ 0, -36, 36, -2 }));
    const content_box = try this.ctx.insert(this.dialog_box, Node.anchor(.{ 0, 0, 100, 100 }, .{ 2, 2, -2, -2 }).hasBackground(true).capturePointer(true).eventFilter(.Pass));

    _ = try this.ctx.insert(portrait_box, Node.fill().dataValue(.{ .Image = img }).hasBackground(true));
    _ = try this.ctx.insert(content_box, Node.fill().dataValue(.{ .Label = text }));

    return content_box;
}

pub fn init(runner: Runner) !@This() {
    const alloc = runner.alloc;
    const rand = runner.rand;
    var ctx = try ui.init(alloc);
    var this = @This(){
        .allocator = alloc,
        .rand = rand,
        .ctx = ctx,
        .desk = undefined,
        .dialog_box = null,
        .hud = undefined,
    };
    this.desk = try this.ctx.insert(null, Node.relative().dataValue(.{ .Image = .{ .style = 0x04, .bmp = &image.coffee_shop_bmp } }));
    this.hud = try this.ctx.insert(null, Node.anchor(.{ 0, 0, 100, 100 }, .{ 0, 0, 0, 0 }));
    // _ = try this.create_dialog(.{ .style = 0x04, .bmp = &image.bubbles_bmp }, "Uh, welcome to the\ngame.\nI guess.");
    var b = try this.ctx.insert(this.hud, Node.anchor(.{ 0, 0, 100, 0 }, .{ 0, 0, 0, 16 }));
    var button_list = try this.ctx.insert(b, Node.hlist());
    var btn_highlight = try this.ctx.insert(button_list, Node.relative().dataValue(.{ .Button = "H" }).capturePointer(true));
    _ = try this.ctx.listen(btn_highlight, .PointerClick, toggle_highlight);

    var doc = try this.create_doc(&document.intro_letter);
    var doc2 = try this.create_doc(&document.love_letter);
    var doc3 = try this.create_doc(&document.controls);
    var doc4 = try this.create_doc(&document.pinks_ledger);
    var doc5 = try this.create_doc(&document.eviction_notice);
    if (this.ctx.get_node(doc3)) |controls| {
        if (toggle_minify(&this.ctx, controls)) |node| {
            _ = this.ctx.set_node(node);
        }
    }

    _ = doc;
    _ = doc2;
    _ = doc3;
    _ = doc4;
    _ = doc5;

    w4.trace("end of init");
    return this;
}

fn scene_script(this: *@This()) !void {
    const messages = .{
        \\Uh, welcome to the
        \\game I guess.
        ,
        \\It's a work in
        \\progress but you
        \\can take a look
        \\around.
        ,
        \\Anyway, I've got to
        \\head out now. Say
        \\hi to Pinks for me!
        ,
    };
    _ = try this.create_dialog(.{ .style = 0x04, .bmp = &image.bubbles_bmp }, messages[0]);
    suspend {}
    _ = try this.create_dialog(.{ .style = 0x04, .bmp = &image.bubbles_bmp }, messages[1]);
    suspend {}
    _ = try this.create_dialog(.{ .style = 0x04, .bmp = &image.bubbles_bmp }, messages[2]);
    frame_ptr = null;
}

fn log(string: []const u8) void {
    w4.traceUtf8(string.ptr, string.len);
}

var started = false;
var frame: @Frame(scene_script) = undefined;
var frame_ptr: ?anyframe = null;

pub fn update(this: *@This()) void {
    if (frame_ptr == null and !started) {
        started = true;
        frame = async scene_script(this);
        frame_ptr = &frame;
    }
    if (zow4.input.btnp(.one, .z)) {
        this.ctx.print_debug(this.allocator, log);
    }

    ui.update(&this.ctx);
    if (highlight) {
        const mousepos = zow4.input.mousepos();
        w4.DRAW_COLORS.* = 0x04;
        w4.rect(mousepos[0] - 2, mousepos[1] - 4, 4, 8);
        if (highlight_state == .start) draw_highlight: {
            const node = this.ctx.get_node(highlight_state.start.handle) orelse break :draw_highlight;
            const data = node.data orelse break :draw_highlight;
            if (data != .Document) break :draw_highlight;
            if (@reduce(.Or, mousepos < geom.rect.top_left(node.bounds))) break :draw_highlight;
            if (@reduce(.Or, mousepos > geom.rect.bottom_right(node.bounds))) break :draw_highlight;
            const col = @intCast(usize, @divTrunc(mousepos[0] - node.bounds[0] + 4, 8));
            const line = @intCast(usize, @divTrunc(mousepos[1] - node.bounds[1], 8));
            if (highlight_state.start.line < line or (highlight_state.start.line == line and highlight_state.start.col <= col)) {
                // The beginning is above, or to the left of the cursor
                const draw_x = node.bounds[0] + @intCast(i32, highlight_state.start.col * 8);
                const draw_y = node.bounds[1] + @intCast(i32, highlight_state.start.line * 8);
                if (data.Document.doc.slice_first_line(highlight_state.start.col, highlight_state.start.line, col, line)) |ptr| {
                    w4.DRAW_COLORS.* = 0x41;
                    w4.textUtf8(ptr.ptr, ptr.len, draw_x, draw_y);
                }
                if (data.Document.doc.slice_rest(highlight_state.start.col, highlight_state.start.line, col, line)) |ptr| {
                    w4.DRAW_COLORS.* = 0x41;
                    w4.textUtf8(ptr.ptr, ptr.len, node.bounds[0], draw_y + 8);
                }
            } else {
                // The beginning is below, or to the right of the cursor
                const draw_x = node.bounds[0] + @intCast(i32, col * 8);
                const draw_y = node.bounds[1] + @intCast(i32, line * 8);
                if (data.Document.doc.slice_first_line(highlight_state.start.col, highlight_state.start.line, col, line)) |ptr| {
                    w4.DRAW_COLORS.* = 0x41;
                    w4.textUtf8(ptr.ptr, ptr.len, draw_x, draw_y);
                }
                if (data.Document.doc.slice_rest(highlight_state.start.col, highlight_state.start.line, col, line)) |ptr| {
                    w4.DRAW_COLORS.* = 0x41;
                    w4.textUtf8(ptr.ptr, ptr.len, node.bounds[0], draw_y + 8);
                }
            }
        }
    }
    if (grabbed) |*grab| {
        if (this.ctx.get_node(grab.handle)) |*node| {
            const pos = zow4.input.mousepos() - grab.diff;
            const size = geom.rect.size(node.layout.Anchor.margin);
            node.layout.Anchor.margin = geom.Rect{ pos[0], pos[1], pos[0] + size[0], pos[1] + size[1] };
            if (!this.ctx.set_node(node.*)) w4.trace("[UPDATE] Grab - failed to find node");
            if (!zow4.input.mouse(.left)) grabbed = null;
        }
    }
}
