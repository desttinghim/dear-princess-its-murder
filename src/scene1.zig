const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const document = @import("document.zig");
const dialog = @import("dialog.zig");
const image = @import("image.zig");

const Runner = @import("main.zig").Runner;

const verbose = false;

const geom = zow4.geometry;

const ui = @import("ui.zig");
const Node = ui.Context.Node;

allocator: std.mem.Allocator,
listeners: std.ArrayList(Listener),
rand: std.rand.Random,
ctx: ui.Context,
desk: usize,
hud: usize,
dialog_box: ?usize,
dialog: ?dialog.DialogIterator,
intro_shown: bool = false,
clue_spotted_shown: bool = false,

docs: [4]?usize,

const Self = @This();
const Listener = struct {
    handle: usize,
    event: zow4.ui.Event,
    callback: fn (*Self, zow4.ui.EventData) void,
};

const HighlightState = union(enum) { hover, start: struct { textpos: document.TextPosition, handle: usize }, release };

var grabbed: ?struct { handle: usize, diff: geom.Vec2 } = null;
var highlight = false;
var highlight_state: HighlightState = .hover;
fn handle_grab(this: *@This(), event: zow4.ui.EventData) void {
    const node = this.ctx.get_node(event.current) orelse return;
    if (!highlight) {
        const tag: []const u8 = @tagName(node.layout);
        if (verbose) w4.trace(tag.ptr);
        if (node.layout != .Anchor) return;
        if (!event.pointer.left) return;
        switch (node.layout) {
            .Anchor => |anchor| {
                // Store the anchor and
                grabbed = .{
                    .handle = node.handle,
                    .diff = event.pointer.pos - geom.rect.top_left(anchor.margin),
                };
                this.ctx.bring_to_front(node.handle);
            },
            else => {},
        }
    }
}

fn toggle_highlight(_: *@This(), _: zow4.ui.EventData) void {
    highlight = !highlight;
    grabbed = null;
}

fn handle_highlight(this: *@This(), event: zow4.ui.EventData) void {
    const node = this.ctx.get_node(event.target) orelse return;
    if (highlight) {
        if (node.data == null) return;
        if (node.data.? != .Document) return;
        std.debug.assert(node.data.? == .Document);

        const doc = node.data.?.Document.doc;
        const col = std.math.clamp(@intCast(usize, @divTrunc(event.pointer.pos[0] - node.bounds[0], 8)), 0, doc.cols);
        const line = std.math.clamp(@intCast(usize, @divTrunc(event.pointer.pos[1] - node.bounds[1], 8)), 0, doc.lines);

        const state = highlight_state;
        switch (state) {
            .hover => {
                if (event._type == .PointerPress) {
                    const pos = doc.position(col, line);
                    highlight_state = .{ .start = .{ .textpos = pos, .handle = node.handle } };
                }
            },
            .start => |histart| {
                if (event._type == .PointerRelease) {
                    if (node.handle != histart.handle) {
                        return;
                    }
                    const pos = doc.position(col, line);
                    document.Highlight.add(doc.region(pos, histart.textpos)) catch unreachable;
                    highlight_state = .hover;
                }
            },
            .release => {},
        }
    }
}

fn handle_minify(this: *@This(), event: zow4.ui.EventData) void {
    if (!event.pointer.right) return;
    if (highlight) return;
    const node = this.ctx.get_node(event.current) orelse return;
    toggle_minify(this, node);
}

fn toggle_minify(this: *@This(), node: ui.Node) void {
    if (node.data) |data| {
        if (data == .Document) {
            var new_node = node;
            const is_mini = !data.Document.mini;
            new_node.data.?.Document.mini = is_mini;
            if (this.ctx.get_ancestor(node.handle, 1)) |ancestor| {
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
                _ = this.ctx.set_node(ancestor_update);
                if (!is_mini) this.ctx.bring_to_front(ancestor.handle);
            }
            _ = this.ctx.set_node(new_node);
        }
    }
}

fn handle_dialog(this: *@This(), event: zow4.ui.EventData) void {
    this.ctx.remove(event.current);
    if (this.dialog) |*dopt| {
        if (dopt.next()) |d| {
            _ = this.create_dialog(d.portrait, d.text) catch unreachable;
        } else {
            this.dialog = null;
        }
    }
}

