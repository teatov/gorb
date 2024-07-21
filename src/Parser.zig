const std = @import("std");
const Lexer = @import("./Lexer.zig");
const Token = @import("./Token.zig");
const ast = @import("./ast.zig");
const errors = @import("./errors.zig");
const object = @import("./object.zig");

lexer: Lexer,
errors: std.ArrayList([]const u8),

cur_token: Token = undefined,
peek_token: Token = undefined,

allocator: std.mem.Allocator,

const Self = @This();

pub fn init(
    allocator: std.mem.Allocator,
    l: Lexer,
) Self {
    var parser = Self{
        .lexer = l,
        .errors = std.ArrayList([]const u8).init(allocator),
        .allocator = allocator,
    };

    parser.nextToken();
    parser.nextToken();

    return parser;
}

pub fn deinit(self: *Self) void {
    for (self.errors.items) |err| self.allocator.free(err);
    self.errors.deinit();
}

pub fn parseProgram(self: *Self) !ast.Node {
    const program = try ast.Block.init(self.allocator);
    var statements = std.ArrayList(ast.Node).init(self.allocator);
    errdefer {
        for (statements.items) |stmt| stmt.deinit(self.allocator);
        statements.deinit();
        self.peek_token.deinit(self.allocator);
        self.allocator.destroy(program);
    }

    while (!self.curTokenIs(.eof)) {
        const stmt = try self.parseStatement();
        try statements.append(stmt);
        self.nextToken();
    }

    program.statements = try statements.toOwnedSlice();

    return .{ .block = program };
}

// statements

fn parseStatement(self: *Self) !ast.Node {
    return switch (self.cur_token.type) {
        .kw_return => try self.parseReturnStatement(),
        .kw_declaration => try self.parseDeclarationStatement(),
        else => try self.parseExpressionStatement(),
    };
}

fn parseReturnStatement(self: *Self) !ast.Node {
    const stmt = try ast.Return.init(self.allocator);
    errdefer self.allocator.destroy(stmt);
    stmt.tok = self.cur_token;

    self.nextToken();

    stmt.return_value = try self.parseExpression(.lowest);

    while (self.peekTokenIs(.semicolon)) {
        self.nextToken();
    }

    return .{ .@"return" = stmt };
}

fn parseDeclarationStatement(self: *Self) !ast.Node {
    const stmt = try ast.Declaration.init(self.allocator);
    errdefer self.allocator.destroy(stmt);
    stmt.tok = self.cur_token;

    try self.expectPeek(.identifier);

    const identifier = try ast.Identifier.init(self.allocator);
    errdefer self.allocator.destroy(identifier);
    identifier.tok = self.cur_token;
    identifier.value = self.cur_token.literal;

    stmt.name = identifier;

    try self.expectPeek(.assign);

    self.nextToken();

    stmt.value = try self.parseExpression(.lowest);

    while (self.peekTokenIs(.semicolon)) {
        self.nextToken();
    }

    return .{ .declaration = stmt };
}

fn parseExpressionStatement(self: *Self) !ast.Node {
    const node = self.parseExpression(.lowest);

    while (self.peekTokenIs(.semicolon)) {
        self.nextToken();
    }

    return node;
}

fn parseBlockStatement(self: *Self) !ast.Node {
    const block = try ast.Block.init(self.allocator);
    errdefer self.allocator.destroy(block);
    var statements = std.ArrayList(ast.Node).init(self.allocator);
    errdefer {
        for (statements.items) |stmt| stmt.deinit(self.allocator);
        statements.deinit();
    }

    self.nextToken();

    while (!self.curTokenIs(.brace_close)) {
        const stmt = try self.parseStatement();
        try statements.append(stmt);
        self.nextToken();
    }

    block.statements = try statements.toOwnedSlice();

    return .{ .block = block };
}

// expressions

