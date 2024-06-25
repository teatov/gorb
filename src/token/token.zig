const std = @import("std");

pub const Token = struct {
    type: TokenType,
    literal: []const u8,
    pos: Pos,
    pub fn string(self: Token, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "({s} {s} {s})\n",
            .{ @tagName(self.type), self.literal, try self.pos.string(allocator) },
        );
    }
};

pub const Pos = struct {
    ln: u32,
    col: u32,
    pub fn string(self: Pos, allocator: std.mem.Allocator) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "{d}:{d}", .{ self.ln, self.col });
    }
};

pub const TokenType = enum {
    illegal,
    eof,

    // identifiers and literals
    identifier,
    integer,
    string,

    // operators
    assign,
    plus,
    minus,
    asterisk,
    slash,
    bang,
    less_than,
    greater_than,
    equals,
    not_equals,

    // delimiters
    comma,
    colon,
    semicolon,
    paren_open,
    paren_close,
    brace_open,
    brace_close,
    bracket_open,
    bracket_close,

    // keywords
    function,
    declaration,
    true,
    false,
    @"if",
    @"else",
    @"return",
};

const Keyword = enum {
    @"fn",
    let,
    true,
    false,
    @"if",
    @"else",
    @"return",
};

pub fn lookupIdentifier(identifier: []const u8) TokenType {
    if (std.meta.stringToEnum(Keyword, identifier)) |keyword| {
        return switch (keyword) {
            .@"fn" => .function,
            .let => .declaration,
            .true => .true,
            .false => .false,
            .@"if" => .@"if",
            .@"else" => .@"else",
            .@"return" => .@"return",
        };
    } else {
        return .identifier;
    }
}
