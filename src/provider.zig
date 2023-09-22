const std = @import("std");
const main = @import("main.zig");

// pub const GameObjectHandle = usize;

pub fn Callback(comptime paramT: type) type {
    if (paramT == void) {
        return struct {
            func: *const fn (*anyopaque, *main.Game) anyerror!void,
            ctx: *anyopaque,
        };
    }
    return struct {
        func: *const fn (*anyopaque, paramT, *main.Game) anyerror!void,
        ctx: *anyopaque,
    };
}

pub const Input = struct {
    const Self = @This();
    const CallbackT = Callback(void);
    observers: std.ArrayList(CallbackT),

    pub fn init(alloc: std.mem.Allocator) Self {
        return Self{ .observers = std.ArrayList(CallbackT).init(alloc) };
    }
    pub fn deinit(self: *Self) void {
        // TODO: do we need to free any of the observer callback ctxs?
        self.observers.deinit();
    }
    pub fn addObserver(self: *Self, cb: CallbackT) !void {
        try self.observers.append(cb);
    }
    pub fn notify(self: *const Self, game: *main.Game) anyerror!void {
        for (self.observers.items) |cb| {
            try cb.func(cb.ctx, game);
        }
    }
};
