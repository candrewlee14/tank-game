const std = @import("std");
const rl = @import("raylib");
const tex = @import("tex.zig");
// const tk = @import("tank.zig");
const provider = @import("provider.zig");
const ecs = @import("ecs.zig");
const Systems = @import("systems.zig");
const Components = @import("components.zig");

const SCREEN_HEIGHT = 450;
const SCREEN_WIDTH = 800;

pub const Game = struct {
    const Self = @This();

    atlas: tex.Atlas,
    screen_height: i32 = SCREEN_HEIGHT,
    screen_width: i32 = SCREEN_WIDTH,

    ents: ecs.EntityManager,

    components: Components,
    systems: Systems,

    pub fn init(self: *Self, alloc: std.mem.Allocator) !void {
        rl.initWindow(SCREEN_WIDTH, SCREEN_HEIGHT, "Tank Game");
        rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

        self.* = Self{
            .atlas = try tex.Atlas.init(alloc),
            .ents = ecs.EntityManager.init(alloc),
            .components = try Components.init(alloc),
            .systems = undefined,
        };
        self.systems = try Systems.init(&self.components);
    }

    pub fn deinit(self: *Self) void {
        rl.closeWindow();
        self.atlas.deinit();
        self.ents.deinit();
        self.components.deinit();
        self.systems.deinit();
    }

    pub fn update(self: *Self) !void {
        inline for (std.meta.fields(Systems)) |field| {
            try @field(self.systems, field.name).update(self);
        }
    }

    pub fn draw(self: *const Self) !void {
        _ = self;
        rl.beginDrawing();
        defer rl.endDrawing();
        rl.clearBackground(rl.Color.white);
        rl.drawText("First window!", 10, 10, 20, rl.Color.light_gray);
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();
    var game: Game = undefined;
    try game.init(alloc);

    const tank = try game.ents.create();
    try game.components.pos.add(tank, .{ .x = 100, .y = 100 });
    try game.components.speed.add(tank, 2);
    try game.components.rot.add(tank, 0);
    try game.components.rot_speed.add(tank, 0.07);
    try game.components.scale.add(tank, .{ .x = 1, .y = 1 });
    try game.components.tex.add(tank, game.atlas.getInfo("tank_red.png"));
    try game.components.keyb.add(tank, {});

    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        try game.update();
        try game.draw();
        //----------------------------------------------------------------------------------
    }
}
