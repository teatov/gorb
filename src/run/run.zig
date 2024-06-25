const std = @import("std");
const token = @import("../token/token.zig");
const lexer = @import("../lexer/lexer.zig");

pub const RunOptions = struct {
    main_alloc: std.mem.Allocator,
    lexer_alloc: std.mem.Allocator,
};

pub fn startRepl(options: RunOptions, in: std.fs.File.Reader, out: std.fs.File.Writer) !void {
    while (true) {
        const input = try in.readUntilDelimiterOrEofAlloc(options.main_alloc, '\n', 8192);

        if (input) |line_raw| {
            defer options.main_alloc.free(line_raw);
            const line = std.mem.trim(u8, line_raw, "\r");
            try run(options, out, line);
        } else {
            break;
        }
    }
}

fn run(options: RunOptions, out: std.fs.File.Writer, input: []const u8) !void {
    var l = lexer.Lexer.init(options.lexer_alloc, input);
    while (try l.next()) |tok| {
        const string = try tok.string(options.main_alloc);
        defer options.main_alloc.free(string);
        _ = try out.write(string);
    }
    try out.print("\n", .{});
}
