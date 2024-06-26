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

    pub fn parseProgram(self: *Parser) !ast.Node {
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

    fn parseStatement(self: *Parser) !ast.Node {
        return switch (self.cur_token.type) {
            .@"return" => try self.parseReturnStatement(),
            .declaration => try self.parseDeclarationStatement(),
            else => try self.parseExpressionStatement(),
        };
    }

    fn parseReturnStatement(self: *Parser) !ast.Node {
        const stmt = try ast.Return.init(self.allocator);
        stmt.token = self.cur_token;

        self.nextToken();

        stmt.return_value = try self.parseExpression(.lowest);

        while (self.peekTokenIs(.semicolon)) {
            self.nextToken();
        }

        return .{ .@"return" = stmt };
    }

    fn parseDeclarationStatement(self: *Parser) !ast.Node {
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

    fn parseExpressionStatement(self: *Parser) !ast.Node {
        const node = self.parseExpression(.lowest);

        while (self.peekTokenIs(.semicolon)) {
            self.nextToken();
        }

        return node;
    }

    fn parseBlockStatement(self: *Parser) !ast.Node {
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

    fn parseExpression(self: *Parser, precedence: Precedence) Error!ast.Node {
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
            // .brace_open => try self.parseHashLiteral(),
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

    fn parseGroupedExpression(self: *Parser) Error!ast.Node {
        self.nextToken();

        const node = try self.parseExpression(.lowest);

        try self.expectPeek(.paren_close);

        return node;
    }

    fn parseIndexExpression(self: *Parser, left: ast.Node) !ast.Node {
        const expr = try ast.Index.init(self.allocator);
        expr.token = self.cur_token;
        expr.left = left;

        self.nextToken();
        expr.index = try self.parseExpression(.lowest);

        try self.expectPeek(.bracket_close);

        return .{ .index = expr };
    }

    fn parseCallExpression(self: *Parser, function: ast.Node) !ast.Node {
        const expr = try ast.Call.init(self.allocator);
        expr.token = self.cur_token;
        expr.function = function;
        expr.arguments = try self.parseExpressionList(.paren_close);

        return .{ .call = expr };
    }

    fn parseIfExpression(self: *Parser) !ast.Node {
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

    fn parseUnaryExpression(self: *Parser) !ast.Node {
        const expr = try ast.UnaryOperation.init(self.allocator);
        expr.token = self.cur_token;
        expr.operator = self.cur_token;

        self.nextToken();

        expr.right = try self.parseExpression(.unary);

        return .{ .unary_operation = expr };
    }

    fn parseBinaryExpression(self: *Parser, left: ast.Node) !ast.Node {
        const expr = try ast.BinaryOperation.init(self.allocator);
        expr.token = self.cur_token;
        expr.operator = self.cur_token;
        expr.left = left;

        const precedence = self.curPrecedence();
        self.nextToken();
        expr.right = try self.parseExpression(precedence);

        return .{ .binary_operation = expr };
    }

    fn parseExpressionList(self: *Parser, end: token.TokenType) ![]ast.Node {
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

    fn parseIdentifier(self: *Parser) !ast.Node {
        const identifier = try ast.Identifier.init(self.allocator);
        identifier.token = self.cur_token;
        identifier.value = self.cur_token.literal;
        return .{ .identifier = identifier };
    }

    fn parseBooleanLiteral(self: *Parser) !ast.Node {
        const boolean = try ast.BooleanLiteral.init(self.allocator);
        boolean.token = self.cur_token;
        boolean.value = self.curTokenIs(token.TokenType.true);
        return .{ .boolean_literal = boolean };
    }

    fn parseIntegerLiteral(self: *Parser) !ast.Node {
        const integer = try ast.IntegerLiteral.init(self.allocator);
        integer.token = self.cur_token;
        integer.value = try std.fmt.parseInt(i32, self.cur_token.literal, 10);
        return .{ .integer_literal = integer };
    }

    fn parseStringLiteral(self: *Parser) !ast.Node {
        const string = try ast.StringLiteral.init(self.allocator);
        string.token = self.cur_token;
        string.value = self.cur_token.literal;
        return .{ .string_literal = string };
    }

    fn parseArrayLiteral(self: *Parser) !ast.Node {
        const array = try ast.ArrayLiteral.init(self.allocator);
        array.token = self.cur_token;
        array.elements = try self.parseExpressionList(.bracket_close);
        return .{ .array_literal = array };
    }

    fn parseFunctionLiteral(self: *Parser) !ast.Node {
        const function = try ast.FunctionLiteral.init(self.allocator);
        function.token = self.cur_token;

        try self.expectPeek(.paren_open);

        function.parameters = try self.parseFunctionParameters();

        try self.expectPeek(.brace_open);

        function.body = (try self.parseBlockStatement()).block;

        return .{ .function_literal = function };
    }

    fn parseFunctionParameters(self: *Parser) ![]*ast.Identifier {
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

    fn nextToken(self: *Parser) void {
        self.cur_token = self.peek_token;
        self.peek_token = self.lexer.nextToken();
    }

    fn curTokenIs(self: *Parser, tok_type: token.TokenType) bool {
        return self.cur_token.type == tok_type;
    }

    fn peekTokenIs(self: *Parser, tok_type: token.TokenType) bool {
        return self.peek_token.type == tok_type;
    }

    fn expectPeek(self: *Parser, tok_type: token.TokenType) !void {
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

    fn peekPrecedence(self: *Parser) Precedence {
        return getPrecedence(self.peek_token.type);
    }

    fn curPrecedence(self: *Parser) Precedence {
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

    fn newError(self: *Parser, message: []const u8, error_name: []const u8, tok: token.Token) void {
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
        for (0..(tok.literal.len)) |_| {
            _ = pointer.append('^') catch null;
        }
        _ = pointer.appendSlice(" here") catch null;

        const msg = std.fmt.allocPrint(
            self.allocator,
            "{s}: {s}\n{s}\n{s}\n",
            .{
                tok.pos.string(self.allocator) catch |err| @errorName(err),
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

    fn expectPeekError(self: *Parser, tok_type: token.TokenType) void {
        const msg = std.fmt.allocPrint(
            self.allocator,
            "expected `{s}`, got `{s}`",
            .{
                @tagName(tok_type),
                @tagName(self.peek_token.type),
            },
        ) catch |err| {
            std.debug.print("expectPeekError {s}", .{@errorName(err)});
            return;
        };
        self.newError(msg, "expectPeekError", self.peek_token);
    }

    fn noUnaryParseFnError(self: *Parser, tok: token.Token) void {
        const msg = std.fmt.allocPrint(
            self.allocator,
            "no unary parse function for `{s}` found",
            .{
                @tagName(tok.type),
            },
        ) catch |err| {
            std.debug.print("noUnaryParseFnError {s}", .{@errorName(err)});
            return;
        };
        self.newError(msg, "noUnaryParseFnError", tok);
    }
};
