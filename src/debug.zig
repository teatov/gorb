const std = @import("std");
const lexer = @import("./lexer.zig");
const object = @import("./object.zig");

pub const Debugger = struct {
    stdin: std.fs.File.Reader = undefined,
    stdout: std.fs.File.Writer = undefined,
    buf: [32]u8 = undefined,
    enabled: bool = false,

    const Self = @This();

    pub fn init() Self {
        const stdin = std.io.getStdIn().reader();
        const stdout = std.io.getStdOut().writer();

        return .{ .stdin = stdin, .stdout = stdout };
    }

    pub fn awaitInput(self: *Self) !void {
        if (self.enabled) {
            _ = try self.stdin.readUntilDelimiter(&self.buf, '\n');
            self.clearTerminal() catch unreachable;
        }
    }

    pub fn printEnvironment(
        self: Self,
        allocator: std.mem.Allocator,
        env: *object.Environment,
    ) !void {
        if (!self.enabled) {
            return;
        }
        _ = try self.stdout.print("\n========\nENV {*}\n", .{env});
        var iterator = env.store.iterator();
        while (iterator.next()) |value| {
            const value_string = try value.value_ptr.*.inspect(allocator);
            // try self.moveCursor();
            _ = try self.stdout.print(
                "{s} = {s}\n",
                .{ value.key_ptr.*, value_string },
            );
            allocator.free(value_string);
        }
        _ = try self.stdout.print("\n", .{});
        if (env.outer) |outer| {
            try self.printEnvironment(allocator, outer);
        }
    }

    fn clearTerminal(self: Self) !void {
        _ = try self.stdout.write("\x1B[2J\x1B[H");
    }
};
