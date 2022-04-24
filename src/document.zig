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

pub const controls = Document.fromText(
    \\CONTROLS:
    \\
    \\Left click and
    \\drag to move items
    \\around.
    \\
    \\Right click to
    \\Expand or minimize
    \\documents.
);

pub const intro_letter = Document.fromText(
    \\Sparkles,
    \\
    \\ We really must
    \\find some time to
    \\catch up! It's been
    \\boring here without
    \\your brilliant
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

pub const eviction_notice = Document.fromText(
    \\Dear Pinks Baker,
    \\
    \\This is a warn-
    \\ing. We will be
    \\evicting you at
    \\the end of the
    \\month unless you
    \\pay your rent.
    \\
    \\Your Landlord,
    \\Blueblood
);

pub const pinks_ledger = pinks: {
    const data = .{
        .{ 0, "2/2", "Coffee", 100 },
        .{ 1, "2/8", "Rent", 700 },
    };
    const format_str = "\n{:>3}|{s:^6}|{s:<7}|{:>6}g" ** data.len;
    const new_fmt =
        \\Ln | Date | Desc. | Amount
        \\---+------+-------+-------
    ++ format_str;
    var new_data = data[0] ++ data[1];
    const ledger = Document.fromText(std.fmt.comptimePrint(new_fmt, new_data));
    break :pinks ledger;
};
