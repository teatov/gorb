const std = @import("std");
const Token = @import("../Token.zig");
const Lexer = @import("../Lexer.zig");

test "next token is correct" {
    const input =
        \\so five = 5;
        \\so ten = 10;
        \\
        \\so add = fn(x, y) {
        \\  x + y;
        \\};
        \\
        \\so result = add(five, ten);
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

    const tests = [_]struct { type: Token.TokenType, literal: []const u8 }{
        .{ .type = .kw_declaration, .literal = "so" },
        .{ .type = .identifier, .literal = "five" },
        .{ .type = .assign, .literal = "=" },
        .{ .type = .integer, .literal = "5" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .kw_declaration, .literal = "so" },
        .{ .type = .identifier, .literal = "ten" },
        .{ .type = .assign, .literal = "=" },
        .{ .type = .integer, .literal = "10" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .kw_declaration, .literal = "so" },
        .{ .type = .identifier, .literal = "add" },
        .{ .type = .assign, .literal = "=" },
        .{ .type = .kw_function, .literal = "fn" },
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
        .{ .type = .kw_declaration, .literal = "so" },
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
        .{ .type = .kw_if, .literal = "if" },
        .{ .type = .paren_open, .literal = "(" },
        .{ .type = .integer, .literal = "5" },
        .{ .type = .less_than, .literal = "<" },
        .{ .type = .integer, .literal = "10" },
        .{ .type = .paren_close, .literal = ")" },
        .{ .type = .brace_open, .literal = "{" },
        .{ .type = .kw_return, .literal = "return" },
        .{ .type = .kw_true, .literal = "true" },
        .{ .type = .semicolon, .literal = ";" },
        .{ .type = .brace_close, .literal = "}" },
        .{ .type = .kw_else, .literal = "else" },
        .{ .type = .brace_open, .literal = "{" },
        .{ .type = .kw_return, .literal = "return" },
        .{ .type = .kw_false, .literal = "false" },
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
    var l = try Lexer.init(arena.allocator(), input, null);

    for (tests) |expected| {
        const tok = try l.nextToken();
        try std.testing.expectEqual(expected.type, tok.type);
        try std.testing.expectEqualStrings(expected.literal, tok.literal);
    }
}
