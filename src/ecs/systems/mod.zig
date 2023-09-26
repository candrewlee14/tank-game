const ecs = @import("../mod.zig");
const rl = @import("raylib");
const Components = @import("../components/mod.zig");
const main = @import("../../main.zig");
const tex = @import("../../tex.zig");
const std = @import("std");

pub const Systems = extern struct {
    // this ordering matters
    mouse: TankMouseSystem,
    keyb: KeyboardMovementSystem,
    mvmt: MovementSystem,
    // render goes last
    der_trans: DerivedTransformSystem,
    spawner: SpawnerSystem,
    rndr: RenderSystem,
    timed_destr: TimedDestructionSystem,

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
};

pub const TimedDestructionSystem = struct {
    const Self = @This();
    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.time_destr.data.keys();
        for (ents) |ent| {
            const timed_destr: Components.TimeDestruct = comps.time_destr.get(ent) orelse continue;
            if (timed_destr.lifetime + timed_destr.birth_time < rl.getTime()) {
                try timed_destr.destroy_fn(game, ent);
            }
        }
    }
};

pub const TankMouseSystem = struct {
    const Self = @This();
    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.mouse.data.keys();
        const mouse_pos = rl.getMousePosition();
        for (ents) |ent| {
            const trans: *Components.TransformObj = comps.trans.getPtr(ent) orelse continue;
            if (trans.dirty) continue; // ignore if dirty
            const wt = trans.getWorld();
            trans.setRot(std.math.atan2(f32, wt.pos.y - mouse_pos.y, wt.pos.x - mouse_pos.x));
        }
    }
};

pub const SpawnerSystem = struct {
    const Self = @This();
    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.spawner.data.keys();
        const time = rl.getTime();
        for (ents) |ent| {
            const spawner: *Components.Spawner = comps.spawner.getPtr(ent).?;
            if (!spawner.is_active) continue;
            if (time - spawner.last_spawn < spawner.spawn_rate) continue;
            spawner.last_spawn = time;
            const spawn = try spawner.factory_fn(game, ent);
            try comps.spawn_src.add(spawn, ent);
            if (spawner.set_inactive_on_spawn) spawner.is_active = false;
        }
    }
};

pub const MovementSystem = struct {
    const Self = @This();

    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.vel.data.keys();
        for (ents) |ent| {
            const vel = comps.vel.get(ent).?;
            const trans = comps.trans.getPtr(ent).?; // anything with vel should have a trans comp
            trans.moveBy(vel);
        }
    }
};

pub const DerivedTransformSystem = struct {
    const Self = @This();

    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.trans.data.keys();
        for (ents) |ent| {
            var trans: *Components.TransformObj = comps.trans.getPtr(ent).?;
            trans.syncWorld(ent, game);
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
            const tex_info: *const tex.Info = comps.tex.get(ent).?;
            const trans = comps.trans.get(ent) orelse continue;

            const tfm: Components.Transform2D = trans.getWorld();

            const s_w: f32 = tex_info.width * tfm.scale.x;
            const s_h: f32 = tex_info.height * tfm.scale.y;
            var origin = tex_info.origin;
            origin.x *= tfm.scale.x;
            origin.y *= tfm.scale.y;
            // std.log.info("origin: {d} {d}", .{ origin.x, origin.y });
            // rl.drawRectanglePro(
            //     .{ .x = tfm.pos.x, .y = tfm.pos.y, .width = s_w, .height = s_h },
            //     origin,
            //     std.math.radiansToDegrees(f32, tfm.rot - tex_info.rot_offset),
            //     rl.Color.sky_blue,
            // );
            game.atlas.tex.drawPro(
                tex_info.getSourceRect(),
                .{ .x = tfm.pos.x, .y = tfm.pos.y, .width = s_w, .height = s_h },
                origin,
                std.math.radiansToDegrees(f32, tfm.rot - tex_info.rot_offset),
                rl.Color.white,
            );
            rl.drawCircle(
                @intFromFloat(tfm.pos.x),
                @intFromFloat(tfm.pos.y),
                2,
                rl.Color.sky_blue,
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
            const trans = comps.trans.getPtr(ent) orelse continue;
            const rot_speed = comps.rot_speed.get(ent) orelse 0;
            const speed = comps.speed.get(ent) orelse 0;

            if (rl.isKeyDown(.key_right) or rl.isKeyDown(.key_d)) trans.rotBy(rot_speed);
            if (rl.isKeyDown(.key_left) or rl.isKeyDown(.key_a)) trans.rotBy(-rot_speed);
            if (rl.isKeyDown(.key_up) or rl.isKeyDown(.key_w)) {
                const rot = trans.getLocal().rot;
                trans.moveBy(.{ .x = @cos(rot) * speed, .y = @sin(rot) * speed });
            }
            if (rl.isKeyDown(.key_down) or rl.isKeyDown(.key_s)) {
                const rot = trans.getLocal().rot;
                trans.moveBy(.{ .x = @cos(rot) * -speed, .y = @sin(rot) * -speed });
            }
        }
    }
};
