const std = @import("std");
const run = @import("./run.zig");

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
    var command: ?[]const u8 = null;
    while (arg_it.next()) |arg| {
        options.trySet(arg);
        if (arg[0] != '-' and command == null) {
            command = arg;
        }
    }

    if (command == null) {
        try stdout.writeAll("welcome to gorb.\n");
        try run.startRepl(allocator, options, stdout, stderr, null);
        return;
    }

    if (command) |comm| {
        const is_command = try runCommand(stdout, comm);
        if (is_command) {
            return;
        }
    }

    if (command) |file_path| {
        if (!std.mem.eql(u8, std.fs.path.extension(file_path), ".gorb")) {
            try stderr.print("file must have a .gorb extension\n", .{});
            return;
        }

        const file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            if (err == std.fs.File.OpenError.FileNotFound) {
                try stderr.print("file '{s}' not found\n", .{file_path});
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
                try stderr.print("'{s}' is a directory and not a file\n", .{file_path});
                return;
            }
            return err;
        };
        // defer allocator.free(input);

        try run.runFile(allocator, options, input, file_path, stdout, stderr);
    }
}

fn runCommand(out: std.fs.File.Writer, command: []const u8) !bool {
    if (std.mem.eql(u8, command, "version")) {
        try out.print("gorb {s}\n", .{version});
        return true;
    }

    if (std.mem.eql(u8, command, "help")) {
        try out.writeAll(help);
        try out.writeAll("\n");
        return true;
    }

    if (std.mem.eql(u8, command, "zen")) {
        try out.writeAll(zen);
        try out.writeAll("\n");
        return true;
    }

    return false;
}

const version = "0.0.1";

const zen = "ᗜˬᗜ не будь злись не бесись не кричись";

const help =
    \\usage: gorb [command | file path] [options]
    \\you can omit the command to start a repl
    \\
    \\commands:
    \\  version           print version info
    \\  help              print this
    \\
    \\options:
    \\  -i, --interactive execute the file and start a repl with it's environment
    \\  -t, --tokens      enable debug token information
    \\  -a, --ast         enable debug ast information
;

test {
    std.testing.refAllDecls(@This());
}
