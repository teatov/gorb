const std = @import("std");
const token = @import("../token.zig");
const lexer = @import("../lexer.zig");
const ast = @import("../ast.zig");
const parser = @import("../parser.zig");

pub fn hack() void {}

fn checkParserErrors(p: *parser.Parser) !void {
    const errors = p.errors.items;
    if (errors.len == 0) {
        return;
    }

    std.debug.print("parser has {d} errors", .{errors.len});
    for (errors) |err| {
        std.debug.print("{s}", .{err});
    }
    try std.testing.expect(false);
}

const PossibleValue = union(enum) {
    boolean: bool,
    integer: i32,
    string: []const u8,
};

fn testLiteralExpression(node: ast.Node, expected: PossibleValue) !void {
    switch (expected) {
        .boolean => |exp| try testBooleanLiteral(node, exp),
        .integer => |exp| try testIntegerLiteral(node, exp),
        .string => |exp| try testIdentifier(node, exp),
    }
}

fn testBooleanLiteral(node: ast.Node, expected: bool) !void {
    const expr = node.boolean_literal;

    try std.testing.expectEqual(expected, expr.value);
    try std.testing.expectEqualStrings(if (expected) "true" else "false", if (expr.value) "true" else "false");
}

fn testIntegerLiteral(node: ast.Node, expected: i32) !void {
    const expr = node.integer_literal;

    try std.testing.expectEqual(expected, expr.value);
    var buf: [256]u8 = undefined;
    const lit = try std.fmt.bufPrint(&buf, "{d}", .{expected});
    try std.testing.expectEqualStrings(lit, expr.token.literal);
}

fn testIdentifier(node: ast.Node, expected: []const u8) !void {
    const expr = node.identifier;

    try std.testing.expectEqualStrings(expected, expr.value);
    try std.testing.expectEqualStrings(expected, expr.token.literal);
}

fn testBinaryOperation(node: ast.Node, left: PossibleValue, operator: []const u8, right: PossibleValue) !void {
    const expr = node.binary_operation;

    try testLiteralExpression(expr.left, left);
    try std.testing.expectEqualStrings(operator, expr.operator.literal);
    try testLiteralExpression(expr.right, right);
}

fn init(allocator: std.mem.Allocator, input: []const u8) !ast.Node {
    var l = try lexer.Lexer.init(allocator, input, null);
    var p = parser.Parser.init(allocator, &l);
    const program = (try p.parseProgram()).program;
    try checkParserErrors(&p);

    try std.testing.expectEqual(1, program.statements.len);

    const node = program.statements[0];
    return node;
}

test "so statements" {
    const tests = [_]struct { input: []const u8, ident: []const u8, value: PossibleValue }{
        .{ .input = "so x = 5;", .ident = "x", .value = .{ .integer = 5 } },
        .{ .input = "so y = true;", .ident = "y", .value = .{ .boolean = true } },
        .{ .input = "so foobar = y;", .ident = "foobar", .value = .{ .string = "y" } },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const node = try init(arena.allocator(), expect.input);
        const expr = node.declaration;

        try std.testing.expectEqualStrings("so", expr.token.literal);
        try std.testing.expectEqualStrings(expect.ident, expr.name.value);
        try std.testing.expectEqualStrings(expect.ident, expr.name.token.literal);

        try testLiteralExpression(expr.value, expect.value);
    }
}

test "return statements" {
    const tests = [_]struct { input: []const u8, value: PossibleValue }{
        .{ .input = "return 5;", .value = .{ .integer = 5 } },
        .{ .input = "return true;", .value = .{ .boolean = true } },
        .{ .input = "return foobar;", .value = .{ .string = "foobar" } },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const node = try init(arena.allocator(), expect.input);
        const expr = node.@"return";

        try std.testing.expectEqualStrings("return", expr.token.literal);

        try testLiteralExpression(expr.return_value, expect.value);
    }
}

