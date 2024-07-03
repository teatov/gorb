const std = @import("std");
const lexer = @import("../lexer/lexer.zig");
const parser = @import("../parser/parser.zig");
const ast = @import("../ast/ast.zig");
const object = @import("../object/object.zig");
const evaluator = @import("../evaluator/evaluator.zig");

pub fn startRepl(
    allocator: std.mem.Allocator,
    in: std.fs.File.Reader,
    out: std.fs.File.Writer,
    env: ?*object.Environment,
) !void {
    const environment = if (env) |e| e else try object.Environment.init(
        allocator,
    );

    while (true) {
        _ = try out.write("> ");
        const input = try in.readUntilDelimiterOrEofAlloc(
            allocator,
            '\n',
            8192,
        );

        if (input) |line_raw| {
            const line = std.mem.trim(u8, line_raw, "\r");

            if (std.mem.eql(u8, line, "exit")) {
                break;
            }

            const val = try run(allocator, out, line, environment);

            if (val) |v| {
                _ = try out.write(try v.inspect(allocator));
                _ = try out.write("\n");
            }
        } else {
            break;
        }
    }
    _ = try out.write("\n");
}

fn run(
    allocator: std.mem.Allocator,
    out: std.fs.File.Writer,
    input: []const u8,
    env: *object.Environment,
) !?object.Object {
    var l = lexer.Lexer.init(allocator, input);
    _ = try out.write("TOKENS: ");
    while (l.next()) |tok| {
        const tok_string = tok.string(allocator);
        _ = try out.write(tok_string);
        _ = try out.write(" ");
    }
    _ = try out.write("\n");
    l.reset();

    var p = parser.Parser.init(allocator, &l);

    const program = p.parseProgram() catch |err| {
        if (err == parser.Parser.Error.OutOfMemory) {
            return err;
        } else {
            for (p.errors.items) |parse_err| {
                _ = try out.write(parse_err);
                _ = try out.write("\n");
            }
            return null;
        }
    };

    _ = try out.write("AST: ");
    const program_string = try program.string(allocator);
    _ = try out.write(program_string);
    _ = try out.write("\n");

    var e = evaluator.Evaluator.init(allocator);

    return try e.eval(program, env);
}
