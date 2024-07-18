const std = @import("std");

pub const Token = struct {
    type: TokenType,
    literal: []const u8,
    pos: Pos,
    line: []const u8,
    file_path: ?[]const u8,

    const Self = @This();

    pub fn print(
        self: Token,
        allocator: std.mem.Allocator,
    ) []const u8 {
        return std.fmt.allocPrint(
            allocator,
            "[{s}: '{s}']",
            .{ @tagName(self.type), self.literal },
        ) catch |err| @errorName(err);
    }
};

pub const Pos = struct {
    ln: u32,
    col: u32,

    pub fn print(
        self: Pos,
        allocator: std.mem.Allocator,
    ) []const u8 {
        return std.fmt.allocPrint(
            allocator,
            "{d}:{d}",
            .{ self.ln, self.col },
        ) catch |err| @errorName(err);
    }
};

pub const TokenType = enum {
    illegal,
    out_of_memory,
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
    kw_function,
    kw_declaration,
    kw_true,
    kw_false,
    kw_if,
    kw_else,
    kw_return,

    pub fn print(
        self: TokenType,
        allocator: std.mem.Allocator,
    ) []const u8 {
        return std.fmt.allocPrint(
            allocator,
            "[{s}]",
            .{@tagName(self)},
        ) catch |err| @errorName(err);
    }
};

pub const keywords = std.StaticStringMap(TokenType).initComptime(
    .{
        .{ "fn", .kw_function },
        .{ "so", .kw_declaration },
        .{ "true", .kw_true },
        .{ "false", .kw_false },
        .{ "if", .kw_if },
        .{ "else", .kw_else },
        .{ "return", .kw_return },
    },
);