test "identifier" {
    const input = "foobar;";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.identifier;

    try std.testing.expectEqualStrings("foobar", expr.value);
    try std.testing.expectEqualStrings("foobar", expr.token.literal);
}

test "integer literal" {
    const input = "5;";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.integer_literal;

    try std.testing.expectEqual(5, expr.value);
    try std.testing.expectEqualStrings("5", expr.token.literal);
}

test "string literal" {
    const input = "\"hello world\";";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.string_literal;

    try std.testing.expectEqualStrings("hello world", expr.value);
    try std.testing.expectEqualStrings("hello world", expr.token.literal);
}

test "array literal" {
    const input = "[1, 2 * 2, 3 + 3]";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.array_literal;

    try std.testing.expectEqual(3, expr.elements.len);
    try testIntegerLiteral(expr.elements[0], 1);
    try testBinaryOperation(expr.elements[1], .{ .integer = 2 }, "*", .{ .integer = 2 });
    try testBinaryOperation(expr.elements[2], .{ .integer = 3 }, "+", .{ .integer = 3 });
}

test "empty array literal" {
    const input = "[]";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.array_literal;

    try std.testing.expectEqual(0, expr.elements.len);
}

test "empty hash literal" {
    const input = "{}";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.hash_literal;

    try std.testing.expectEqual(0, expr.pairs.count());
}

test "hash literal string keys" {
    const input = "{\"one\": 1, \"two\": 2, \"three\": 3}";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.hash_literal;

    const tests = [_]struct { key: []const u8, value: i32 }{
        .{ .key = "one", .value = 1 },
        .{ .key = "two", .value = 2 },
        .{ .key = "three", .value = 3 },
    };

    try std.testing.expectEqual(tests.len, expr.pairs.count());

    var iterator = expr.pairs.iterator();
    while (iterator.next()) |pair| {
        const literal = pair.key_ptr.string_literal.*;
        const expect = for (tests) |t| {
            if (std.mem.eql(u8, t.key, literal.value)) break t;
        } else null;

        try std.testing.expectEqualStrings(expect.?.key, literal.value);
        try testIntegerLiteral(pair.value_ptr.*, expect.?.value);
    }
}

test "hash literal boolean keys" {
    const input = "{true: 1, false: 2}";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.hash_literal;

    const tests = [_]struct { key: bool, value: i32 }{
        .{ .key = true, .value = 1 },
        .{ .key = false, .value = 2 },
    };

    try std.testing.expectEqual(tests.len, expr.pairs.count());

    var iterator = expr.pairs.iterator();
    while (iterator.next()) |pair| {
        const literal = pair.key_ptr.boolean_literal.*;
        const expect = for (tests) |t| {
            if (t.key == literal.value) break t;
        } else null;

        try std.testing.expectEqual(expect.?.key, literal.value);
        try testIntegerLiteral(pair.value_ptr.*, expect.?.value);
    }
}

test "hash literal integer keys" {
    const input = "{1: 1, 2: 2, 3: 3}";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.hash_literal;

    const tests = [_]struct { key: i32, value: i32 }{
        .{ .key = 1, .value = 1 },
        .{ .key = 2, .value = 2 },
        .{ .key = 3, .value = 3 },
    };

    try std.testing.expectEqual(tests.len, expr.pairs.count());

    var iterator = expr.pairs.iterator();
    while (iterator.next()) |pair| {
        const literal = pair.key_ptr.integer_literal.*;
        const expect = for (tests) |t| {
            if (t.key == literal.value) break t;
        } else null;

        try std.testing.expectEqual(expect.?.key, literal.value);
        try testIntegerLiteral(pair.value_ptr.*, expect.?.value);
    }
}

