const zow4 = @import("zow4");

pub const title_bmp = zow4.draw.load_bitmap(@embedFile("../assets/title-screen.bmp")) catch @compileError("title");

/////////////////////////
// Character Portraits //
/////////////////////////

pub const bubbles_bmp = zow4.draw.load_bitmap(@embedFile("../assets/bubbles.bmp")) catch @compileError("title");