fn parseExpression(
    self: *Self,
    precedence: Precedence,
) Error!ast.Node {
    var expr: ast.Node = switch (self.cur_token.type) {
        .paren_open => try self.parseGroupedExpression(),
        .kw_if => try self.parseIfExpression(),
        .bang => try self.parseUnaryExpression(),
        .minus => try self.parseUnaryExpression(),
        .kw_function => try self.parseFunctionLiteral(),
        .identifier => try self.parseIdentifier(),
        .kw_true => try self.parseBooleanLiteral(),
        .kw_false => try self.parseBooleanLiteral(),
        .integer => try self.parseIntegerLiteral(),
        .string => try self.parseStringLiteral(),
        .bracket_open => try self.parseArrayLiteral(),
        .brace_open => try self.parseHashLiteral(),
        else => {
            try self.noUnaryParseFnError(self.cur_token);
            return ParserError.NoUnaryParseFn;
        },
    };
    errdefer expr.deinit(self.allocator);

    while (!self.peekTokenIs(.semicolon) and @intFromEnum(precedence) < @intFromEnum(self.peekPrecedence())) {
        const tok_type = self.peek_token.type;
        self.nextToken();
        expr = switch (tok_type) {
            .bracket_open => try self.parseIndexExpression(expr),
            .paren_open => try self.parseCallExpression(expr),
            .plus => try self.parseBinaryExpression(expr),
            .minus => try self.parseBinaryExpression(expr),
            .slash => try self.parseBinaryExpression(expr),
            .asterisk => try self.parseBinaryExpression(expr),
            .equals => try self.parseBinaryExpression(expr),
            .not_equals => try self.parseBinaryExpression(expr),
            .less_than => try self.parseBinaryExpression(expr),
            .greater_than => try self.parseBinaryExpression(expr),
            else => return expr,
        };
    }

    return expr;
}

fn parseGroupedExpression(self: *Self) Error!ast.Node {
    self.nextToken();

    const node = try self.parseExpression(.lowest);
    errdefer node.deinit(self.allocator);

    try self.expectPeek(.paren_close);

    return node;
}

fn parseIndexExpression(self: *Self, left: ast.Node) !ast.Node {
    const expr = try ast.Index.init(self.allocator);
    errdefer self.allocator.destroy(expr);
    expr.tok = self.cur_token;
    expr.left = left;

    self.nextToken();
    expr.index = try self.parseExpression(.lowest);
    errdefer expr.index.deinit(self.allocator);

    try self.expectPeek(.bracket_close);

    return .{ .index = expr };
}

fn parseCallExpression(
    self: *Self,
    function: ast.Node,
) !ast.Node {
    const expr = try ast.Call.init(self.allocator);
    errdefer self.allocator.destroy(expr);
    expr.tok = self.cur_token;
    expr.function = function;
    expr.arguments = try self.parseExpressionList(.paren_close);

    return .{ .call = expr };
}

fn parseIfExpression(self: *Self) !ast.Node {
    const expr = try ast.If.init(self.allocator);
    errdefer self.allocator.destroy(expr);
    expr.tok = self.cur_token;

    try self.expectPeek(.paren_open);

    self.nextToken();
    expr.condition = try self.parseExpression(.lowest);
    errdefer expr.condition.deinit(self.allocator);

    try self.expectPeek(.paren_close);

    try self.expectPeek(.brace_open);

    expr.consequence = (try self.parseBlockStatement()).block;
    errdefer expr.consequence.deinit(self.allocator);

    if (self.peekTokenIs(.kw_else)) {
        self.nextToken();

        try self.expectPeek(.brace_open);

        expr.alternative = (try self.parseBlockStatement()).block;
    } else {
        expr.alternative = null;
    }

    return .{ .@"if" = expr };
}

fn parseUnaryExpression(self: *Self) !ast.Node {
    const expr = try ast.UnaryOperation.init(self.allocator);
    errdefer self.allocator.destroy(expr);
    expr.tok = self.cur_token;
    expr.operator = self.cur_token;

    self.nextToken();

    expr.right = try self.parseExpression(.unary);

    return .{ .unary_operation = expr };
}

fn parseBinaryExpression(
    self: *Self,
    left: ast.Node,
) !ast.Node {
    const expr = try ast.BinaryOperation.init(self.allocator);
    errdefer self.allocator.destroy(expr);
    expr.tok = self.cur_token;
    expr.operator = self.cur_token;
    expr.left = left;

    const precedence = self.curPrecedence();
    self.nextToken();
    expr.right = try self.parseExpression(precedence);

    return .{ .binary_operation = expr };
}