pub fn create_doc(this: *@This(), doc: *const document.Document) !usize {
    const pad = 2;
    const size = geom.Vec2{ doc.cols + pad * 2, doc.lines + pad * 2 };
    // Listen for events on this floating node, since it controls positioning.
    // This node uses the default of
    const rand = this.rand.intRangeLessThanBiased;
    const offset = geom.Vec2{ rand(i32, -40, 40), rand(i32, -40, 40) };
    const pos = (geom.Vec2{ 80, 80 }) - @divTrunc(size, geom.Vec2{ 2, 2 }) + offset;
    const floatnode = Node.anchor(.{ 0, 0, 0, 0 }, .{ pos[0], pos[1], pos[0] + size[0], pos[1] + size[1] }).capturePointer(true);
    var float = try this.ctx.insert(this.desk, floatnode);
    try this.listen(float, .PointerPress, handle_grab);

    // Capture events and pass them up
    const papernode = Node
        .anchor(.{ 0, 0, 100, 100 }, .{ pad, pad, -pad, -pad })
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
    try this.listen(content, .PointerPress, handle_minify);
    try this.listen(content, .PointerPress, handle_highlight);
    try this.listen(content, .PointerRelease, handle_highlight);

    // const float_btns_container = Node
        // .anchor(.{ 0, 100, 100, 100 }, .{ pad, -pad - 16, -pad, -pad })
        // .eventFilter(.Pass);
    // const float_btns = try this.ctx.insert(float, float_btns_container);

    // const done_btn = try this.ctx.insert(float_btns, Node.relative().dataValue(.{ .Button = "Done" }).capturePointer(true).eventFilter(.Pass));
    // _ = done_btn;

    return content;
}

pub fn create_dialog(this: *@This(), img_opt: ?zow4.draw.Blit, text: []const u8) !usize {
    if (this.dialog_box) |handle| {
        this.ctx.remove(handle);
    }
    // Positions at bottom with 2px of padding
    this.dialog_box = try this.ctx.insert(this.hud, Node.anchor(
        .{ 0, 100, 100, 100 },
        .{ 2, -40, -2, -2 },
    ).capturePointer(true));
    try this.listen(this.dialog_box.?, .PointerClick, handle_dialog);
    // Positions portrait above the dialog
    const content_box = try this.ctx.insert(this.dialog_box, Node.anchor(.{ 0, 0, 100, 100 }, .{ 2, 2, -2, -2 }).hasBackground(true).capturePointer(true).eventFilter(.Pass));

    if (img_opt) |img| {
        const portrait_box = try this.ctx.insert(this.dialog_box, Node.anchor(.{ 0, 0, 0, 0 }, .{ 2, -img.bmp.height - 4, img.bmp.width + 4, -2 }));
        _ = try this.ctx.insert(portrait_box, Node.fill().dataValue(.{ .Image = img }).hasBackground(true));
    }
    _ = try this.ctx.insert(content_box, Node.fill().dataValue(.{ .Label = text }));

    return content_box;
}

fn listen(this: *@This(), handle: usize, event: zow4.ui.Event, callback: fn (*@This(), zow4.ui.EventData) void) !void {
    try this.listeners.append(.{ .handle = handle, .event = event, .callback = callback });
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
        .dialog = null,
        .hud = undefined,
        .listeners = std.ArrayList(Listener).init(alloc),
        .docs = .{null} ** 4,
    };
    this.desk = try this.ctx.insert(null, Node.relative().dataValue(.{ .Image = .{ .style = 0x04, .bmp = &image.coffee_shop_bmp } }));
    this.hud = try this.ctx.insert(null, Node.anchor(.{ 0, 0, 100, 100 }, .{ 0, 0, 0, 0 }));
    var b = try this.ctx.insert(this.hud, Node.anchor(.{ 0, 0, 100, 0 }, .{ 0, 0, 0, 14 }));
    var button_list = try this.ctx.insert(b, Node.hlist());
    var btn_highlight = try this.ctx.insert(button_list, Node.relative().dataValue(.{ .Button = "Mark" }).capturePointer(true));
    try this.listen(btn_highlight, .PointerClick, toggle_highlight);

    this.docs[0] = try this.create_doc(&document.intro_letter);
    this.docs[1] = try this.create_doc(&document.controls);

    if (this.ctx.get_node(this.docs[0].?)) |intro| {
        toggle_minify(&this, intro);
    }
    if (this.ctx.get_node(this.docs[1].?)) |controls| {
        toggle_minify(&this, controls);
    }

    // try document.Highlight.add(document.Highlight.important[0]);
    // try document.Highlight.add(document.Highlight.important[1]);
    return this;
}

