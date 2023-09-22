const ecs = @import("ecs.zig");
const std = @import("std");
const rl = @import("raylib");
const tex = @import("tex.zig");
const Self = @This();

pos: ecs.ComponentManager(rl.Vector2),
scale: ecs.ComponentManager(rl.Vector2),
rot: ecs.ComponentManager(f32),
vel: ecs.ComponentManager(rl.Vector2),
tex: ecs.ComponentManager(*const tex.Info),
keyb: ecs.ComponentManager(void),
speed: ecs.ComponentManager(f32),
rot_speed: ecs.ComponentManager(f32),

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
