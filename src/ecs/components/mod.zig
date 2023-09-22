const ecs = @import("../mod.zig");
const std = @import("std");
const rl = @import("raylib");
const tex = @import("../../tex.zig");
const main = @import("../../main.zig");

const Self = @This();

trans: ecs.ComponentManager(TransformObj),
vel: ecs.ComponentManager(rl.Vector2),
tex: ecs.ComponentManager(*const tex.Info),
keyb: ecs.ComponentManager(void),
mouse: ecs.ComponentManager(void),
speed: ecs.ComponentManager(f32),
rot_speed: ecs.ComponentManager(f32),
parent: ecs.ComponentManager(ecs.ID),
spawn_src: ecs.ComponentManager(ecs.ID),

pub fn init(alloc: std.mem.Allocator) !Self {
    var self: Self = undefined;
    inline for (std.meta.fields(Self)) |field| {
        @field(self, field.name) = try (field.type).init(alloc);
    }
    return self;
}

pub fn deinit(self: *Self) void {
    inline for (std.meta.fields(Self)) |field| {
        @field(self, field.name).deinit();
    }
}

pub const Transform2D = struct {
    pos: rl.Vector2,
    scale: rl.Vector2 = .{ .x = 1, .y = 1 },
    rot: f32 = 0,

    pub fn composeWith(self: *Transform2D, other: *const Transform2D) void {
        // add pos
        self.pos.x += other.pos.x;
        self.pos.y += other.pos.y;
        // mul scale
        self.scale.x *= other.scale.x;
        self.scale.y *= other.scale.y;
        // add rot
        self.rot += other.rot;
    }
};

pub const TransformObj = struct {
    local: Transform2D,
    derived: Transform2D = undefined, // dirty bit forces us to define this

    dirty: bool = true,

    derived_pos: bool = true,
    derived_scale: bool = true,
    derived_rot: bool = true,

    pub fn moveBy(self: *TransformObj, vel: rl.Vector2) void {
        self.local.pos.x += vel.x;
        self.local.pos.y += vel.y;
        self.dirty = true;
    }

    pub fn setPos(self: *TransformObj, new_pos: rl.Vector2) void {
        self.pos = new_pos;
        self.dirty = true;
    }

    pub fn rotBy(self: *TransformObj, rot_amt: f32) void {
        self.local.rot += rot_amt;
        self.dirty = true;
    }

    pub fn setScale(self: *TransformObj, new_scale: rl.Vector2) void {
        self.local.scale = new_scale;
        self.dirty = true;
    }

    pub fn setRot(self: *TransformObj, new_rot: f32) void {
        self.local.rot = new_rot;
        self.dirty = true;
    }

    pub fn getLocal(self: *const TransformObj) Transform2D {
        return self.local;
    }
    pub fn getWorld(self: *const TransformObj) Transform2D {
        std.debug.assert(!self.dirty);
        return self.derived;
    }
    pub fn syncWorld(self: *TransformObj, my_id: ecs.ID, game: *main.Game) void {
        // TODO: right now we have to go all the way up the highest parent,
        // dirty is just local to this element
        // dirty *should* allow us to not have to recurse up the tree though
        // this would involve setting all children recursively as dirty when parent moves ...
        // is that better?
        // I think when we recurse into children, if it is marked as dirty, we can exit early
        // which might make it quick
        const comps = &game.components;
        const p_id = comps.parent.get(my_id) orelse {
            if (self.dirty) {
                self.derived = self.local;
                self.dirty = false;
            }
            return;
        };
        var plocal = comps.trans.getPtr(p_id) orelse {
            if (self.dirty) {
                self.derived = self.local;
                self.dirty = false;
            }
            return;
        };
        if (plocal.dirty) {
            plocal.syncWorld(p_id, game);
        }
        const p_world = plocal.getWorld();
        self.derived = self.local;
        // add pos
        if (self.derived_pos) {
            self.derived.pos.x += p_world.pos.x;
            self.derived.pos.y += p_world.pos.y;
        }
        // mul scale
        if (self.derived_scale) {
            self.derived.scale.x *= p_world.scale.x;
            self.derived.scale.y *= p_world.scale.y;
        }
        // add rot
        if (self.derived_rot) self.derived.rot += p_world.rot;
        self.dirty = false;
    }
};
