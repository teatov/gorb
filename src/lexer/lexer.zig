const std = @import("std");
const token = @import("../token/token.zig");

pub const Lexer = struct {
    input: []const u8,

    offset: u32 = 0,
    read_offset: u32 = 0,
    ch: u8 = 0,
    pos: token.Pos = .{ .ln = 1, .col = 0 },

    finished: bool = false,

    allocator: std.mem.Allocator,

    pub fn init(allocator: std.mem.Allocator, input: []const u8) Lexer {
        var lexer = Lexer{
            .input = input,
            .allocator = allocator,
        };
        lexer.readChar();
        return lexer;
    }

    pub fn reset(self: *Lexer) void {
        self.offset = 0;
        self.read_offset = 0;
        self.ch = 0;
        self.pos = .{ .ln = 1, .col = 0 };
        self.readChar();
    }

    pub fn next(self: *Lexer) ?token.Token {
        const tok = self.nextToken();

        if (self.finished) {
            return null;
        }

        if (tok.type == .eof) {
            self.finished = true;
        }

        return tok;
    }

    pub fn nextToken(self: *Lexer) token.Token {
        self.skipWhitespace();

        const tok: token.Token = switch (self.ch) {
            // operators
            '=' => blk: {
                if (self.peekChar() == '=') {
                    const start_offset = self.offset;
                    const pos = self.pos;
                    self.readChar();
                    self.readChar();
                    break :blk .{
                        .type = .equals,
                        .literal = self.input[start_offset..self.offset],
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
                    const start_offset = self.offset;
                    const pos = self.pos;
                    self.readChar();
                    self.readChar();
                    break :blk .{
                        .type = .not_equals,
                        .literal = self.input[start_offset..self.offset],
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
                const literal = self.readString() catch "OUT OF MEMORY!!!";
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

    fn newToken(self: *Lexer, tok_type: token.TokenType) token.Token {
        defer self.readChar();
        return .{
            .type = tok_type,
            .literal = self.input[self.offset..self.read_offset],
            .pos = self.pos,
        };
    }

    fn readChar(self: *Lexer) void {
        self.offset = self.read_offset;
        if (self.read_offset >= self.input.len) {
            self.ch = 0;
        } else {
            self.ch = self.input[self.read_offset];
            self.read_offset += 1;
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
        if (self.read_offset >= self.input.len) {
            return 0;
        } else {
            return self.input[self.read_offset];
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
        const start_offset = self.offset;
        while (std.ascii.isAlphabetic(self.ch)) {
            self.readChar();
        }
        return self.input[start_offset..self.offset];
    }

    fn readNumber(self: *Lexer) []const u8 {
        const start_offset = self.offset;
        while (std.ascii.isDigit(self.ch)) {
            self.readChar();
        }
        return self.input[start_offset..self.offset];
    }
};

const lexer_test = @import("./lexer_test.zig");

test {
    lexer_test.hack();
}
