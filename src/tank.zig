const std = @import("std");
const rl = @import("raylib");
const tex = @import("tex.zig");
const provider = @import("provider.zig");
const main = @import("main.zig");
const ecs = @import("ecs.zig");

pub const Bullet = struct {
    const Self = @This();

    pos: rl.Vector2,
    speed: f32,
    rot: f32,
    scale: rl.Vector2 = .{ .x = 1, .y = 1 },
    tex_info: *const tex.Info,

    pub fn init(self: *Self, atlas: *const tex.Atlas) !void {
        self.tex_info = atlas.getInfo("bulletDark1_outline.png");
    }
    pub fn update(self: *Self) !void {
        self.pos.x += @cos(self.rot) * self.speed;
        self.pos.y += @sin(self.rot) * self.speed;
    }
    pub fn draw(self: *Self, atlas: *const tex.Atlas) !void {
        const w: f32 = self.tex_info.width * self.scale.x;
        const h: f32 = self.tex_info.height * self.scale.y;
        atlas.tex.drawPro(
            self.tex_info.getSourceRect(),
            .{ .x = self.pos.x, .y = self.pos.y, .width = w, .height = h },
            .{ .x = w / 2, .y = h / 2 },
            std.math.radiansToDegrees(f32, self.rot + std.math.pi * 0.5),
            rl.Color.white,
        );
    }
};

pub const BulletSpawner = struct {
    const Self = @This();

    barrel_src: *Barrel,
    last_shot: f64 = 0,
    fire_rate: f64 = 10,
    bullets: std.heap.MemoryPool(Bullet),

    pub fn subscribeToInput(self: *Self, input: *provider.Input) !void {
        const cb: provider.Callback(void) = .{
            .func = handleInputCb,
            .obj_handle = self,
        };
        try input.addObserver(cb);
    }
    fn handleInputCb(ctx: *anyopaque, game: *main.Game) anyerror!void {
        _ = game;
        const self: *Self = @alignCast(@ptrCast(ctx));
        try handleInput(self);
    }
    fn handleInput(self: *Self) !void {
        const cur_time = rl.getTime();
        if (rl.isMouseButtonDown(.mouse_button_left) and (cur_time - self.last_shot) >= self.fire_rate) {
            self.last_shot = cur_time;
            std.log.info("Shot!", .{});
            var bullet = try self.bullets.create(Bullet);
            bullet.init();
        }
    }
};

pub const Barrel = struct {
    const Self = @This();

    mount: *Tank,
    rot: f32 = 0,
    tex_info: *const tex.Info,
    scale: rl.Vector2 = .{ .x = 1.5, .y = 1.5 },

    pub fn init(self: *Self, mount: *Tank, atlas: *const tex.Atlas) !void {
        self.* = Self{
            .mount = mount,
            .tex_info = atlas.getInfo("specialBarrel1_outline.png"),
        };
    }

    pub fn update(self: *Self) void {
        _ = self;
    }

    pub fn draw(self: *const Self, atlas: *const tex.Atlas) void {
        const s_barrel_w: f32 = self.tex_info.width * self.mount.scale.x * self.scale.x;
        const s_barrel_h: f32 = self.tex_info.height * self.mount.scale.y * self.scale.y;
        const barrel_orig_y = 10 * self.mount.scale.y * self.scale.y; // TODO: move this constant into the json file
        atlas.tex.drawPro(
            self.tex_info.getSourceRect(),
            .{ .x = self.mount.pos.x, .y = self.mount.pos.y, .width = s_barrel_w, .height = s_barrel_h },
            .{ .x = s_barrel_w / 2, .y = barrel_orig_y },
            std.math.radiansToDegrees(f32, self.rot + std.math.pi * 0.5),
            rl.Color.white,
        );
    }

    pub fn subscribeToInput(self: *Self, input: *provider.Input) !void {
        const cb: provider.Callback(void) = .{
            .func = handleInputCb,
            .ctx = self,
        };
        try input.addObserver(cb);
    }
    fn handleInputCb(ctx: *anyopaque, game: *main.Game) anyerror!void {
        _ = game;
        const self: *Self = @alignCast(@ptrCast(ctx));
        try handleInput(self);
    }
    fn handleInput(self: *Self) !void {
        const mouse_pos = rl.getMousePosition();
        self.rot = std.math.atan2(f32, self.mount.pos.y - mouse_pos.y, self.mount.pos.x - mouse_pos.x);
    }
};

pub const Tank = struct {
    const Self = @This();

    id: 
    input_obs: ?provider.Callback(void) = null,
    pos: rl.Vector2 = .{ .x = 100, .y = 100 },
    /// rotation in radians
    rot: f32 = 0,
    /// rotation speed (in radians per frame)
    rot_speed: f32 = 0.07,
    speed: f32 = 2,
    scale: rl.Vector2 = .{ .x = 1, .y = 1 },
    tex_info: *const tex.Info,
    barrel: Barrel,

    pub fn init(self: *Self, atlas: *const tex.Atlas, game: *const main.Game) !void {
        self.* = Self{
            .id = try game.ents.create(),
            .tex_info = atlas.getInfo("tankBody_red_outline.png"),
            .barrel = undefined,
        };
        try self.barrel.init(self, atlas);
    }
    pub fn subscribeToInput(self: *Self, input: *provider.Input) !void {
        const cb: provider.Callback(void) = .{
            .func = handleInputCb,
            .ctx = self,
        };
        try input.addObserver(cb);
    }
    fn handleInputCb(ctx: *anyopaque, game: *main.Game) anyerror!void {
        _ = game;
        const self: *Self = @alignCast(@ptrCast(ctx));
        try handleInput(self);
    }
    fn handleInput(self: *Self) !void {
        if (rl.isKeyDown(.key_right) or rl.isKeyDown(.key_d)) self.rot += self.rot_speed;
        if (rl.isKeyDown(.key_left) or rl.isKeyDown(.key_a)) self.rot -= self.rot_speed;
        if (rl.isKeyDown(.key_up) or rl.isKeyDown(.key_w)) {
            self.pos.x += @cos(self.rot) * self.speed;
            self.pos.y += @sin(self.rot) * self.speed;
        }
        if (rl.isKeyDown(.key_down) or rl.isKeyDown(.key_s)) {
            self.pos.x -= @cos(self.rot) * self.speed;
            self.pos.y -= @sin(self.rot) * self.speed;
        }
    }
    pub fn deinit(self: *Self) void {
        _ = self;
    }
    pub fn update(self: *Self) void {
        _ = self;
    }
    pub fn draw(self: *const Self, atlas: *const tex.Atlas) void {
        // Body
        const s_body_w: f32 = self.tex_info.width * self.scale.x;
        const s_body_h: f32 = self.tex_info.height * self.scale.y;
        atlas.tex.drawPro(
            self.tex_info.getSourceRect(),
            .{ .x = self.pos.x, .y = self.pos.y, .width = s_body_w, .height = s_body_h },
            .{ .x = s_body_w / 2, .y = s_body_h / 2 },
            std.math.radiansToDegrees(f32, self.rot + std.math.pi * 0.5),
            rl.Color.white,
        );
        self.barrel.draw(atlas);
    }
};
