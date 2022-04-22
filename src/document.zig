const w4 = @import("wasm4");
const std = @import("std");
const zow4 = @import("zow4");
const geom = zow4.geometry;

pub const Document = struct {
    text: []const u8,
    cols: i32,
    lines: i32,

    pub fn draw(this: @This(), pos: geom.Vec2) void {
        w4.textUtf8(this.text.ptr, this.text.len, pos[0], pos[1]);
    }

    pub fn draw_mini(this: @This(), pos: geom.Vec2) void {
        text_mini(this.text, pos, null);
    }

    pub fn fromText(string: []const u8) @This() {
        @setEvalBranchQuota(10_000);
        var tokiter = std.mem.split(u8, string, "\n");
        var i: usize = 0;
        var maxline: usize = 0;
        while (tokiter.next()) |tok| {
            i += 1;
            if (tok.len > maxline) maxline = tok.len;
            // if (tok.len > 19) {
            //     @compileLog("Line is too long: ");
            //     @compileLog(i);
            // }
        }
        return @This(){
            .text = string,
            .cols = @intCast(i32, maxline),
            .lines = @intCast(i32, i),
        };
    }
};

const CharDrawType = enum {
    Character,
    Space,
    Newline,
};

fn get_char_draw_type(char: u8) CharDrawType {
    switch (char) {
        'A'...'Z',
        'a'...'z',
        ':'...'@',
        '!'...'.',
        '['...'`',
        '{'...'~',
        => return .Character,
        ' ' => return .Space,
        '\n' => return .Newline,
        else => return .Space,
    }
}

/// Draws a string in a miniature form, with 1 pixel equal to 1 character.
pub fn text_mini(string: []const u8, pos: geom.Vec2, lines: ?usize) void {
    var x = pos[0];
    var y = pos[1];
    var line: usize = 0;
    for (string) |char| {
        switch (get_char_draw_type(char)) {
            .Space => {
                x += 1;
            },
            .Character => {
                zow4.draw.pixel(x, y);
                x += 1;
            },
            .Newline => {
                line += 1;
                if (lines) |l| {
                    if (line == l) return;
                }
                x = pos[0];
                y += 1;
            },
        }
    }
}

///////////////////
// Document Data //
///////////////////

pub const intro_letter = Document.fromText(
    \\Sparkles,
    \\
    \\ We really must
    \\find some time to
    \\catch up! It's been
    \\boring here without
    \\you're brilliant
    \\intellect to keep
    \\things sparkling...
    \\
    \\ Unfortunately this
    \\contact is for more
    \\serious matters.
    \\Recent events have
    \\made quite a stir,
    \\though I'm afraid
    \\there's not much I
    \\can tell you at the
    \\moment. Suffice it
    \\to say I will be
    \\contacting you
    \\soon. I do hope
    \\you are caught up
    \\on your studies,
    \\because I will be
    \\needing your help
    \\for some time
    \\afterwords.
    \\
    \\ - Sunshine
);

pub const love_letter = Document.fromText(
    \\Hey,
    \\
    \\ I think you're
    \\really  cool and
    \\I'd like to get
    \\to know you better.
    \\
    \\ I just can't stop
    \\thinking about your
    \\curly hair, cute
    \\horns, and yummy
    \\cinnamon buns!
    \\
    \\ -
);