fn parseExpressionList(
    self: *Self,
    end: Token.TokenType,
) ![]ast.Node {
    var list = std.ArrayList(ast.Node).init(self.allocator);
    errdefer {
        for (list.items) |expr| expr.deinit(self.allocator);
        list.deinit();
    }

    if (self.peekTokenIs(end)) {
        self.nextToken();
        return try list.toOwnedSlice();
    }

    self.nextToken();
    try list.append(try self.parseExpression(.lowest));

    while (self.peekTokenIs(.comma)) {
        self.nextToken();
        self.nextToken();
        try list.append(try self.parseExpression(.lowest));
    }

    try self.expectPeek(end);

    return try list.toOwnedSlice();
}

// literals

fn parseIdentifier(self: *Self) !ast.Node {
    const identifier = try ast.Identifier.init(self.allocator);
    errdefer self.allocator.destroy(identifier);
    identifier.tok = self.cur_token;
    identifier.value = self.cur_token.literal;
    return .{ .identifier = identifier };
}

fn parseBooleanLiteral(self: *Self) !ast.Node {
    const boolean = try ast.BooleanLiteral.init(self.allocator);
    errdefer self.allocator.destroy(boolean);
    boolean.tok = self.cur_token;
    boolean.value = self.curTokenIs(Token.TokenType.kw_true);
    return .{ .boolean_literal = boolean };
}

fn parseIntegerLiteral(self: *Self) !ast.Node {
    const integer = try ast.IntegerLiteral.init(self.allocator);
    errdefer self.allocator.destroy(integer);
    integer.tok = self.cur_token;
    integer.value = try std.fmt.parseInt(
        object.Integer,
        self.cur_token.literal,
        10,
    );
    return .{ .integer_literal = integer };
}

fn parseStringLiteral(self: *Self) !ast.Node {
    const string = try ast.StringLiteral.init(self.allocator);
    errdefer self.allocator.destroy(string);
    string.tok = self.cur_token;
    string.value = self.cur_token.literal;
    return .{ .string_literal = string };
}

fn parseArrayLiteral(self: *Self) !ast.Node {
    const array = try ast.ArrayLiteral.init(self.allocator);
    errdefer self.allocator.destroy(array);
    array.tok = self.cur_token;
    array.elements = try self.parseExpressionList(
        .bracket_close,
    );
    return .{ .array_literal = array };
}

fn parseHashLiteral(self: *Self) !ast.Node {
    const hash = try ast.HashLiteral.init(self.allocator);
    errdefer self.allocator.destroy(hash);
    hash.tok = self.cur_token;
    var pairs = std.AutoHashMap(ast.Node, ast.Node).init(self.allocator);
    errdefer {
        var iterator = pairs.iterator();
        while (iterator.next()) |value| {
            value.key_ptr.deinit(self.allocator);
            value.value_ptr.deinit(self.allocator);
        }
        pairs.deinit();
    }

    while (!self.peekTokenIs(.brace_close)) {
        self.nextToken();
        const key = try self.parseExpression(.lowest);
        errdefer key.deinit(self.allocator);

        try self.expectPeek(.colon);

        self.nextToken();
        const value = try self.parseExpression(.lowest);
        errdefer value.deinit(self.allocator);

        try pairs.put(key, value);

        if (!self.peekTokenIs(.brace_close)) {
            try self.expectPeek(.comma);
        }
    }

    try self.expectPeek(.brace_close);

    hash.pairs = pairs;
    return .{ .hash_literal = hash };
}

fn parseFunctionLiteral(self: *Self) !ast.Node {
    const function = try ast.FunctionLiteral.init(self.allocator);
    errdefer self.allocator.destroy(function);
    function.tok = self.cur_token;

    try self.expectPeek(.paren_open);

    function.parameters = try self.parseFunctionParameters();
    errdefer {
        for (function.parameters) |param| param.deinit(self.allocator);
        self.allocator.free(function.parameters);
    }

    try self.expectPeek(.brace_open);

    function.body = (try self.parseBlockStatement()).block;

    return .{ .function_literal = function };
}

