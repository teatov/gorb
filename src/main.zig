const std = @import("std");
const run = @import("./run.zig");

const version = "0.0.1";

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const stderr = std.io.getStdErr().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var options = run.Options{};

    var arg_it = try std.process.argsWithAllocator(allocator);
    defer arg_it.deinit();
    _ = arg_it.next() orelse unreachable;
    var file_path: ?[]const u8 = null;
    while (arg_it.next()) |arg| {
        if (!options.trySet(arg) and arg[0] != '-') {
            file_path = arg;
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

    if (file_path) |f| {
        const file = std.fs.cwd().openFile(f, .{}) catch |err| {
            if (err == std.fs.File.OpenError.FileNotFound) {
                try stderr.print("file '{s}' not found\n", .{f});
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
                try stderr.print("'{s}' is a directory and not a file\n", .{f});
                return;
            }
            return err;
        };
        // defer allocator.free(input);

        try run.runFile(allocator, options, input, f, stdout, stderr);
    } else {
        _ = try stdout.write("welcome to gorb.\n");
        try run.startRepl(allocator, options, stdout, stderr, null);
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
