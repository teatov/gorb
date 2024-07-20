const std = @import("std");
const Lexer = @import("./Lexer.zig");
const parser = @import("./parser.zig");
const ast = @import("./ast.zig");
const object = @import("./object.zig");
const evaluator = @import("./evaluator.zig");
const linenoise = @import("linenoise");

pub fn runFile(
    allocator: std.mem.Allocator,
    options: RunOptions,
    input: []const u8,
    file_path: []const u8,
    out: std.fs.File.Writer,
    errout: std.fs.File.Writer,
) !void {
    // const env = try object.Environment.init(allocator);

    const val = try run(
        allocator,
        options,
        errout,
        input,
        file_path,
        // env,
    );

    if (val.obj == object.ObjectType.@"error") {
        const error_message = try val.obj.inspect(allocator);
        defer allocator.free(error_message);
        try errout.writeAll(error_message);
        try errout.writeAll("\n");
    } else if (options.interactive) {
        try startRepl(
            allocator,
            options,
            out,
            errout,
            // env,
        );
        return;
    }
}

pub fn startRepl(
    allocator: std.mem.Allocator,
    options: RunOptions,
    out: std.fs.File.Writer,
    errout: std.fs.File.Writer,
    // environment: ?*object.Environment,
) !void {
    // const env = if (environment) |e| e else try object.Environment.init(
    //     allocator,
    // );
    // defer env.close();

    var ln = linenoise.Linenoise.init(allocator);
    defer ln.deinit();

    var input = std.ArrayList([]const u8).init(allocator);
    defer input.deinit();
    defer for (input.items) |line| allocator.free(line);

    while (ln.linenoise("> ") catch |err| (if (err == error.CtrlC) null else return err)) |line| {
        try input.append(line);
        if (std.mem.eql(u8, line, "exit")) {
            break;
        }

        const val = try run(
            allocator,
            options,
            errout,
            line,
            null,
            // env,
        );

        const val_string = try val.obj.inspect(allocator);
        defer allocator.free(val_string);
        try out.writeAll(val_string);
        try out.writeAll("\n");
        try ln.history.add(line);
    }
}

const RunResult = struct {
    obj: object.Object,
    program: ast.Node,
};

// fn run(
//     allocator: std.mem.Allocator,
//     options: RunOptions,
//     errout: std.fs.File.Writer,
//     input: []const u8,
//     file_path: ?[]const u8,
//     env: *object.Environment,
// ) !RunResult {
fn run(
    allocator: std.mem.Allocator,
    options: RunOptions,
    _: std.fs.File.Writer,
    input: []const u8,
    file_path: ?[]const u8,
    // _: *object.Environment,
) !RunResult {
    var l = try Lexer.init(allocator, input, file_path);

    if (options.debug_tokents) {
        std.debug.print("TOKENS: ", .{});
        while (try l.next()) |tok| {
            const tok_string = tok.fmt(allocator);
            std.debug.print("{s} ", .{tok_string});
            allocator.free(tok_string);
            tok.deinit(allocator);
        }
        std.debug.print("\n", .{});
    }

    // var p = parser.Parser.init(allocator, &l);

    // const program = p.parseProgram() catch |err| {
    //     if (err == parser.Parser.Error.OutOfMemory) {
    //         return err;
    //     } else {
    //         for (p.errors.items) |parse_err| {
    //             try errout.writeAll(parse_err);
    //             try errout.writeAll("\n");
    //         }
    //         return error.ParserError;
    //     }
    // };

    // if (options.debug_ast) {
    //     std.debug.print("AST: ", .{});
    //     const program_string = try program.fmt(allocator);
    //     std.debug.print("{s}", .{program_string});
    //     std.debug.print("\n", .{});
    // allocator.free(program_string);
    // }

    // var e = evaluator.Evaluator.init(allocator);

    // const obj = try e.eval(program, env);
    // return .{ .obj = obj, .program = program };
    return .{ .obj = .null, .program = .nothing };
}

pub const RunOptions = struct {
    debug_tokents: bool = false,
    debug_ast: bool = false,
    interactive: bool = false,

    pub fn trySet(self: *RunOptions, arg: []const u8) void {
        if (std.mem.eql(u8, arg, "--tokens") or checkFlag(arg, "t")) {
            self.debug_tokents = true;
        }
        if (std.mem.eql(u8, arg, "--ast") or checkFlag(arg, "a")) {
            self.debug_ast = true;
        }
        if (std.mem.eql(u8, arg, "--interactive") or checkFlag(arg, "i")) {
            self.interactive = true;
        }
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
