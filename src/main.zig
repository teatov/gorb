const std = @import("std");
const run = @import("./run.zig");

const version = "0.0.1";

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

    if (options.version) {
        _ = try stdout.write("gorb ");
        _ = try stdout.write(version);
        _ = try stdout.write("\n");
        return;
    }

    if (options.help) {
        _ = try stdout.write(help);
        _ = try stdout.write("\n");
        return;
    }

    if (file_name) |f| {
        const file = std.fs.cwd().openFile(f, .{}) catch |err| {
            if (err == std.fs.File.OpenError.FileNotFound) {
                try stdout.print("file '{s}' not found\n", .{f});
                return;
            }
            return err;
        };
        defer file.close();

        const input = file.readToEndAlloc(
            allocator,
            std.math.maxInt(usize),
        ) catch |err| {
            if (err == std.fs.File.OpenError.IsDir) {
                try stdout.print("'{s}' is a directory and not a file\n", .{f});
                return;
            }
            return err;
        };

        try run.runFile(allocator, options, input, f, stdin, stdout);
    } else {
        _ = try stdout.write("welcome to gorb.\n");
        try run.startRepl(allocator, options, stdin, stdout, null);
    }
}

const help =
    \\usage: gorb [options] [file path]
    \\you can omit the file path to start a repl
    \\
    \\options:
    \\  -i, --interactive execute the file and start a repl with it's environment
    \\  -t, --tokens      enable debug token information
    \\  -a, --ast         enable debug ast information
    \\  -v, --version     print version
    \\  -h, --help        print this
;

test {
    std.testing.refAllDecls(@This());
}