pub fn update(this: *@This()) !void {
    const intro_letter_closed = closed: {
        const doc_handle = this.docs[0] orelse break :closed false;
        const doc_node = this.ctx.get_node(doc_handle) orelse break :closed false;
        const data = doc_node.data orelse break :closed false;
        const doc = data.Document;
        if (doc.mini) break :closed true;
        break :closed false;
    };
    if (intro_letter_closed and !this.intro_shown and this.dialog == null) {
        this.dialog = dialog.get_dialog(&dialog.intro);
        const d = this.dialog.?.next() orelse unreachable;
        _ = try this.create_dialog(d.portrait, d.text);
        this.intro_shown = true;
        highlight = false;
    }
    if (this.intro_shown and this.dialog == null and this.docs[2] == null and this.docs[3] == null) {
        this.docs[2] = try this.create_doc(&document.pinks_ledger);
        this.docs[3] = try this.create_doc(&document.eviction_notice);
    }
    const important_found = document.Highlight.important_found();
    if (this.intro_shown and !this.clue_spotted_shown and important_found > 1 and this.dialog == null) {
        this.dialog = dialog.get_dialog(&dialog.clue_spotted);
        const d = this.dialog.?.next() orelse unreachable;
        _ = try this.create_dialog(d.portrait, d.text);
        this.clue_spotted_shown = true;
        highlight = false;
    }

    const inputs = ui.get_inputs();
    var update_iter = this.ctx.poll(inputs);
    while (update_iter.next()) |event| {
        for (this.listeners.items) |listener| {
            if (listener.handle == event.current and listener.event == event._type) {
                listener.callback(this, event);
            }
        }
    }
    this.ctx.layout(.{ 0, 0, 160, 160 });
    this.ctx.paint();
    if (highlight) {
        const mousepos = zow4.input.mousepos();
        w4.DRAW_COLORS.* = 0x04;
        w4.rect(mousepos[0], mousepos[1] - 6, 1, 8);
        if (highlight_state == .start) draw_highlight: {
            const node = this.ctx.get_node(highlight_state.start.handle) orelse break :draw_highlight;
            const data = node.data orelse break :draw_highlight;
            if (data != .Document) break :draw_highlight;
            if (@reduce(.Or, mousepos < geom.rect.top_left(node.bounds))) break :draw_highlight;
            if (@reduce(.Or, mousepos > geom.rect.bottom_right(node.bounds))) break :draw_highlight;
            const col = @intCast(usize, @divTrunc(mousepos[0] - node.bounds[0], 8));
            const line = @intCast(usize, @divTrunc(mousepos[1] - node.bounds[1], 8));
            if (highlight_state.start.textpos.line < line or (highlight_state.start.textpos.line == line and highlight_state.start.textpos.col <= col)) {
                // The beginning is above, or to the left of the cursor
                const draw_x = node.bounds[0] + @intCast(i32, highlight_state.start.textpos.col * 8);
                const draw_y = node.bounds[1] + @intCast(i32, highlight_state.start.textpos.line * 8);
                if (data.Document.doc.slice_first_line(highlight_state.start.textpos.col, highlight_state.start.textpos.line, col, line)) |ptr| {
                    w4.DRAW_COLORS.* = 0x41;
                    w4.textUtf8(ptr.ptr, ptr.len, draw_x, draw_y);
                }
                if (data.Document.doc.slice_rest(highlight_state.start.textpos.col, highlight_state.start.textpos.line, col, line)) |ptr| {
                    w4.DRAW_COLORS.* = 0x41;
                    w4.textUtf8(ptr.ptr, ptr.len, node.bounds[0], draw_y + 8);
                }
            } else {
                // The beginning is below, or to the right of the cursor
                const draw_x = node.bounds[0] + @intCast(i32, col * 8);
                const draw_y = node.bounds[1] + @intCast(i32, line * 8);
                if (data.Document.doc.slice_first_line(highlight_state.start.textpos.col, highlight_state.start.textpos.line, col, line)) |ptr| {
                    w4.DRAW_COLORS.* = 0x41;
                    w4.textUtf8(ptr.ptr, ptr.len, draw_x, draw_y);
                }
                if (data.Document.doc.slice_rest(highlight_state.start.textpos.col, highlight_state.start.textpos.line, col, line)) |ptr| {
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
