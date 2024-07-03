const std = @import("std");
const token = @import("./token.zig");
const lexer = @import("./lexer.zig");

pub fn hack() void {}

test "next token is correct" {
    const input =
        \\let five = 5;
        \\let ten = 10;
        \\
        \\let add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\let result = add(five, ten);
        \\!-/*5;
        \\5 < 10 > 5;
        \\
        \\if (5<10) {
        \\  return true;
        \\} else {
        \\  return false;
        \\}
        \\
        \\10 == 10;
        \\10 != 9;
        \\"foobar";
        \\"foo bar";
        \\"\n\r\t\\\"";
        \\[1, 2];
        \\{"foo": "bar"};
    ;

    const tests = [_]struct { type: token.TokenType, literal: []const u8 }{
        .{ .type = .declaration, .literal = "let" },
        .{ .type = .identifier, .literal = "five" },
        .{ .type = .assign, .literal = "=" },
        .{ .type = .integer, .literal = "5" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .declaration, .literal = "let" },
        .{ .type = .identifier, .literal = "ten" },
        .{ .type = .assign, .literal = "=" },
        .{ .type = .integer, .literal = "10" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .declaration, .literal = "let" },
        .{ .type = .identifier, .literal = "add" },
        .{ .type = .assign, .literal = "=" },
        .{ .type = .function, .literal = "fn" },
        .{ .type = .paren_open, .literal = "(" },
        .{ .type = .identifier, .literal = "x" },
        .{ .type = .comma, .literal = "," },
        .{ .type = .identifier, .literal = "y" },
        .{ .type = .paren_close, .literal = ")" },
        .{ .type = .brace_open, .literal = "{" },
        .{ .type = .identifier, .literal = "x" },
        .{ .type = .plus, .literal = "+" },
        .{ .type = .identifier, .literal = "y" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .brace_close, .literal = "}" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .declaration, .literal = "let" },
        .{ .type = .identifier, .literal = "result" },
        .{ .type = .assign, .literal = "=" },
        .{ .type = .identifier, .literal = "add" },
        .{ .type = .paren_open, .literal = "(" },
        .{ .type = .identifier, .literal = "five" },
        .{ .type = .comma, .literal = "," },
        .{ .type = .identifier, .literal = "ten" },
        .{ .type = .paren_close, .literal = ")" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .bang, .literal = "!" },
        .{ .type = .minus, .literal = "-" },
        .{ .type = .slash, .literal = "/" },
        .{ .type = .asterisk, .literal = "*" },
        .{ .type = .integer, .literal = "5" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .integer, .literal = "5" },
        .{ .type = .less_than, .literal = "<" },
        .{ .type = .integer, .literal = "10" },
        .{ .type = .greater_than, .literal = ">" },
        .{ .type = .integer, .literal = "5" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .@"if", .literal = "if" },
        .{ .type = .paren_open, .literal = "(" },
        .{ .type = .integer, .literal = "5" },
        .{ .type = .less_than, .literal = "<" },
        .{ .type = .integer, .literal = "10" },
        .{ .type = .paren_close, .literal = ")" },
        .{ .type = .brace_open, .literal = "{" },
        .{ .type = .@"return", .literal = "return" },
        .{ .type = .true, .literal = "true" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .brace_close, .literal = "}" },
        .{ .type = .@"else", .literal = "else" },
        .{ .type = .brace_open, .literal = "{" },
        .{ .type = .@"return", .literal = "return" },
        .{ .type = .false, .literal = "false" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .brace_close, .literal = "}" },
        .{ .type = .integer, .literal = "10" },
        .{ .type = .equals, .literal = "==" },
        .{ .type = .integer, .literal = "10" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .integer, .literal = "10" },
        .{ .type = .not_equals, .literal = "!=" },
        .{ .type = .integer, .literal = "9" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .string, .literal = "foobar" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .string, .literal = "foo bar" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .string, .literal = "\n\r\t\\\"" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .bracket_open, .literal = "[" },
        .{ .type = .integer, .literal = "1" },
        .{ .type = .comma, .literal = "," },
        .{ .type = .integer, .literal = "2" },
        .{ .type = .bracket_close, .literal = "]" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .brace_open, .literal = "{" },
        .{ .type = .string, .literal = "foo" },
        .{ .type = .colon, .literal = ":" },
        .{ .type = .string, .literal = "bar" },
        .{ .type = .brace_close, .literal = "}" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .eof, .literal = "" },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    var l = try lexer.Lexer.init(arena.allocator(), input);

    for (tests) |expected| {
        const tok = l.nextToken();
        try std.testing.expectEqual(expected.type, tok.type);
        try std.testing.expectEqualStrings(expected.literal, tok.literal);
    }
}
