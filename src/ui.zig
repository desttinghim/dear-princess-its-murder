const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");
const Document = @import("document.zig").Document;
const g = zow4.geometry;
const ui = zow4.ui;
const draw = zow4.draw;
const text = zow4.text;
const input = zow4.input;

pub const Context = ui.Context(UI);
pub const Node = Context.Node;

pub fn init(alloc: std.mem.Allocator) !Context {
    return Context.init(alloc, UI.size, UI.update, UI.paint);
}

pub fn print_debug(this: Node) void {
    const typename: [*:0]const u8 = @tagName(this.layout);
    const dataname: [*:0]const u8 = if (this.data) |data| @tagName(data) else "null";
    w4.tracef("type %s, data %s, children %d", typename, dataname, this.children);
}

pub fn update(ui_ctx: *Context) void {
    ui_ctx.update(.{
        .pointer = .{
            .left = input.mouse(.left),
            .right = input.mouse(.right),
            .middle = input.mouse(.middle),
            .pos = input.mousepos(),
        },
        .keys = .{
            .up = input.btn(.one, .up),
            .down = input.btn(.one, .down),
            .left = input.btn(.one, .left),
            .right = input.btn(.one, .right),
            .accept = input.btn(.one, .x),
            .reject = input.btn(.one, .z),
        },
    });
    ui_ctx.layout(.{ 0, 0, 160, 160 });
    if (w4.SYSTEM_FLAGS.* & w4.SYSTEM_PRESERVE_FRAMEBUFFER == 0) {
        // If the framebuffer is not being preserved, just draw
        ui_ctx.paint();
    } else if (!g.vec.isZero(input.mousediff()) or input.mouse(.any)) {
        w4.DRAW_COLORS.* = 0x1;
        w4.rect(0, 0, 160, 160);
        ui_ctx.paint();
    }
    input.update();
}

pub const UI = union(enum) {
    /// Draws text to the screen. Pass a pointer to the text to be rendered.
    Label: []const u8,
    /// Draws a Document to the screen
    Document: struct { doc: *const Document, mini: bool },
    /// Draws an image to the screen. Assumes there is another array containing image info
    Image: *draw.Blit,
    /// Button
    Button: []const u8,

    pub fn size(this: @This()) g.Vec2 {
        switch (this) {
            .Label => |label| {
                const label_size = text.text_size(label);
                return .{
                    label_size[0],
                    label_size[1],
                };
            },
            .Document => |doc| {
                if (doc.mini) {
                    return .{
                        doc.doc.cols,
                        doc.doc.lines,
                    };
                } else {
                    return .{
                        doc.doc.cols * 8,
                        doc.doc.lines * 8,
                    };
                }
            },
            .Image => |blit| {
                const blit_size = blit.get_size();
                return .{
                    blit_size[0], blit_size[1],
                };
            },
            .Button => |btn_label| {
                const label_size = text.text_size(btn_label);
                const padding = 6; // 3 pixels left, 2 pixels right
                return .{
                    label_size[0] + padding,
                    label_size[1] + padding,
                };
            },
        }
    }

    pub fn update(node: Node) Node {
        if (node.data) |data| {
            switch (data) {
                .Label => {},
                .Document => {},
                .Image => {},
                .Button => {},
            }
        }
        return node;
    }

    pub fn paint(node: Node) void {
        if (node.has_background) {
            var left = g.rect.left(node.bounds);
            var top = g.rect.top(node.bounds);

            const rect_size = g.rect.size(node.bounds);
            // Make sure we are at least the minimum size to prevent crashing
            var sizex = @intCast(u32, rect_size[0]);
            var sizey = @intCast(u32, rect_size[1]);

            // Clear background
            w4.DRAW_COLORS.* = 0x41;
            w4.rect(left, top, sizex, sizey);
        }
        if (node.data) |data| {
            switch (data) {
                .Label => |label| {
                    w4.DRAW_COLORS.* = 0x04;
                    w4.textUtf8(label.ptr, label.len, node.bounds[0], node.bounds[1]);
                },
                .Document => |doc| {
                    if (doc.mini) {
                        w4.DRAW_COLORS.* = 0x04;
                        doc.doc.draw_mini(g.rect.top_left(node.bounds));
                    } else {
                        w4.DRAW_COLORS.* = 0x04;
                        doc.doc.draw(g.rect.top_left(node.bounds));
                    }
                },
                .Image => |blit| {
                    blit.blit(.{ node.bounds[0], node.bounds[1] });
                },
                .Button => |btn_label| {
                    var left = g.rect.left(node.bounds);
                    var right = g.rect.right(node.bounds);
                    var top = g.rect.top(node.bounds);
                    var bottom = g.rect.bottom(node.bounds);

                    const rect_size = g.rect.size(node.bounds);
                    // Make sure we are at least the minimum size to prevent crashing
                    var sizex = @intCast(u32, if (rect_size[0] < node.min_size[0])
                        node.min_size[0]
                    else
                        rect_size[0]);
                    var sizey = @intCast(u32, if (rect_size[1] < node.min_size[1])
                        node.min_size[1]
                    else
                        rect_size[1]);

                    // Clear background
                    w4.DRAW_COLORS.* = 0x01;
                    w4.rect(left + 1, top + 1, sizex - 2, sizey - 2);
                    var dark = false;
                    switch (node.pointer_state) {
                        .Open, .Hover, .Drag => {
                            w4.DRAW_COLORS.* = 0x04;
                            // Render "Shadow"
                            w4.hline(left + 2, bottom - 1, sizex - 2);
                            w4.vline(right - 1, top + 2, sizey - 2);
                            // Render "Side"
                            w4.hline(left + 1, bottom - 2, sizex - 2);
                            w4.vline(right - 2, top + 1, sizey - 2);
                            if (node.pointer_state == .Hover) {
                                w4.DRAW_COLORS.* = 0x41;
                                w4.rect(left + 1, top + 1, sizex - 2, sizey - 2);
                            }
                        },
                        .Press => {
                            w4.DRAW_COLORS.* = 0x44;
                            w4.rect(left + 2, top + 2, sizex - 2, sizey - 2);
                            dark = true;
                        },
                        .Click => {
                            w4.DRAW_COLORS.* = 0x44;
                            w4.rect(left + 2, top + 2, sizex - 2, sizey - 2);
                            dark = true;
                        },
                    }
                    w4.DRAW_COLORS.* = if (dark) 0x01 else 0x04;
                    const offset: i32 = if (dark) 4 else 3;
                    w4.textUtf8(btn_label.ptr, btn_label.len, left + offset, top + offset);
                },
            }
        }
    }
};
