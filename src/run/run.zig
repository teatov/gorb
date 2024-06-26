const std = @import("std");
const token = @import("../token/token.zig");
const lexer = @import("../lexer/lexer.zig");
const parser = @import("../parser/parser.zig");
const ast = @import("../ast/ast.zig");

pub const RunOptions = struct {
    main_alloc: std.mem.Allocator,
    mass_alloc: std.mem.Allocator,
};

pub fn startRepl(options: RunOptions, in: std.fs.File.Reader, out: std.fs.File.Writer) !void {
    while (true) {
        _ = try out.write("> ");
        const input = try in.readUntilDelimiterOrEofAlloc(options.main_alloc, '\n', 8192);

        if (input) |line_raw| {
            defer options.main_alloc.free(line_raw);
            const line = std.mem.trim(u8, line_raw, "\r");

            if (std.mem.eql(u8, line, "exit")) {
                break;
            }

            try run(options, out, line);
        } else {
            break;
        }
    }
    _ = try out.write("\n");
}

fn run(options: RunOptions, out: std.fs.File.Writer, input: []const u8) !void {
    var l = lexer.Lexer.init(options.mass_alloc, input);
    while (l.next()) |tok| {
        const tok_string = tok.string(options.mass_alloc);
        _ = try out.write(tok_string);
        _ = try out.write(" ");
    }
    _ = try out.write("\n");
    l.reset();

    var p = parser.Parser.init(options.mass_alloc, &l);

    const program = p.parseProgram() catch |err| {
        if (err == parser.Parser.Error.OutOfMemory) {
            return err;
        } else {
            for (p.errors.items) |parse_err| {
                _ = try out.write(parse_err);
                _ = try out.write("\n");
            }
            return;
        }
    };

    const program_string = try ast.Node.string(
        program,
        options.mass_alloc,
    );
    _ = try out.write(program_string);
    _ = try out.write("\n");
}
