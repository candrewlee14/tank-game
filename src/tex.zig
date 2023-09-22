const std = @import("std");
const rl = @import("raylib");

const spritesheet_dir = "assets/Spritesheet/";

pub const Info = struct {
    const Self = @This();
    name: []const u8,
    pos: rl.Vector2,
    width: f32,
    height: f32,
    origin: rl.Vector2,
    rot_offset: f32 = -0.5 * std.math.pi,

    pub fn getSourceRect(self: *const Self) rl.Rectangle {
        return .{
            .x = self.pos.x,
            .y = self.pos.y,
            .width = self.width,
            .height = self.height,
        };
    }
};

pub const Atlas = struct {
    const Self = @This();
    const InfoMap = std.json.ArrayHashMap(Info);

    tex: rl.Texture2D,
    info: std.json.Parsed(InfoMap),

    pub fn init(alloc: std.mem.Allocator) !Self {
        const f = try std.fs.cwd().openFile(spritesheet_dir ++ "allSprites_default.json", .{});
        var f_read = f.reader();
        var r = std.json.reader(alloc, f_read);
        const info = try std.json.parseFromTokenSource(InfoMap, alloc, &r, .{});
        return Self{
            .tex = rl.loadTexture(spritesheet_dir ++ "allSprites_default.png"),
            .info = info,
        };
    }

    pub fn deinit(self: *Self) void {
        self.tex.unload();
        self.info.deinit();
    }

    pub fn getInfo(self: *const Self, tex_name: []const u8) *const Info {
        return self.info.value.map.getPtr(tex_name) orelse {
            std.log.err("Couldn't find tex_name: {s}", .{tex_name});
            @panic("Failed to get tex_name");
        };
    }
};
