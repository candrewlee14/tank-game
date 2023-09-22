const std = @import("std");
const Alloc = std.mem.Allocator;

pub const ID = u64;

pub const EntityManager = struct {
    const Self = @This();

    next_id: ID = 0,
    /// The boolean represents whether this entity is marked for deletion
    entities: std.AutoArrayHashMap(ID, bool),

    pub fn init(alloc: Alloc) Self {
        return Self{ .entities = std.AutoArrayHashMap(ID, bool).init(alloc) };
    }
    pub fn deinit(self: *Self) void {
        self.entities.deinit();
    }
    pub fn create(self: *Self) !ID {
        const id = self.next_id;
        try self.entities.putNoClobber(id, false);
        self.next_id += 1;
        return id;
    }
    pub fn markPurge(self: *Self, ent: ID) void {
        self.entities.putAssumeCapacity(ent, true);
    }
    /// This only gets called after all other purges are called,
    /// So no updates operate on now-missing data.
    pub fn purgeReady(self: *Self) !void {
        var it = self.entities.iterator();
        var deleted: usize = 0;
        var i: usize = 0;
        while (it.next()) |entry| : (i += 1) {
            if (entry.value_ptr.*) {
                self.entities.swapRemoveAt(i);
            }
        }
        // TODO: this may be unecessary
        if (deleted > i / 10) try self.entities.reIndex();
    }
};

pub fn ComponentManager(comptime ComponentT: type) type {
    return struct {
        const Self = @This();
        data: std.AutoArrayHashMap(ID, ComponentT),

        pub fn init(alloc: Alloc) !Self {
            return Self{ .data = std.AutoArrayHashMap(ID, ComponentT).init(alloc) };
        }
        pub fn deinit(self: *Self) void {
            self.data.deinit();
        }
        pub fn contains(self: *Self, ent: ID) bool {
            return self.data.contains(ent);
        }
        pub fn add(self: *Self, ent: ID, data: ComponentT) !void {
            try self.data.putNoClobber(ent, data);
        }
        pub fn set(self: *Self, ent: ID, data: ComponentT) void {
            self.data.putAssumeCapacity(ent, data);
        }
        pub fn getPtr(self: *const Self, ent: ID) ?*ComponentT {
            return self.data.getPtr(ent);
        }
        pub fn get(self: *const Self, ent: ID) ?ComponentT {
            return self.data.get(ent);
        }
        pub fn remove(self: *Self, ent: ID) void {
            self.data.swapRemove(ent);
        }
    };
}

const MovementSystem = struct {
    const Self = @This();

    positions: *ComponentManager(Vec2),
    velocities: *const ComponentManager(Vec2),

    pub fn update(self: *const Self) !void {
        const ents = self.positions.data.keys();
        for (ents) |ent| {
            if (self.velocities.get(ent)) |vel| {
                const pos = self.positions.getPtr(ent).?;
                pos.*.x += vel.x;
                pos.*.y += vel.y;
            }
        }
    }
};

const Vec2 = struct {
    x: f32,
    y: f32,
};

test "ECS" {
    var alloc = std.testing.allocator;

    var man_ent = EntityManager.init(alloc);
    defer man_ent.deinit();
    var man_positions = try ComponentManager(Vec2).init(alloc);
    defer man_positions.deinit();
    var man_velocities = try ComponentManager(Vec2).init(alloc);
    defer man_velocities.deinit();

    const boid1 = try man_ent.create();
    const boid2 = try man_ent.create();
    const boid3 = try man_ent.create();
    const boid4 = try man_ent.create();
    const boid5 = try man_ent.create();

    try man_positions.add(boid1, .{ .x = 1, .y = 1 });
    try man_positions.add(boid3, .{ .x = 3, .y = 3 });
    try man_positions.add(boid4, .{ .x = 4, .y = 4 });
    try man_positions.add(boid5, .{ .x = 5, .y = 5 });

    try man_velocities.add(boid1, .{ .x = -1, .y = -1 });
    try man_velocities.add(boid4, .{ .x = -4, .y = 4 });

    const sys_movement = MovementSystem{
        .positions = &man_positions,
        .velocities = &man_velocities,
    };
    try sys_movement.update();

    try std.testing.expectEqualDeep(Vec2{ .x = 0, .y = 0 }, man_positions.get(boid1).?);
    try std.testing.expectEqualDeep(@as(?Vec2, null), man_positions.get(boid2));
    try std.testing.expectEqualDeep(Vec2{ .x = 3, .y = 3 }, man_positions.get(boid3).?);
    try std.testing.expectEqualDeep(Vec2{ .x = 0, .y = 8 }, man_positions.get(boid4).?);
    try std.testing.expectEqualDeep(Vec2{ .x = 5, .y = 5 }, man_positions.get(boid5).?);
}
