const std = @import("std");
const token = @import("../token/token.zig");

pub const Lexer = struct {
    input: []const u8,
    offset: u32 = 0,
    readOffset: u32 = 0,
    ch: u8 = 0,
    pos: token.Pos = .{ .ln = 1, .col = 0 },
    allocator: std.mem.Allocator,
    finished: bool = false,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Lexer {
        var lexer = Lexer{
            .input = input,
            .allocator = allocator,
        };
        lexer.readChar();
        return lexer;
    }

    pub fn deinit(self: Lexer) void {
        self.allocator.free(self);
    }

    pub fn next(self: *Lexer) !?token.Token {
        const tok = try self.nextToken();

        if (self.finished) {
            return null;
        }

        if (tok.type == .eof) {
            self.finished = true;
        }

        return tok;
    }

    pub fn nextToken(self: *Lexer) !token.Token {
        self.skipWhitespace();

        const tok: token.Token = switch (self.ch) {
            // operators
            '=' => blk: {
                if (self.peekChar() == '=') {
                    const startOffset = self.offset;
                    const pos = self.pos;
                    self.readChar();
                    self.readChar();
                    break :blk .{
                        .type = .equals,
                        .literal = self.input[startOffset..self.offset],
                        .pos = pos,
                    };
                } else {
                    break :blk self.newToken(.assign);
                }
            },
            '+' => self.newToken(.plus),
            '-' => self.newToken(.minus),
            '!' => blk: {
                if (self.peekChar() == '=') {
                    const startOffset = self.offset;
                    const pos = self.pos;
                    self.readChar();
                    self.readChar();
                    break :blk .{
                        .type = .not_equals,
                        .literal = self.input[startOffset..self.offset],
                        .pos = pos,
                    };
                } else {
                    break :blk self.newToken(.bang);
                }
            },
            '*' => self.newToken(.asterisk),
            '/' => self.newToken(.slash),
            '<' => self.newToken(.less_than),
            '>' => self.newToken(.greater_than),

            // delitimers
            ',' => self.newToken(.comma),
            ':' => self.newToken(.colon),
            ';' => self.newToken(.semicolon),
            '(' => self.newToken(.paren_open),
            ')' => self.newToken(.paren_close),
            '{' => self.newToken(.brace_open),
            '}' => self.newToken(.brace_close),
            '[' => self.newToken(.bracket_open),
            ']' => self.newToken(.bracket_close),

            // identifiers and literals
            '"' => blk: {
                const pos = self.pos;
                const literal = try self.readString();
                break :blk .{
                    .type = .string,
                    .literal = literal,
                    .pos = pos,
                };
            },
            0 => self.newToken(.eof),
            else => blk: {
                const pos = self.pos;
                if (std.ascii.isAlphabetic(self.ch)) {
                    const literal = self.readIdentifier();
                    break :blk .{
                        .type = token.lookupIdentifier(literal),
                        .literal = literal,
                        .pos = pos,
                    };
                } else if (std.ascii.isDigit(self.ch)) {
                    break :blk .{
                        .type = .integer,
                        .literal = self.readNumber(),
                        .pos = pos,
                    };
                } else {
                    break :blk self.newToken(.illegal);
                }
            },
        };

        return tok;
    }

    fn newToken(self: *Lexer, tokenType: token.TokenType) token.Token {
        defer self.readChar();
        return .{
            .type = tokenType,
            .literal = self.input[self.offset..self.readOffset],
            .pos = self.pos,
        };
    }

    fn readChar(self: *Lexer) void {
        self.offset = self.readOffset;
        if (self.readOffset >= self.input.len) {
            self.ch = 0;
        } else {
            self.ch = self.input[self.readOffset];
            self.readOffset += 1;
        }

        if (self.ch == '\n') {
            self.pos.ln += 1;
            self.pos.col = 0;
        } else {
            self.pos.col += 1;
        }
    }

    fn skipWhitespace(self: *Lexer) void {
        while (std.ascii.isWhitespace(self.ch)) {
            self.readChar();
        }
    }

    fn peekChar(self: *Lexer) u8 {
        if (self.readOffset >= self.input.len) {
            return 0;
        } else {
            return self.input[self.readOffset];
        }
    }

    fn readString(self: *Lexer) ![]u8 {
        defer self.readChar();
        var literal = std.ArrayList(u8).init(self.allocator);

        while (true) {
            self.readChar();

            if (self.ch == '\\') {
                const escape: u8 = switch (self.peekChar()) {
                    'n' => '\n',
                    'r' => '\r',
                    't' => '\t',
                    '\\' => '\\',
                    '"' => '"',
                    else => 0,
                };

                if (escape != 0) {
                    try literal.append(escape);
                } else {
                    try literal.append(self.ch);
                    try literal.append(self.peekChar());
                }

                self.readChar();
                continue;
            }

            if (self.ch == '"' or self.ch == 0) {
                break;
            }

            try literal.append(self.ch);
        }

        return literal.items;
    }

    fn readIdentifier(self: *Lexer) []const u8 {
        const startOffset = self.offset;
        while (std.ascii.isAlphabetic(self.ch)) {
            self.readChar();
        }
        return self.input[startOffset..self.offset];
    }

    fn readNumber(self: *Lexer) []const u8 {
        const startOffset = self.offset;
        while (std.ascii.isDigit(self.ch)) {
            self.readChar();
        }
        return self.input[startOffset..self.offset];
    }
};

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
    var l = Lexer.init(arena.allocator(), input);

    for (tests) |expected| {
        const tok = try l.nextToken();
        try std.testing.expectEqual(expected.type, tok.type);
        try std.testing.expectEqualStrings(expected.literal, tok.literal);
    }
}
