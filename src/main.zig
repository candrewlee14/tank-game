const std = @import("std");
const rl = @import("raylib");
const tex = @import("tex.zig");
// const tk = @import("tank.zig");
const provider = @import("provider.zig");
const ecs = @import("ecs/mod.zig");
const Systems = @import("ecs/systems/mod.zig").Systems;
const Components = @import("ecs/components/mod.zig");

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
    try game.components.trans.add(tank, .{ .local = .{ .pos = .{ .x = 100, .y = 100 } } });
    try game.components.speed.add(tank, 2);
    try game.components.rot_speed.add(tank, 0.07);
    try game.components.tex.add(tank, game.atlas.getInfo("tankBody_red_outline.png"));
    try game.components.keyb.add(tank, {});

    const barrel = try game.ents.create();
    try game.components.trans.add(barrel, .{
        .local = .{
            .pos = .{ .x = 0, .y = 0 },
            // .scale = .{ .x = 1, .y = 4 },
        },
        .derived_rot = false,
    });
    try game.components.mouse.add(barrel, {});
    try game.components.parent.add(barrel, tank);
    try game.components.tex.add(barrel, game.atlas.getInfo("specialBarrel1_outline.png"));

    const track_spawner = try game.ents.create();
    try game.components.trans.add(track_spawner, .{
        .local = .{
            .pos = .{ .x = 0, .y = 0 },
            // .scale = .{ .x = 1, .y = 4 },
        },
    });
    try game.components.parent.add(track_spawner, tank);
    try game.components.spawner.add(track_spawner, .{
        //     spawn_rate: f64,
        // last_spawn: f64,
        // factory_fn: fn (*main.Game) anyerror!void,
        // is_active: bool = false,
        // set_inactive_on_spawn: bool = false,
        .spawn_rate = 0.1,
        .last_spawn = 0,
        .factory_fn = &create_tracks,
        .is_active = true,
    });

    const bullet_spawner = try game.ents.create();
    try game.components.parent.add(bullet_spawner, barrel);
    try game.components.trans.add(bullet_spawner, .{
        .local = .{ .pos = .{ .x = -20, .y = 0 } },
    });
    try game.components.tex.add(bullet_spawner, game.atlas.getInfo("shotLarge.png"));
    //--------------------------------------------------------------------------------------

    // Main game loop
    while (!rl.windowShouldClose()) { // Detect window close button or ESC key
        try game.update();
        try game.draw();
        try game.ents.purgeReady();
        //----------------------------------------------------------------------------------
    }
}

pub fn create_tracks(game: *Game, spawner_ent: ecs.ID) anyerror!ecs.ID {
    var src_trans: Components.TransformObj = game.components.trans.get(spawner_ent).?;
    const spawn = try game.ents.create();
    std.debug.assert(src_trans.dirty == false);
    try game.components.trans.add(spawn, .{
        .local = src_trans.derived,
        .derived = src_trans.derived,
        .dirty = false,
    });
    try game.components.tex.add(spawn, game.atlas.getInfo("tracksDouble.png"));
    try game.components.time_destr.add(spawn, Components.TimeDestruct.init(5, &destroy_track));
    return spawn;
}

pub fn destroy_track(game: *Game, ent: ecs.ID) anyerror!void {
    _ = game.components.trans.remove(ent);
    _ = game.components.tex.remove(ent);
    _ = game.components.time_destr.remove(ent);
    try game.ents.markPurge(ent);
}
