const std = @import("std");
const lexer = @import("./lexer.zig");
const parser = @import("./parser.zig");
const ast = @import("./ast.zig");
const object = @import("./object.zig");
const evaluator = @import("./evaluator.zig");
const linenoise = @import("./linenoize/main.zig");

pub fn runFile(
    allocator: std.mem.Allocator,
    options: Options,
    input: []const u8,
    file: []const u8,
    out: std.fs.File.Writer,
) !void {
    const environment = try object.Environment.init(allocator);

    const val = try run(allocator, options, out, input, file, environment);

    if (@intFromEnum(val) == @intFromEnum(object.ObjectType.@"error")) {
        _ = try out.write(try val.inspect(allocator));
        _ = try out.write("\n");
    } else if (options.interactive) {
        try startRepl(allocator, options, out, environment);
    }
}

pub fn startRepl(
    allocator: std.mem.Allocator,
    options: Options,
    out: std.fs.File.Writer,
    env: ?*object.Environment,
) !void {
    const environment = if (env) |e| e else try object.Environment.init(
        allocator,
    );

    var ln = linenoise.Linenoise.init(allocator);
    defer ln.deinit();

    while (try ln.linenoise("> ")) |line| {
        if (std.mem.eql(u8, line, "exit")) {
            break;
        }

        const val = try run(allocator, options, out, line, null, environment);

        _ = try out.write(try val.inspect(allocator));
        _ = try out.write("\n");
        try ln.history.add(line);
    }
    _ = try out.write("\n");
}

fn run(
    allocator: std.mem.Allocator,
    options: Options,
    out: std.fs.File.Writer,
    input: []const u8,
    file: ?[]const u8,
    env: *object.Environment,
) !object.Object {
    var l = try lexer.Lexer.init(allocator, input, file);

    if (options.debug_tokents) {
        _ = try out.write("TOKENS: ");
        while (l.next()) |tok| {
            const tok_string = tok.string(allocator);
            _ = try out.write(tok_string);
            _ = try out.write(" ");
        }
        _ = try out.write("\n");
        l.reset();
    }

    var p = parser.Parser.init(allocator, &l);

    const program = p.parseProgram() catch |err| {
        if (err == parser.Parser.Error.OutOfMemory) {
            return err;
        } else {
            for (p.errors.items) |parse_err| {
                _ = try out.write(parse_err);
                _ = try out.write("\n");
            }
            return .{ .null = try object.Null.init(allocator) };
        }
    };

    if (options.debug_ast) {
        _ = try out.write("AST: ");
        const program_string = try program.string(allocator);
        _ = try out.write(program_string);
        _ = try out.write("\n");
    }

    var e = evaluator.Evaluator.init(allocator);

    return try e.eval(program, env);
}

pub const Options = struct {
    debug_tokents: bool = false,
    debug_ast: bool = false,
    interactive: bool = false,
    version: bool = false,
    help: bool = false,

    pub fn trySet(self: *Options, arg: []const u8) bool {
        if (std.mem.eql(u8, arg, "--tokens") or std.mem.eql(u8, arg, "-t")) {
            self.debug_tokents = true;
            return true;
        }
        if (std.mem.eql(u8, arg, "--ast") or std.mem.eql(u8, arg, "-a")) {
            self.debug_ast = true;
            return true;
        }
        if (std.mem.eql(u8, arg, "--interactive") or std.mem.eql(u8, arg, "-i")) {
            self.interactive = true;
            return true;
        }
        if (std.mem.eql(u8, arg, "--version") or std.mem.eql(u8, arg, "-v")) {
            self.version = true;
            return true;
        }
        if (std.mem.eql(u8, arg, "--help") or std.mem.eql(u8, arg, "-h")) {
            self.help = true;
            return true;
        }
        return false;
    }
};
