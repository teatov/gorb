const std = @import("std");
const lexer = @import("../lexer/lexer.zig");
const token = @import("../token/token.zig");
const ast = @import("../ast/ast.zig");

pub const Parser = struct {
    lexer: *lexer.Lexer,
    errors: std.ArrayList([]const u8),

    cur_token: token.Token = undefined,
    peek_token: token.Token = undefined,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator, l: *lexer.Lexer) Parser {
        var parser = Parser{
            .lexer = l,
            .errors = std.ArrayList([]const u8).init(allocator),
            .allocator = allocator,
        };

        parser.nextToken();
        parser.nextToken();

        return parser;
    }

    pub fn parseProgram(self: *Self) !ast.Node {
        const program = try ast.Program.init(self.allocator);
        var statements = std.ArrayList(ast.Node).init(self.allocator);

        while (!self.curTokenIs(.eof)) {
            const stmt = try self.parseStatement();
            try statements.append(stmt);
            self.nextToken();
        }

        program.statements = statements.items;

        return .{ .program = program };
    }

    // statements

    fn parseStatement(self: *Self) !ast.Node {
        return switch (self.cur_token.type) {
            .@"return" => try self.parseReturnStatement(),
            .declaration => try self.parseDeclarationStatement(),
            else => try self.parseExpressionStatement(),
        };
    }

    fn parseReturnStatement(self: *Self) !ast.Node {
        const stmt = try ast.Return.init(self.allocator);
        stmt.token = self.cur_token;

        self.nextToken();

        stmt.return_value = try self.parseExpression(.lowest);

        while (self.peekTokenIs(.semicolon)) {
            self.nextToken();
        }

        return .{ .@"return" = stmt };
    }

    fn parseDeclarationStatement(self: *Self) !ast.Node {
        const stmt = try ast.Declaration.init(self.allocator);
        stmt.token = self.cur_token;

        try self.expectPeek(.identifier);

        const identifier = try ast.Identifier.init(self.allocator);
        identifier.token = self.cur_token;
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
        var statements = std.ArrayList(ast.Node).init(self.allocator);

        self.nextToken();

        while (!self.curTokenIs(.brace_close) and !self.curTokenIs(.eof)) {
            const stmt = try self.parseStatement();
            try statements.append(stmt);
            self.nextToken();
        }

        block.statements = statements.items;

        return .{ .block = block };
    }

    // expressions

    fn parseExpression(self: *Self, precedence: Precedence) Error!ast.Node {
        var expr: ast.Node = switch (self.cur_token.type) {
            .paren_open => try self.parseGroupedExpression(),
            .@"if" => try self.parseIfExpression(),
            .bang => try self.parseUnaryExpression(),
            .minus => try self.parseUnaryExpression(),
            .function => try self.parseFunctionLiteral(),
            .identifier => try self.parseIdentifier(),
            .true => try self.parseBooleanLiteral(),
            .false => try self.parseBooleanLiteral(),
            .integer => try self.parseIntegerLiteral(),
            .string => try self.parseStringLiteral(),
            .bracket_open => try self.parseArrayLiteral(),
            .brace_open => try self.parseHashLiteral(),
            else => {
                self.noUnaryParseFnError(self.cur_token);
                return Error.NoUnaryParseFn;
            },
        };

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

        try self.expectPeek(.paren_close);

        return node;
    }

    fn parseIndexExpression(self: *Self, left: ast.Node) !ast.Node {
        const expr = try ast.Index.init(self.allocator);
        expr.token = self.cur_token;
        expr.left = left;

        self.nextToken();
        expr.index = try self.parseExpression(.lowest);

        try self.expectPeek(.bracket_close);

        return .{ .index = expr };
    }

    fn parseCallExpression(self: *Self, function: ast.Node) !ast.Node {
        const expr = try ast.Call.init(self.allocator);
        expr.token = self.cur_token;
        expr.function = function;
        expr.arguments = try self.parseExpressionList(.paren_close);

        return .{ .call = expr };
    }

    fn parseIfExpression(self: *Self) !ast.Node {
        const expr = try ast.If.init(self.allocator);
        expr.token = self.cur_token;

        try self.expectPeek(.paren_open);

        self.nextToken();
        expr.condition = try self.parseExpression(.lowest);

        try self.expectPeek(.paren_close);

        try self.expectPeek(.brace_open);

        expr.consequence = (try self.parseBlockStatement()).block;

        if (self.peekTokenIs(.@"else")) {
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
        expr.token = self.cur_token;
        expr.operator = self.cur_token;

        self.nextToken();

        expr.right = try self.parseExpression(.unary);

        return .{ .unary_operation = expr };
    }

    fn parseBinaryExpression(self: *Self, left: ast.Node) !ast.Node {
        const expr = try ast.BinaryOperation.init(self.allocator);
        expr.token = self.cur_token;
        expr.operator = self.cur_token;
        expr.left = left;

        const precedence = self.curPrecedence();
        self.nextToken();
        expr.right = try self.parseExpression(precedence);

        return .{ .binary_operation = expr };
    }

    fn parseExpressionList(self: *Self, end: token.TokenType) ![]ast.Node {
        var list = std.ArrayList(ast.Node).init(self.allocator);

        if (self.peekTokenIs(end)) {
            self.nextToken();
            return list.items;
        }

        self.nextToken();
        try list.append(try self.parseExpression(.lowest));

        while (self.peekTokenIs(.comma)) {
            self.nextToken();
            self.nextToken();
            try list.append(try self.parseExpression(.lowest));
        }

        try self.expectPeek(end);

        return list.items;
    }

    // literals

    fn parseIdentifier(self: *Self) !ast.Node {
        const identifier = try ast.Identifier.init(self.allocator);
        identifier.token = self.cur_token;
        identifier.value = self.cur_token.literal;
        return .{ .identifier = identifier };
    }

    fn parseBooleanLiteral(self: *Self) !ast.Node {
        const boolean = try ast.BooleanLiteral.init(self.allocator);
        boolean.token = self.cur_token;
        boolean.value = self.curTokenIs(token.TokenType.true);
        return .{ .boolean_literal = boolean };
    }

    fn parseIntegerLiteral(self: *Self) !ast.Node {
        const integer = try ast.IntegerLiteral.init(self.allocator);
        integer.token = self.cur_token;
        integer.value = try std.fmt.parseInt(i32, self.cur_token.literal, 10);
        return .{ .integer_literal = integer };
    }

    fn parseStringLiteral(self: *Self) !ast.Node {
        const string = try ast.StringLiteral.init(self.allocator);
        string.token = self.cur_token;
        string.value = self.cur_token.literal;
        return .{ .string_literal = string };
    }

    fn parseArrayLiteral(self: *Self) !ast.Node {
        const array = try ast.ArrayLiteral.init(self.allocator);
        array.token = self.cur_token;
        array.elements = try self.parseExpressionList(.bracket_close);
        return .{ .array_literal = array };
    }

    fn parseHashLiteral(self: *Self) !ast.Node {
        const hash = try ast.HashLiteral.init(self.allocator);
        hash.token = self.cur_token;
        var pairs = std.AutoHashMap(ast.Node, ast.Node).init(self.allocator);

        while (!self.peekTokenIs(.brace_close)) {
            self.nextToken();
            const key = try self.parseExpression(.lowest);

            try self.expectPeek(.colon);

            self.nextToken();
            const value = try self.parseExpression(.lowest);

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
        function.token = self.cur_token;

        try self.expectPeek(.paren_open);

        function.parameters = try self.parseFunctionParameters();

        try self.expectPeek(.brace_open);

        function.body = (try self.parseBlockStatement()).block;

        return .{ .function_literal = function };
    }

    fn parseFunctionParameters(self: *Self) ![]*ast.Identifier {
        var identifiers = std.ArrayList(*ast.Identifier).init(self.allocator);

        if (self.peekTokenIs(.paren_close)) {
            self.nextToken();
            return identifiers.items;
        }

        self.nextToken();

        const identifier = try ast.Identifier.init(self.allocator);
        identifier.token = self.cur_token;
        identifier.value = self.cur_token.literal;
        try identifiers.append(identifier);

        while (self.peekTokenIs(.comma)) {
            self.nextToken();
            self.nextToken();

            const ident = try ast.Identifier.init(self.allocator);
            ident.token = self.cur_token;
            ident.value = self.cur_token.literal;
            try identifiers.append(ident);
        }

        try self.expectPeek(.paren_close);

        return identifiers.items;
    }

    // helpers

    fn nextToken(self: *Self) void {
        self.cur_token = self.peek_token;
        self.peek_token = self.lexer.nextToken();
    }

    fn curTokenIs(self: *Self, tok_type: token.TokenType) bool {
        return self.cur_token.type == tok_type;
    }

    fn peekTokenIs(self: *Self, tok_type: token.TokenType) bool {
        return self.peek_token.type == tok_type;
    }

    fn expectPeek(self: *Self, tok_type: token.TokenType) !void {
        if (self.peekTokenIs(tok_type)) {
            self.nextToken();
        } else {
            self.expectPeekError(tok_type);
            return Error.UnexpectedPeekToken;
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

    fn getPrecedence(tok_type: token.TokenType) Precedence {
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

    pub const Error = error{
        UnexpectedPeekToken,
        NoUnaryParseFn,
        OutOfMemory,
        Overflow,
        InvalidCharacter,
    };

    fn newError(self: *Self, message: []const u8, error_name: []const u8, tok: token.Token) void {
        var lines = std.mem.splitScalar(u8, self.lexer.input, '\n');
        var line: ?[]const u8 = null;
        var i: u32 = 1;
        while (lines.next()) |ln| : (i += 1) {
            if (i == tok.pos.ln) {
                line = ln;
                break;
            }
        }

        var pointer = std.ArrayList(u8).init(self.allocator);
        for (0..(tok.pos.col - 1)) |_| {
            _ = pointer.append(' ') catch null;
        }

        var pointer_width = tok.literal.len;

        if (pointer_width == 0) {
            pointer_width = 1;
        }

        if (tok.type == .string) {
            pointer_width += 2;
        }

        for (0..(pointer_width)) |_| {
            _ = pointer.append('^') catch null;
        }
        _ = pointer.appendSlice(" here") catch null;

        const msg = std.fmt.allocPrint(
            self.allocator,
            "{s}: {s}\n{s}\n{s}\n",
            .{
                tok.pos.string(self.allocator),
                message,
                line orelse "???",
                pointer.items,
            },
        ) catch |err| {
            std.debug.print("{s} {s}", .{ error_name, @errorName(err) });
            return;
        };
        self.errors.append(msg) catch |err| std.debug.print("{s} {s}", .{ error_name, @errorName(err) });
    }

    fn expectPeekError(self: *Self, tok_type: token.TokenType) void {
        const msg = std.fmt.allocPrint(
            self.allocator,
            "expected {s}, got {s}",
            .{
                tok_type.string(self.allocator),
                self.peek_token.string(self.allocator),
            },
        ) catch |err| {
            std.debug.print("expectPeekError {s}", .{@errorName(err)});
            return;
        };
        self.newError(msg, "expectPeekError", self.peek_token);
    }

    fn noUnaryParseFnError(self: *Self, tok: token.Token) void {
        const msg = std.fmt.allocPrint(
            self.allocator,
            "no unary parse function for {s} found",
            .{
                tok.string(self.allocator),
            },
        ) catch |err| {
            std.debug.print("noUnaryParseFnError {s}", .{@errorName(err)});
            return;
        };
        self.newError(msg, "noUnaryParseFnError", tok);
    }
};

const parser_test = @import("./parser_test.zig");

test {
    parser_test.hack();
}
