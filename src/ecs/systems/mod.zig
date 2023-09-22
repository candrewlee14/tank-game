const ecs = @import("../mod.zig");
const rl = @import("raylib");
const Components = @import("../components/mod.zig");
const main = @import("../../main.zig");
const tex = @import("../../tex.zig");
const std = @import("std");

pub const Systems = extern struct {
    // this ordering matters
    mouse: PanToMouseSystem,
    keyb: KeyboardMovementSystem,
    mvmt: MovementSystem,
    // render goes last
    der_trans: DerivedTransformSystem,
    rndr: RenderSystem,

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

pub const PanToMouseSystem = struct {
    const Self = @This();
    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.mouse.data.keys();
        const mouse_pos = rl.getMousePosition();
        for (ents) |ent| {
            const trans: *Components.TransformObj = comps.trans.getPtr(ent) orelse continue;
            // this is a special case of directly setting derived
            trans.setRot(std.math.atan2(f32, trans.derived.pos.y - mouse_pos.y, trans.derived.pos.x - mouse_pos.x));
        }
    }
};

pub const MovementSystem = struct {
    const Self = @This();

    pub fn update(self: *const Self, game: *main.Game) !void {
        _ = self;
        const comps = &game.components;
        const ents = comps.trans.data.keys();
        for (ents) |ent| {
            const trans = comps.trans.getPtr(ent).?;
            const vel = comps.vel.get(ent) orelse continue;
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
            game.atlas.tex.drawPro(
                tex_info.getSourceRect(),
                .{ .x = tfm.pos.x, .y = tfm.pos.y, .width = s_w, .height = s_h },
                tex_info.origin,
                std.math.radiansToDegrees(f32, tfm.rot - tex_info.rot_offset),
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