fn parseFunctionParameters(self: *Self) ![]*ast.Identifier {
    var identifiers = std.ArrayList(*ast.Identifier).init(self.allocator);
    errdefer {
        for (identifiers.items) |ident| ident.deinit(self.allocator);
        identifiers.deinit();
    }

    if (self.peekTokenIs(.paren_close)) {
        self.nextToken();
        return try identifiers.toOwnedSlice();
    }

    self.nextToken();

    const identifier = try ast.Identifier.init(self.allocator);
    identifier.tok = self.cur_token;
    identifier.value = self.cur_token.literal;
    try identifiers.append(identifier);

    while (self.peekTokenIs(.comma)) {
        self.nextToken();
        self.nextToken();

        const ident = try ast.Identifier.init(self.allocator);
        ident.tok = self.cur_token;
        ident.value = self.cur_token.literal;
        try identifiers.append(ident);
    }

    try self.expectPeek(.paren_close);

    return try identifiers.toOwnedSlice();
}

// helpers

fn nextToken(self: *Self) void {
    self.cur_token = self.peek_token;
    self.peek_token = self.lexer.nextToken() catch @panic("parser nextToken OOM");
}

fn curTokenIs(self: *Self, tok_type: Token.TokenType) bool {
    return self.cur_token.type == tok_type;
}

fn peekTokenIs(self: *Self, tok_type: Token.TokenType) bool {
    return self.peek_token.type == tok_type;
}

fn expectPeek(self: *Self, tok_type: Token.TokenType) !void {
    if (self.peekTokenIs(tok_type)) {
        self.nextToken();
    } else {
        try self.expectPeekError(tok_type);
        return ParserError.UnexpectedPeekToken;
    }
}

const Precedence = enum(u32) {
    lowest,
    equality,
    comparison,
    sum,
    product,
    unary,
    call,
    index,
};

fn getPrecedence(tok_type: Token.TokenType) Precedence {
    return switch (tok_type) {
        .equals => .equality,
        .not_equals => .equality,
        .less_than => .comparison,
        .greater_than => .comparison,
        .plus => .sum,
        .minus => .sum,
        .asterisk => .product,
        .slash => .product,
        .paren_open => .call,
        .bracket_open => .index,
        else => .lowest,
    };
}

fn peekPrecedence(self: *Self) Precedence {
    return getPrecedence(self.peek_token.type);
}

fn curPrecedence(self: *Self) Precedence {
    return getPrecedence(self.cur_token.type);
}

// errors

const Error = error{
    OutOfMemory,
    Overflow,
    InvalidCharacter,
} || ParserError;

pub const ParserError = error{
    UnexpectedPeekToken,
    NoUnaryParseFn,
};

fn newParserError(
    self: *Self,
    msg: []const u8,
    tok: Token,
) !void {
    defer self.allocator.free(msg);
    const message = errors.formatError(self.allocator, msg, tok);
    try self.errors.append(message);
}

fn expectPeekError(
    self: *Self,
    tok_type: Token.TokenType,
) !void {
    const tok_text = tok_type.fmt(self.allocator);
    const peek_tok_text = self.peek_token.fmt(self.allocator);
    defer self.allocator.free(tok_text);
    defer self.allocator.free(peek_tok_text);
    const msg = try std.fmt.allocPrint(
        self.allocator,
        "expected {s}, got {s}",
        .{
            tok_text,
            peek_tok_text,
        },
    );
    try self.newParserError(msg, self.peek_token);
}

fn noUnaryParseFnError(self: *Self, tok: Token) !void {
    const tok_text = tok.fmt(self.allocator);
    defer self.allocator.free(tok_text);
    const msg = try std.fmt.allocPrint(
        self.allocator,
        "no unary parse function for {s} found",
        .{
            tok_text,
        },
    );
    try self.newParserError(msg, tok);
}

test {
    _ = @import("./tests/parser_test.zig");
}
