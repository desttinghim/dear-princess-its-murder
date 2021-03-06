const zow4 = @import("zow4");

pub const title_bmp = zow4.draw.load_bitmap(@embedFile("../assets/title-screen.bmp")) catch @compileError("title");

///////////////
// Locations //
///////////////

pub const coffee_shop_bmp = zow4.draw.load_bitmap(@embedFile("../assets/coffee-shop.bmp")) catch @compileError("coffee shop");

/////////////////////////
// Character Portraits //
/////////////////////////

pub const bubbles_bmp = zow4.draw.load_bitmap(@embedFile("../assets/bubbles.bmp")) catch @compileError("bubbles");
pub const pinks_bmp = zow4.draw.load_bitmap(@embedFile("../assets/pinks.bmp")) catch @compileError("pinks");
pub const sparkles_bmp = zow4.draw.load_bitmap(@embedFile("../assets/sparkles.bmp")) catch @compileError("sparkles");
