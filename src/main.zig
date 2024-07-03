const std = @import("std");
const run = @import("./run/run.zig");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();
    const allocator = arena.allocator();

    var options = run.Options{};

    var arg_it = try std.process.argsWithAllocator(allocator);
    _ = arg_it.next() orelse unreachable;
    var file_name: ?[]const u8 = null;
    while (arg_it.next()) |arg| {
        if (!options.trySet(arg) and arg[0] != '-') {
            file_name = arg;
        }
    }

    if (file_name) |f| {
        const file = try std.fs.cwd().openFile(f, .{});
        defer file.close();
        try run.runFile(allocator, options, file, stdin, stdout);
    } else {
        try run.startRepl(allocator, options, stdin, stdout, null);
    }
}

test {
    std.testing.refAllDecls(@This());
}
