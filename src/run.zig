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
) !void {
    const env = try object.Environment.init(allocator);

    const val = try run(allocator, options, out, input, file_path, env);

    if (@intFromEnum(val) == @intFromEnum(object.ObjectType.@"error")) {
        _ = try out.write(try val.inspect(allocator));
        _ = try out.write("\n");
    } else if (options.interactive) {
        try startRepl(allocator, options, out, env);
        return;
    }
    env.deinit();
}

pub fn startRepl(
    allocator: std.mem.Allocator,
    options: Options,
    out: std.fs.File.Writer,
    environment: ?*object.Environment,
) !void {
    const env = if (environment) |e| e else try object.Environment.init(
        allocator,
    );
    defer env.deinit();

    var ln = linenoise.Linenoise.init(allocator);
    defer ln.deinit();

    var lines = std.ArrayList([]const u8).init(allocator);
    while (ln.linenoise("> ") catch |err| if (err == error.CtrlC) null else return err) |line| {
        try lines.append(line);
        if (std.mem.eql(u8, line, "exit")) {
            break;
        }

        const val = try run(allocator, options, out, line, null, env);

        _ = try out.write(try val.inspect(allocator));
        _ = try out.write("\n");
        try ln.history.add(line);
    }

    for (lines.items) |item| allocator.free(item);
    lines.deinit();
    _ = try out.write("\n");
}

fn run(
    // allocator: std.mem.Allocator,
    // options: Options,
    // out: std.fs.File.Writer,
    // input: []const u8,
    // file_path: ?[]const u8,
    // env: *object.Environment,
    allocator: std.mem.Allocator,
    options: Options,
    out: std.fs.File.Writer,
    input: []const u8,
    file_path: ?[]const u8,
    _: *object.Environment,
) !object.Object {
    var l = try lexer.Lexer.init(allocator, input, file_path);

    var p = parser.Parser.init(allocator, &l);

    const program = p.parseProgram(options.debug_tokents) catch |err| {
        if (err == parser.Parser.Error.OutOfMemory) {
            return err;
        } else {
            for (p.errors.items) |parse_err| {
                _ = try out.write(parse_err);
                _ = try out.write("\n");
            }
            return .null;
        }
    };
    defer program.deinit(allocator);

    if (options.debug_ast) {
        _ = try out.write("AST: ");
        const program_string = try program.print(allocator);
        _ = try out.write(program_string);
        _ = try out.write("\n");
        allocator.free(program_string);
    }

    // var e = evaluator.Evaluator.init(allocator);

    // return try e.eval(program, env);
    return object.Object.null;
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