test "hash literal with expressions" {
    const input = "{\"one\": 0 + 1, \"two\": 10 - 8, \"three\": 15 / 5}";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.hash_literal;

    const tests = [_]struct { key: []const u8, left: i32, operator: []const u8, right: i32 }{
        .{ .key = "one", .left = 0, .operator = "+", .right = 1 },
        .{ .key = "two", .left = 10, .operator = "-", .right = 8 },
        .{ .key = "three", .left = 15, .operator = "/", .right = 5 },
    };

    try std.testing.expectEqual(tests.len, expr.pairs.count());

    var iterator = expr.pairs.iterator();
    while (iterator.next()) |pair| {
        const literal = pair.key_ptr.string_literal.*;
        const expect = for (tests) |t| {
            if (std.mem.eql(u8, t.key, literal.value)) break t;
        } else null;

        try std.testing.expectEqualStrings(expect.?.key, literal.value);
        try testBinaryOperation(pair.value_ptr.*, .{ .integer = expect.?.left }, expect.?.operator, .{ .integer = expect.?.right });
    }
}

test "unary operations" {
    const tests = [_]struct {
        input: []const u8,
        operator: []const u8,
        value: PossibleValue,
    }{
        .{ .input = "!5;", .operator = "!", .value = .{ .integer = 5 } },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const node = try init(arena.allocator(), expect.input);
        const expr = node.unary_operation;

        try std.testing.expectEqualStrings(expect.operator, expr.operator.literal);

        try testLiteralExpression(expr.right, expect.value);
    }
}

test "binary operations" {
    const tests = [_]struct {
        input: []const u8,
        left: PossibleValue,
        operator: []const u8,
        right: PossibleValue,
    }{
        .{ .input = "5 + 5;", .left = .{ .integer = 5 }, .operator = "+", .right = .{ .integer = 5 } },
        .{ .input = "5 - 5;", .left = .{ .integer = 5 }, .operator = "-", .right = .{ .integer = 5 } },
        .{ .input = "5 * 5;", .left = .{ .integer = 5 }, .operator = "*", .right = .{ .integer = 5 } },
        .{ .input = "5 / 5;", .left = .{ .integer = 5 }, .operator = "/", .right = .{ .integer = 5 } },
        .{ .input = "5 > 5;", .left = .{ .integer = 5 }, .operator = ">", .right = .{ .integer = 5 } },
        .{ .input = "5 < 5;", .left = .{ .integer = 5 }, .operator = "<", .right = .{ .integer = 5 } },
        .{ .input = "5 == 5;", .left = .{ .integer = 5 }, .operator = "==", .right = .{ .integer = 5 } },
        .{ .input = "5 != 5;", .left = .{ .integer = 5 }, .operator = "!=", .right = .{ .integer = 5 } },
        .{ .input = "foobar + barfoo;", .left = .{ .string = "foobar" }, .operator = "+", .right = .{ .string = "barfoo" } },
        .{ .input = "foobar - barfoo;", .left = .{ .string = "foobar" }, .operator = "-", .right = .{ .string = "barfoo" } },
        .{ .input = "foobar * barfoo;", .left = .{ .string = "foobar" }, .operator = "*", .right = .{ .string = "barfoo" } },
        .{ .input = "foobar / barfoo;", .left = .{ .string = "foobar" }, .operator = "/", .right = .{ .string = "barfoo" } },
        .{ .input = "foobar > barfoo;", .left = .{ .string = "foobar" }, .operator = ">", .right = .{ .string = "barfoo" } },
        .{ .input = "foobar < barfoo;", .left = .{ .string = "foobar" }, .operator = "<", .right = .{ .string = "barfoo" } },
        .{ .input = "foobar == barfoo;", .left = .{ .string = "foobar" }, .operator = "==", .right = .{ .string = "barfoo" } },
        .{ .input = "foobar != barfoo;", .left = .{ .string = "foobar" }, .operator = "!=", .right = .{ .string = "barfoo" } },
        .{ .input = "true == true;", .left = .{ .boolean = true }, .operator = "==", .right = .{ .boolean = true } },
        .{ .input = "true != false;", .left = .{ .boolean = true }, .operator = "!=", .right = .{ .boolean = false } },
        .{ .input = "false == false;", .left = .{ .boolean = false }, .operator = "==", .right = .{ .boolean = false } },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const node = try init(arena.allocator(), expect.input);

        try testBinaryOperation(node, expect.left, expect.operator, expect.right);
    }
}

