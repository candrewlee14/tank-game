const std = @import("std");
const rl = @import("raylib");
const tex = @import("tex.zig");
const tk = @import("tank.zig");
const provider = @import("provider.zig");

const SCREEN_HEIGHT = 450;
const SCREEN_WIDTH = 800;

pub const GameObject = union(enum) {
    bullet: tk.Bullet,
    tank: tk.Tank,
    bullet_spawner: tk.BulletSpawner,
    barrel: tk.Barrel,
};

pub const GameObjectStore = std.SegmentedList(GameObject, 1000);

pub const Game = struct {
    const Self = @This();

    input_provider: provider.Input,
    atlas: tex.Atlas,
    screen_height: i32 = SCREEN_HEIGHT,
    screen_width: i32 = SCREEN_WIDTH,
    tank: tk.Tank,
    store: GameObjectStore = .{},

    pub fn init(self: *Self, alloc: std.mem.Allocator) !void {
        rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tank Game");
        rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

        self.* = Self{
            .input_provider = provider.Input.init(alloc),
            .tank = undefined,
            .atlas = try tex.Atlas.init(alloc),
        };
        try self.tank.init(&self.atlas);
        try self.tank.subscribeToInput(&self.input_provider);
        try self.tank.barrel.subscribeToInput(&self.input_provider);
    }

    pub fn deinit(self: *Self) void {
        rl.closeWindow();
        self.tank.deinit();
        self.input_provider.deinit();
        self.atlas.deinit();
    }

    pub fn update(self: *Self) !void {
        try self.input_provider.notify(self);
    }

    pub fn draw(self: *const Self) !void {
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.white);
        rl.drawText("First window!", 10, 10, 20, rl.Color.light_gray);
        self.tank.draw(&self.atlas);
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    var game: Game = undefined;
    try game.init(alloc);

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        try game.update();
        try game.draw();
        //----------------------------------------------------------------------------------
    }
}
