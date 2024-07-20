const std = @import("std");
const lexer = @import("./lexer.zig");
const parser = @import("./parser.zig");
const ast = @import("./ast.zig");
const object = @import("./object.zig");
const evaluator = @import("./evaluator.zig");
const linenoise = @import("linenoise");

pub fn runFile(
    allocator: std.mem.Allocator,
    options: Options,
    input: []const u8,
    file_path: []const u8,
    out: std.fs.File.Writer,
    errout: std.fs.File.Writer,
) !void {
    const env = try object.Environment.init(allocator);

    const val = try run(allocator, options, errout, input, file_path, env);

    if (@intFromEnum(val.obj) == @intFromEnum(object.ObjectType.@"error")) {
        const error_message = try val.obj.inspect(allocator);
        _ = try errout.write(error_message);
        _ = try errout.write("\n");
        // allocator.free(error_message);
    } else if (options.interactive) {
        try startRepl(allocator, options, out, errout, env);
        return;
    }
    // _ = val.obj.deref(allocator);
    // env.close();
    // val.program.deinit(allocator, true);
}

pub fn startRepl(
    allocator: std.mem.Allocator,
    options: Options,
    out: std.fs.File.Writer,
    errout: std.fs.File.Writer,
    environment: ?*object.Environment,
) !void {
    const env = if (environment) |e| e else try object.Environment.init(
        allocator,
    );
    // defer env.close();

    var ln = linenoise.Linenoise.init(allocator);
    // defer ln.deinit();

    var lines = std.ArrayList([]const u8).init(allocator);
    while (ln.linenoise("> ") catch |err| if (err == error.CtrlC) null else return err) |line| {
        try lines.append(line);
        if (std.mem.eql(u8, line, "exit")) {
            break;
        }

        const val = try run(allocator, options, errout, line, null, env);

        const val_string = try val.obj.inspect(allocator);
        _ = try out.write(val_string);
        _ = try out.write("\n");
        // allocator.free(val_string);
        try ln.history.add(line);
    }

    // for (lines.items) |item| allocator.free(item);
    // lines.deinit();
    _ = try out.write("\n");
}

const RunResult = struct {
    obj: object.Object,
    program: ast.Node,
};

fn run(
    allocator: std.mem.Allocator,
    options: Options,
    errout: std.fs.File.Writer,
    input: []const u8,
    file_path: ?[]const u8,
    env: *object.Environment,
) !RunResult {
    var l = try lexer.Lexer.init(allocator, input, file_path);

    var p = parser.Parser.init(allocator, &l);

    const program = p.parseProgram(options.debug_tokents) catch |err| {
        if (err == parser.Parser.Error.OutOfMemory) {
            return err;
        } else {
            for (p.errors.items) |parse_err| {
                _ = try errout.write(parse_err);
                _ = try errout.write("\n");
                // allocator.free(parse_err);
            }
            return error.ParserError;
        }
    };

    if (options.debug_ast) {
        std.debug.print("AST: ", .{});
        const program_string = try program.fmt(allocator);
        std.debug.print("{s}", .{program_string});
        std.debug.print("\n", .{});
        // allocator.free(program_string);
    }

    var e = evaluator.Evaluator.init(allocator);

    const obj = try e.eval(program, env);
    return .{ .obj = obj, .program = program };
}

pub const Options = struct {
    debug_tokents: bool = false,
    debug_ast: bool = false,
    interactive: bool = false,
    version: bool = false,
    help: bool = false,

    pub fn trySet(self: *Options, arg: []const u8) bool {
        var did_set = false;
        if (std.mem.eql(u8, arg, "--tokens") or checkFlag(arg, "t")) {
            self.debug_tokents = true;
            did_set = true;
        }
        if (std.mem.eql(u8, arg, "--ast") or checkFlag(arg, "a")) {
            self.debug_ast = true;
            did_set = true;
        }
        if (std.mem.eql(u8, arg, "--interactive") or checkFlag(arg, "i")) {
            self.interactive = true;
            did_set = true;
        }
        if (std.mem.eql(u8, arg, "--version") or checkFlag(arg, "v")) {
            self.version = true;
            did_set = true;
        }
        if (std.mem.eql(u8, arg, "--help") or checkFlag(arg, "h")) {
            self.help = true;
            did_set = true;
        }
        return did_set;
    }

    fn checkFlag(arg: []const u8, flag: []const u8) bool {
        return arg[0] == '-' and arg[1] != '-' and std.mem.containsAtLeast(
            u8,
            arg,
            1,
            flag,
        );
    }
};