test "operator precedence" {
    const tests = [_]struct {
        input: []const u8,
        expected: []const u8,
    }{
        .{ .input = "-a * b", .expected = "((-a) * b)" },
        .{ .input = "!-a", .expected = "(!(-a))" },
        .{ .input = "a + b + c", .expected = "((a + b) + c)" },
        .{ .input = "a + b - c", .expected = "((a + b) - c)" },
        .{ .input = "a * b * c", .expected = "((a * b) * c)" },
        .{ .input = "a * b / c", .expected = "((a * b) / c)" },
        .{ .input = "a + b / c", .expected = "(a + (b / c))" },
        .{ .input = "a + b * c + d / e - f", .expected = "(((a + (b * c)) + (d / e)) - f)" },
        .{ .input = "5 > 4 == 3 < 4", .expected = "((5 > 4) == (3 < 4))" },
        .{ .input = "5 < 4 != 3 > 4", .expected = "((5 < 4) != (3 > 4))" },
        .{ .input = "3 + 4 * 5 == 3 * 1 + 4 * 5", .expected = "((3 + (4 * 5)) == ((3 * 1) + (4 * 5)))" },
        .{ .input = "true", .expected = "true" },
        .{ .input = "false", .expected = "false" },
        .{ .input = "3 > 5 == false", .expected = "((3 > 5) == false)" },
        .{ .input = "3 < 5 == true", .expected = "((3 < 5) == true)" },
        .{ .input = "1 + (2 + 3) + 4", .expected = "((1 + (2 + 3)) + 4)" },
        .{ .input = "(5 + 5) * 2", .expected = "((5 + 5) * 2)" },
        .{ .input = "2 / (5 + 5)", .expected = "(2 / (5 + 5))" },
        .{ .input = "(5 + 5) * 2 * (5 + 5)", .expected = "(((5 + 5) * 2) * (5 + 5))" },
        .{ .input = "-(5 + 5)", .expected = "(-(5 + 5))" },
        .{ .input = "!(true == true)", .expected = "(!(true == true))" },
        .{ .input = "a + add(b * c) + d", .expected = "((a + add((b * c))) + d)" },
        .{ .input = "add(a, b, 1, 2 * 3, 4 + 5, add(6, 7 * 8))", .expected = "add(a, b, 1, (2 * 3), (4 + 5), add(6, (7 * 8)))" },
        .{ .input = "add(a + b + c * d / f + g)", .expected = "add((((a + b) + ((c * d) / f)) + g))" },
        .{ .input = "a * [1, 2, 3, 4][b * c] * d", .expected = "((a * ([1, 2, 3, 4][(b * c)])) * d)" },
        .{ .input = "add(a * b[2], b[1], 2 * [1, 2][1])", .expected = "add((a * (b[2])), (b[1]), (2 * ([1, 2][1])))" },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const node = try init(arena.allocator(), expect.input);

        const string = try node.string(arena.allocator());
        try std.testing.expectEqualStrings(expect.expected, string);
    }
}

test "boolean expressions" {
    const tests = [_]struct {
        input: []const u8,
        expected: bool,
    }{
        .{ .input = "true;", .expected = true },
        .{ .input = "false;", .expected = false },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const node = try init(arena.allocator(), expect.input);
        const expr = node.boolean_literal;

        try std.testing.expectEqual(expect.expected, expr.value);
    }
}

