const std = @import("std");
const w4 = @import("wasm4");
const zow4 = @import("zow4");

const ui = @import("ui.zig");
const image = @import("image.zig");

const Runner = @import("main.zig").Runner;

pub const DialogIterator = struct {
    dialog: []const Message,
    index: usize,

    pub fn next(this: *@This()) ?Message {
        const index = this.index;
        if (index >= this.dialog.len) return null;
        this.index += 1;
        return this.dialog[index];
    }
};

pub fn get_dialog(dialog: []const Message) DialogIterator {
    return .{
        .index = 0,
        .dialog = dialog,
    };
}

pub const Message = struct {
    portrait: ?zow4.draw.Blit,
    side: enum {left, center, right} = .right,
    text: []const u8,
};

pub const intro = [_]Message{
    .{
        .portrait = .{ .style = 0x04, .bmp = &image.bubbles_bmp },
        .text = 
        \\Uh, welcome to the
        \\game I guess.
        ,
    },
    .{
        .portrait = .{ .style = 0x04, .bmp = &image.bubbles_bmp },
        .text = 
        \\It's a work in
        \\progress but you
        \\can take a look
        \\around.
        ,
    },
    .{
        .portrait = .{ .style = 0x04, .bmp = &image.bubbles_bmp },
        .text = 
        \\Anyway, I've got to
        \\head out now. Say
        \\hi to Pinks for me!
        ,
    },
    .{
        .portrait = null,
        .text =
        \\...
        ,
    },
    .{
        .portrait = .{ .style = 0x04, .bmp = &image.pinks_bmp },
        .text =
        \\Where's Bubbles off
        \\to in such a hurry?
        ,
    },
    .{
        .portrait = null,
        .text =
        \\Work, I imagine.
        \\Not all of us are
        \\self-employed.
        ,
    },
    .{
        .portrait = .{ .style = 0x04, .bmp = &image.pinks_bmp },
        .text =
        \\Sounds awfully
        \\inconvenient...
        \\Would you mind
        \\helping me out?
        ,
    },
    .{
        .portrait = null,
        .text =
        \\Yes, but I get the
        \\feeling you'll ask
        \\anyway. What do
        \\you want?
        ,
    },
};

pub const clue_spotted = [_]Message{
    .{
        .portrait = .{ .style = 0x04, .bmp = &image.pinks_bmp },
        .text =
        \\See? It doesn't
        \\make any sense.
        ,
    },
    .{
        .portrait = .{ .style = 0x04, .bmp = &image.pinks_bmp },
        .text =
        \\It's not like my
        \\landlord to be rude
        \\either.
        ,
    },
};

// fn intro_script(this: *@This()) !void {
//     const messages = .{
//         \\Uh, welcome to the
//         \\game I guess.
//         ,
//         \\It's a work in
//         \\progress but you
//         \\can take a look
//         \\around.
//         ,
//         \\Anyway, I've got to
//         \\head out now. Say
//         \\hi to Pinks for me!
//         ,
//     };
//     _ = try this.create_dialog(.{ .style = 0x04, .bmp = &image.bubbles_bmp }, messages[0]);
//     suspend {}
//     _ = try this.create_dialog(.{ .style = 0x04, .bmp = &image.bubbles_bmp }, messages[1]);
//     suspend {}
//     _ = try this.create_dialog(.{ .style = 0x04, .bmp = &image.bubbles_bmp }, messages[2]);
//     frame_ptr = null;
// }
