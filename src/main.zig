const std = @import("std");

const InternalStr = packed union {
    short: @Vector(12, u8),
    long: packed struct(u96) {
        prefix: u32,
        ptr: [*]u8,
    },
};

const GermanString = packed struct {
    len: u32,
    content: InternalStr,

    pub inline fn get_prefix(self: *GermanString) [4]u8 {
        return @bitCast(self.content.long.prefix);
    }

    pub inline fn get(self: *GermanString) []const u8 {
        return if (self.len > 12) self.content.long.ptr[4..self.len] else {
            const as_arr: *[16]u8 = @ptrCast(&self.content.short);
            return as_arr[4 .. self.len + 4];
        };
    }
};

const GerString = struct {
    alloc: std.mem.Allocator,
    string: GermanString,

    pub fn init(alloc: std.mem.Allocator, str: []const u8) !GerString {
        var res = GerString{
            .alloc = alloc,
            .string = GermanString{ .len = 0, .content = InternalStr{ .short = undefined } },
        };

        try res.create(str);
        return res;
    }

    pub fn deinit(self: *GerString) void {
        if (self.string.len > 12) {
            var string: []u8 = undefined;
            string.len = @intCast(self.string.len - 4);
            string.ptr = self.string.content.long.ptr;
            self.alloc.free(string);
            self.string.len = 0;
        } else {
            self.string.len = 0;
        }
    }

    fn create(self: *GerString, str: []const u8) !void {
        if (str.len > 12) {
            self.string.len = @intCast(str.len);
            self.string.content = .{ .long = .{
                .prefix = undefined,
                .ptr = (try self.alloc.alloc(u8, self.string.len - 4)).ptr,
            } };
            self.string.content.long.prefix = std.mem.bytesToValue(u32, str[0..4]);
            @memcpy(self.string.content.long.ptr[4..self.string.len], str[4..]);
        } else {
            self.string.len = @intCast(str.len);
            self.string.content.short = @splat(0);
            const ptr: *[16]u8 = @ptrCast(&self.string.content.short);
            @memcpy(ptr[4 .. str.len + 4], str[0..]);
        }
    }

    pub inline fn get(self: *GerString) []const u8 {
        return self.string.get();
    }

    pub inline fn get_prefix(self: *GerString) [4]u8 {
        return self.string.get_prefix();
    }
};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const alloc = gpa.allocator();

    std.debug.print("internal string: {d} bits.\n", .{@bitSizeOf(InternalStr)});

    var ger_str = try GerString.init(alloc, "Hello, my name is Harold :3");
    defer ger_str.deinit();

    std.debug.print("Content from gerstr: {s}{s}\n", .{ ger_str.get_prefix(), ger_str.get() });

    var short_ger = try GerString.init(alloc, "holzmaster");
    defer short_ger.deinit();

    std.debug.print("content form short_str {s}\n", .{short_ger.get()});
}

test {
    std.testing.refAllDecls(@This());
}

test "test length" {
    const allocator = std.testing.allocator;

    var ger_str = try GerString.init(allocator, "0123456789123"); // 13 bytes
    defer ger_str.deinit();
}