test "if expression" {
    const input = "if (x < y) { x }";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.@"if";

    try testBinaryOperation(expr.condition, .{ .string = "x" }, "<", .{ .string = "y" });
    try std.testing.expectEqual(1, expr.consequence.statements.len);

    const consequence = expr.consequence.statements[0];
    try testIdentifier(consequence, "x");

    try std.testing.expectEqual(null, expr.alternative);
}

test "if else expression" {
    const input = "if (x < y) { x } else { y }";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.@"if";

    try testBinaryOperation(expr.condition, .{ .string = "x" }, "<", .{ .string = "y" });

    try std.testing.expectEqual(1, expr.consequence.statements.len);
    const consequence = expr.consequence.statements[0];
    try testIdentifier(consequence, "x");

    try std.testing.expectEqual(1, expr.alternative.?.statements.len);
    const alternative = expr.alternative.?.statements[0];
    try testIdentifier(alternative, "y");
}

test "function literal" {
    const input = "fn(x, y) { x + y; }";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.function_literal;

    try std.testing.expectEqual(2, expr.parameters.len);
    try testIdentifier(.{ .identifier = expr.parameters[0] }, "x");
    try testIdentifier(.{ .identifier = expr.parameters[1] }, "y");

    try std.testing.expectEqual(1, expr.body.statements.len);
    try testBinaryOperation(expr.body.statements[0], .{ .string = "x" }, "+", .{ .string = "y" });
}

test "function parameters" {
    var params_1 = [_][]const u8{};
    var params_2 = [_][]const u8{"x"};
    var params_3 = [_][]const u8{ "x", "y", "z" };
    const tests = [_]struct {
        input: []const u8,
        params: [][]const u8,
    }{
        .{ .input = "fn() {};", .params = &params_1 },
        .{ .input = "fn(x) {};", .params = &params_2 },
        .{ .input = "fn(x, y, z) {};", .params = &params_3 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const node = try init(arena.allocator(), expect.input);
        const expr = node.function_literal;

        try std.testing.expectEqual(expect.params.len, expr.parameters.len);

        for (expect.params, 0..) |param, i| {
            try testLiteralExpression(.{ .identifier = expr.parameters[i] }, .{ .string = param });
        }
    }
}

test "call expression" {
    const input = "add(1, 2 * 3, 4 + 5);";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.call;

    try testIdentifier(expr.function, "add");

    try std.testing.expectEqual(3, expr.arguments.len);
    try testLiteralExpression(expr.arguments[0], .{ .integer = 1 });
    try testBinaryOperation(expr.arguments[1], .{ .integer = 2 }, "*", .{ .integer = 3 });
    try testBinaryOperation(expr.arguments[2], .{ .integer = 4 }, "+", .{ .integer = 5 });
}

test "call expression parameters" {
    var args_1 = [_][]const u8{};
    var args_2 = [_][]const u8{"1"};
    var args_3 = [_][]const u8{ "1", "(2 * 3)", "(4 + 5)" };
    const tests = [_]struct {
        input: []const u8,
        ident: []const u8,
        args: [][]const u8,
    }{
        .{ .input = "add();", .ident = "add", .args = &args_1 },
        .{ .input = "add(1);", .ident = "add", .args = &args_2 },
        .{ .input = "add(1, 2 * 3, 4 + 5);", .ident = "add", .args = &args_3 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const node = try init(arena.allocator(), expect.input);
        const expr = node.call;

        try std.testing.expectEqual(expect.args.len, expr.arguments.len);

        for (expect.args, 0..) |arg, i| {
            try std.testing.expectEqualStrings(arg, try expr.arguments[i].string(arena.allocator()));
        }
    }
}

test "index expression" {
    const input = "myArray[1 + 1]";

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const node = try init(arena.allocator(), input);
    const expr = node.index;

    try testIdentifier(expr.left, "myArray");

    try testBinaryOperation(expr.index, .{ .integer = 1 }, "+", .{ .integer = 1 });
}
