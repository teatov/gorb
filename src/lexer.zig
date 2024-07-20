const std = @import("std");
const Token = @import("./Token.zig");

pub const Lexer = struct {
    input: []const u8,

    offset: u32 = 0,
    read_offset: u32 = 0,
    ch: u8 = 0,
    pos: Token.Pos = .{ .ln = 1, .col = 0 },
    lines_it: std.mem.SplitIterator(u8, .scalar),
    file_path: ?[]const u8,

    finished: bool = false,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        input: []const u8,
        file_path: ?[]const u8,
    ) !Lexer {
        var lexer = Lexer{
            .input = input,
            .allocator = allocator,
            .lines_it = std.mem.splitScalar(u8, input, '\n'),
            .file_path = file_path,
        };
        lexer.readChar();
        return lexer;
    }

    pub fn next(self: *Self) !?Token {
        const tok = try self.nextToken();

        if (self.finished) {
            return null;
        }

        if (tok.type == .eof) {
            self.finished = true;
        }

        return tok;
    }

    pub fn nextToken(self: *Self) !Token {
        self.skipWhitespace();

        const tok: Token = switch (self.ch) {
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
                        .line = self.nthLine(pos.ln),
                        .file_path = self.file_path,
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
                        .line = self.nthLine(pos.ln),
                        .file_path = self.file_path,
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
                    .line = self.nthLine(pos.ln),
                    .file_path = self.file_path,
                };
            },
            '_', 'a'...'z', 'A'...'Z' => blk: {
                const pos = self.pos;
                const literal = self.readIdentifier();
                break :blk .{
                    .type = self.lookupIdentifier(literal),
                    .literal = literal,
                    .pos = pos,
                    .line = self.nthLine(pos.ln),
                    .file_path = self.file_path,
                };
            },
            '0'...'9' => blk: {
                const pos = self.pos;
                break :blk .{
                    .type = .integer,
                    .literal = self.readNumber(),
                    .pos = pos,
                    .line = self.nthLine(pos.ln),
                    .file_path = self.file_path,
                };
            },
            0 => self.newToken(.eof),
            else => self.newToken(.illegal),
        };

        return tok;
    }

    fn newToken(
        self: *Self,
        tok_type: Token.TokenType,
    ) Token {
        defer self.readChar();
        return .{
            .type = tok_type,
            .literal = self.input[self.offset..self.read_offset],
            .pos = self.pos,
            .line = self.nthLine(self.pos.ln),
            .file_path = self.file_path,
        };
    }

    fn readChar(self: *Self) void {
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

    fn skipWhitespace(self: *Self) void {
        while (std.ascii.isWhitespace(self.ch)) {
            self.readChar();
        }
    }

    fn peekChar(self: *Self) u8 {
        if (self.read_offset >= self.input.len) {
            return 0;
        } else {
            return self.input[self.read_offset];
        }
    }

    fn readString(self: *Self) ![]u8 {
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

        return try literal.toOwnedSlice();
    }

    fn readIdentifier(self: *Self) []const u8 {
        const start_offset = self.offset;
        while (std.ascii.isAlphabetic(self.ch) or self.ch == '_') {
            self.readChar();
        }
        return self.input[start_offset..self.offset];
    }

    fn readNumber(self: *Self) []const u8 {
        const start_offset = self.offset;
        while (std.ascii.isDigit(self.ch)) {
            self.readChar();
        }
        return self.input[start_offset..self.offset];
    }

    fn lookupIdentifier(_: *Self, identifier: []const u8) Token.TokenType {
        if (Token.keywords.get(identifier)) |keyword| {
            return keyword;
        } else {
            return .identifier;
        }
    }

    fn nthLine(self: *Self, ln: u32) []const u8 {
        self.lines_it.reset();
        var i: u32 = 1;
        while (self.lines_it.next()) |line| {
            if (i == ln) {
                return line;
            }
            i += 1;
        }
        unreachable;
    }
};

test {
    _ = @import("./tests/lexer_test.zig");
}
