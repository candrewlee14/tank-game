const ecs = @import("ecs.zig");
const rl = @import("raylib");
const Components = @import("components.zig");
const main = @import("main.zig");
const tex = @import("tex.zig");
const std = @import("std");

const Systems = @This();

mvmt: MovementSystem,
rndr: RenderSystem,
keyb: KeyboardMovementSystem,

pub fn init(comp: *Components) !Systems {
    _ = comp;
    var systems: Systems = undefined;
    // for each system field in Systems
    inline for (std.meta.fields(Systems)) |field| {
        @field(systems, field.name) = (field.type){};
        // // for each component field in a system
        // inline for (std.meta.fields(field.type)) |comp_field| {
        //     // set the value of that field to be a reference to the same field name in comp
        //     @field(system, comp_field.name) = &@field(comp, comp_field.name);
        // }
    }
    // return Systems{ .mvmt = MovementSystem{ .pos = &comp.pos, .vel = &comp.vel }, .rndr = RenderSystem{.pos} };
    return systems;
}
pub fn deinit(self: *Systems) void {
    _ = self;
}

pub const MovementSystem = struct {
    const Self = @This();

    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.pos.data.keys();
        for (ents) |ent| {
            const vel = comps.vel.get(ent) orelse continue;
            const pos = comps.pos.getPtr(ent).?;
            pos.*.x += vel.x;
            pos.*.y += vel.y;
        }
    }
};

pub const RenderSystem = struct {
    const Self = @This();

    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.tex.data.keys();
        for (ents) |ent| {
            const tex_info = comps.tex.get(ent).?;
            const pos = comps.pos.get(ent) orelse continue;

            const rot = comps.rot.get(ent) orelse 0;
            const scale = comps.scale.get(ent) orelse rl.Vector2{ .x = 1, .y = 1 };

            const s_w: f32 = tex_info.width * scale.x;
            const s_h: f32 = tex_info.height * scale.y;
            game.atlas.tex.drawPro(
                tex_info.getSourceRect(),
                .{ .x = pos.x, .y = pos.y, .width = s_w, .height = s_h },
                tex_info.origin,
                std.math.radiansToDegrees(f32, rot - std.math.pi * 0.5),
                rl.Color.white,
            );
        }
    }
};

pub const KeyboardMovementSystem = struct {
    const Self = @This();

    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.keyb.data.keys();
        for (ents) |ent| {
            const pos = comps.pos.getPtr(ent) orelse continue;
            const speed = comps.speed.get(ent) orelse continue;
            const rot = comps.rot.getPtr(ent) orelse continue;
            const rot_speed = comps.rot_speed.get(ent) orelse continue;

            if (rl.isKeyDown(.key_right) or rl.isKeyDown(.key_d)) rot.* += rot_speed;
            if (rl.isKeyDown(.key_left) or rl.isKeyDown(.key_a)) rot.* -= rot_speed;
            if (rl.isKeyDown(.key_up) or rl.isKeyDown(.key_w)) {
                pos.x += @cos(rot.*) * speed;
                pos.y += @sin(rot.*) * speed;
            }
            if (rl.isKeyDown(.key_down) or rl.isKeyDown(.key_s)) {
                pos.x -= @cos(rot.*) * speed;
                pos.y -= @sin(rot.*) * speed;
            }
        }
    }
};
