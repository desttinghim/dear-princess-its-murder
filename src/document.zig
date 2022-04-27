const w4 = @import("wasm4");
const std = @import("std");
const zow4 = @import("zow4");
const geom = zow4.geometry;

/// A TextPosition stores a point in a document.
pub const TextPosition = struct { index: u16, line: u8, col: u8 };

pub const TextRegion = struct {
    document: *const Document,
    /// NOTE: Assumed to be in order
    region: [2]TextPosition,

    pub fn contains(this: @This(), other: @This()) bool {
        return (this.document == other.document and
            this.region[0].line <= other.region[0].line and
            this.region[0].col <= other.region[0].col and
            this.region[1].line >= other.region[1].line and
            this.region[1].col >= other.region[1].col);
    }
};

/// A singleton that manages player highlights
pub const Highlight = struct {
    pub const important: []const TextRegion = &.{
        .{
            .document = &pinks_ledger,
            .region = .{ pinks_ledger.position(11, 3), pinks_ledger.position(15, 3) },
        },
        .{
            .document = &eviction_notice,
            .region = .{ eviction_notice.position(9, 7), eviction_notice.position(13, 7) },
        },
    };

    var list: std.ArrayList(TextRegion) = undefined;

    pub fn init(allocator: std.mem.Allocator) !void {
        list = try std.ArrayList(TextRegion).initCapacity(allocator, 20);
    }

    pub fn deinit() void {
        list.deinit();
    }

    pub fn add(new_highlight: TextRegion) !void {
        try list.append(new_highlight);
    }

    pub fn has_found(which: usize) bool {
        const imp = important[which];
        for (list.items) |highlight| {
            if (highlight.contains(imp)) return true;
        }
        return false;
    }

    pub fn important_found() usize {
        var found: usize = 0;
        for (important) |imp| {
            for (list.items) |highlight| {
                if (highlight.contains(imp)) found += 1;
            }
        }
        return found;
    }
};

fn sliceContainsSlice(container: []u8, slice: []u8) bool {
    return @ptrToInt(slice.ptr) >= @ptrToInt(container.ptr) and
        (@ptrToInt(slice.ptr) + slice.len) <= (@ptrToInt(container.ptr) + container.len);
}

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

    fn index_from_col_line(this: @This(), col: usize, line: usize) usize {
        std.debug.assert(col <= this.cols and line <= this.lines);
        var lineiter = std.mem.split(u8, this.text, "\n");
        var i: usize = 0;
        var index: usize = 0;
        while (lineiter.next()) |line_slice| : (i += 1) {
            if (i != line) {
                index += line_slice.len + 1;
                continue;
            }
            if (line_slice.len <= col) return index + line_slice.len;
            return index + col;
        }
        return index - 1;
    }

    fn index_from_line(this: @This(), line: usize) usize {
        std.debug.assert(line <= this.lines);
        var lineiter = std.mem.split(u8, this.text, "\n");
        var i: usize = 0;
        var index: usize = 0;
        while (lineiter.next()) |line_slice| : (i += 1) {
            if (i != line) {
                index += line_slice.len + 1;
                continue;
            }
            return index;
        }
        return index - 1;
    }

    pub fn slice_from_col_line(this: @This(), col: usize, line: usize) ?[]const u8 {
        if (col > this.cols or line > this.lines) return null;
        const index = this.index_from_col_line(col, line);
        return this.text[index..index];
    }

    pub fn slice_to_eol(this: @This(), col: usize, line: usize) ?[]const u8 {
        if (col > this.cols or line > this.lines) return null;
        const index = this.index_from_col_line(col, line);
        if (line + 1 >= this.lines) return this.text[index..];
        const index2 = this.index_from_line(line + 1);
        return this.text[index..index2];
    }

    pub fn slice_from_eol(this: @This(), col: usize, line: usize) ?[]const u8 {
        if (col > this.cols or line > this.lines) return null;
        const index = if (line == 0) 0 else this.index_from_line(line - 1);
        const index2 = this.index_from_line(line);
        return this.text[index .. index2 + col];
    }

    pub fn slice_first_line(this: @This(), col1: usize, line1: usize, col2: usize, line2: usize) ?[]const u8 {
        if (line1 == line2) return this.slice_from_col_line_2(col1, line1, col2, line2);
        const first_line = if (line1 <= line2) line1 else line2;
        const first_col = if (line1 <= line2) col1 else col2;
        return this.slice_to_eol(first_col, first_line);
    }

    pub fn slice_rest(this: @This(), col1: usize, line1: usize, col2: usize, line2: usize) ?[]const u8 {
        if (line1 == line2) return null;
        const first_line = if (line1 <= line2) line1 else line2;
        const second_line = if (line1 <= line2) line2 else line1;
        const second_col = if (line1 <= line2) col2 else col1;
        return this.slice_from_col_line_2(0, first_line + 1, second_col, second_line);
    }

    pub fn slice_from_col_line_2(this: @This(), col1: usize, line1: usize, col2: usize, line2: usize) ?[]const u8 {
        if (line1 > this.lines or col1 > this.cols or line2 > this.lines or col2 > this.cols) return null;
        const index1 = this.index_from_col_line(col1, line1);
        const index2 = this.index_from_col_line(col2, line2);
        return if (index1 < index2)
            this.text[index1..index2]
        else
            this.text[index2..index1];
    }

    pub fn position(this: @This(), col: usize, line: usize) TextPosition {
        @setEvalBranchQuota(4000);
        const index = @truncate(u16, this.index_from_col_line(col, line));
        return .{ .index = index, .col = @truncate(u8, col), .line = @truncate(u8, line) };
    }

    pub fn region(this: *const @This(), pos1: TextPosition, pos2: TextPosition) TextRegion {
        const first_pos = if (pos1.index <= pos2.index) pos1 else pos2;
        const second_pos = if (first_pos.index == pos1.index) pos2 else pos1;
        return .{
            .document = this,
            .region = .{ first_pos, second_pos },
        };
    }

    pub const HighlightIterator = struct {
        document: *const Document,
        index: usize,
        pub fn next(this: *@This()) ?TextRegion {
            if (this.index >= Highlight.list.items.len) return null;
            while (this.index < Highlight.list.items.len) : (this.index += 1) {
                if (this.document == Highlight.list.items[this.index].document) {
                    const index = this.index;
                    this.index += 1;
                    return Highlight.list.items[index];
                }
            }
            return null;
        }
    };

    // Returns an iterator over every highlight in document, in the order the player highlighted them
    pub fn highlight_iterator(this: *const @This()) HighlightIterator {
        return HighlightIterator{
            .document = this,
            .index = 0,
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
