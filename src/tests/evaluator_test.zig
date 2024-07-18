const std = @import("std");
const token = @import("../token.zig");
const lexer = @import("../lexer.zig");
const ast = @import("../ast.zig");
const parser = @import("../parser.zig");
const object = @import("../object.zig");
const evaluator = @import("../evaluator.zig");

fn init(allocator: std.mem.Allocator, input: []const u8) !object.Object {
    var l = try lexer.Lexer.init(allocator, input, null);
    var p = parser.Parser.init(allocator, &l);
    const program = try p.parseProgram(false);
    var e = evaluator.Evaluator.init(allocator);
    const env = try object.Environment.init(allocator);
    return try e.eval(program, env);
}

fn testIntegerObject(obj: object.Object, expected: i32) !void {
    const val = obj.integer;
    try std.testing.expectEqual(expected, val);
}

fn testBooleanObject(obj: object.Object, expected: bool) !void {
    const val = obj.boolean;
    try std.testing.expectEqual(expected, val);
}

fn testNullObject(obj: object.Object) !void {
    _ = obj.null;
}

test "integer expressions" {
    const tests = [_]struct { input: []const u8, value: i32 }{
        .{ .input = "5", .value = 5 },
        .{ .input = "10", .value = 10 },
        .{ .input = "-10", .value = -10 },
        .{ .input = "5 + 5 + 5 + 5 - 10", .value = 10 },
        .{ .input = "2 * 2 * 2 * 2 * 2", .value = 32 },
        .{ .input = "-50 + 100 + -50", .value = 0 },
        .{ .input = "5 * 2 + 10", .value = 20 },
        .{ .input = "5 + 2 * 10", .value = 25 },
        .{ .input = "20 + 2 * -10", .value = 0 },
        .{ .input = "50 / 2 * 2 + 10", .value = 60 },
        .{ .input = "2 * (5 + 10)", .value = 30 },
        .{ .input = "3 * 3 * 3 + 10", .value = 37 },
        .{ .input = "3 * (3 * 3) + 10", .value = 37 },
        .{ .input = "(5 + 10 * 2 + 15 / 3) * 2 + -10", .value = 50 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        try testIntegerObject(obj, expect.value);
    }
}

test "string literal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input = "\"Hello World!\"";

    const obj = try init(arena.allocator(), input);
    const val = obj.string;

    try std.testing.expectEqualStrings("Hello World!", val);
}

test "string concatenation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input = "\"Hello\" + \" \" + \"World!\"";

    const obj = try init(arena.allocator(), input);
    const val = obj.string;

    try std.testing.expectEqualStrings("Hello World!", val);
}

test "array literal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input = "[1, 2 * 2, 3 + 3]";

    const obj = try init(arena.allocator(), input);
    const val = obj.array;

    try std.testing.expectEqual(3, val.elements.len);
    try testIntegerObject(val.elements[0], 1);
    try testIntegerObject(val.elements[1], 4);
    try testIntegerObject(val.elements[2], 6);
}

test "hash literal" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const input =
        \\so two = "two";
        \\{
        \\  "one": 10 - 9,
        \\  two: 1 + 1,
        \\  "thr" + "ee": 6 / 2,
        \\  4: 4,
        \\  true: 5,
        \\  false: 6
        \\}
    ;

    const tests = [_]struct { key: object.HashKey, value: i32 }{
        .{ .key = (object.Object{ .string = "one" }).hashKey().?, .value = 1 },
        .{ .key = (object.Object{ .string = "two" }).hashKey().?, .value = 2 },
        .{ .key = (object.Object{ .string = "three" }).hashKey().?, .value = 3 },
        .{ .key = (object.Object{ .integer = 4 }).hashKey().?, .value = 4 },
        .{ .key = (object.Object{ .boolean = true }).hashKey().?, .value = 5 },
        .{ .key = (object.Object{ .boolean = false }).hashKey().?, .value = 6 },
    };

    const obj = try init(allocator, input);
    const val = obj.hash;

    try std.testing.expectEqual(tests.len, val.pairs.count());

    for (tests) |expect| {
        const pair = val.pairs.get(expect.key);
        try std.testing.expect(pair != null);

        try testIntegerObject(pair.?.value, expect.value);
    }
}

test "array index expression" {
    const tests = [_]struct { input: []const u8, value: ?i32 }{
        .{ .input = "[1, 2, 3][0]", .value = 1 },
        .{ .input = "[1, 2, 3][1]", .value = 2 },
        .{ .input = "[1, 2, 3][2]", .value = 3 },
        .{ .input = "so i = 0; [1][i];", .value = 1 },
        .{ .input = "[1, 2, 3][1 + 1];", .value = 3 },
        .{ .input = "so myArray = [1, 2, 3]; myArray[2];", .value = 3 },
        .{ .input = "so myArray = [1, 2, 3]; myArray[0] + myArray[1] + myArray[2];", .value = 6 },
        .{ .input = "so myArray = [1, 2, 3]; so i = myArray[0]; myArray[i]", .value = 2 },
        .{ .input = "[1, 2, 3][3]", .value = null },
        .{ .input = "[1, 2, 3][-1]", .value = null },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        if (expect.value) |val| {
            try testIntegerObject(obj, val);
        } else {
            try testNullObject(obj);
        }
    }
}

test "hash index expression" {
    const tests = [_]struct { input: []const u8, value: ?i32 }{
        .{ .input = "{\"foo\": 5}[\"foo\"]", .value = 5 },
        .{ .input = "{\"foo\": 5}[\"bar\"]", .value = null },
        .{ .input = "so key = \"foo\"; {\"foo\": 5}[key]", .value = 5 },
        .{ .input = "{}[\"foo\"]", .value = null },
        .{ .input = "{5: 5}[5]", .value = 5 },
        .{ .input = "{true: 5}[true]", .value = 5 },
        .{ .input = "{false: 5}[false]", .value = 5 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        if (expect.value) |val| {
            try testIntegerObject(obj, val);
        } else {
            try testNullObject(obj);
        }
    }
}

test "boolean expression" {
    const tests = [_]struct { input: []const u8, value: bool }{
        .{ .input = "true", .value = true },
        .{ .input = "false", .value = false },
        .{ .input = "1 < 2", .value = true },
        .{ .input = "1 > 2", .value = false },
        .{ .input = "1 < 1", .value = false },
        .{ .input = "1 > 1", .value = false },
        .{ .input = "1 == 1", .value = true },
        .{ .input = "1 != 1", .value = false },
        .{ .input = "1 == 2", .value = false },
        .{ .input = "1 != 2", .value = true },
        .{ .input = "true == true", .value = true },
        .{ .input = "false == false", .value = true },
        .{ .input = "true == false", .value = false },
        .{ .input = "true != false", .value = true },
        .{ .input = "false != true", .value = true },
        .{ .input = "(1 < 2) == true", .value = true },
        .{ .input = "(1 < 2) == false", .value = false },
        .{ .input = "(1 > 2) == true", .value = false },
        .{ .input = "(1 > 2) == false", .value = true },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        try testBooleanObject(obj, expect.value);
    }
}

test "bang operator" {
    const tests = [_]struct { input: []const u8, value: bool }{
        .{ .input = "true", .value = true },
        .{ .input = "false", .value = false },
        .{ .input = "1 < 2", .value = true },
        .{ .input = "1 > 2", .value = false },
        .{ .input = "1 < 1", .value = false },
        .{ .input = "1 > 1", .value = false },
        .{ .input = "1 == 1", .value = true },
        .{ .input = "1 != 1", .value = false },
        .{ .input = "1 == 2", .value = false },
        .{ .input = "1 != 2", .value = true },
        .{ .input = "true == true", .value = true },
        .{ .input = "false == false", .value = true },
        .{ .input = "true == false", .value = false },
        .{ .input = "true != false", .value = true },
        .{ .input = "false != true", .value = true },
        .{ .input = "(1 < 2) == true", .value = true },
        .{ .input = "(1 < 2) == false", .value = false },
        .{ .input = "(1 > 2) == true", .value = false },
        .{ .input = "(1 > 2) == false", .value = true },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        try testBooleanObject(obj, expect.value);
    }
}

test "if else expressions" {
    const tests = [_]struct { input: []const u8, value: ?i32 }{
        .{ .input = "if (true) { 10 }", .value = 10 },
        .{ .input = "if (false) { 10 }", .value = null },
        .{ .input = "if (1) { 10 }", .value = 10 },
        .{ .input = "if (1 < 2) { 10 }", .value = 10 },
        .{ .input = "if (1 > 2) { 10 }", .value = null },
        .{ .input = "if (1 > 2) { 10 } else { 20 }", .value = 20 },
        .{ .input = "if (1 < 2) { 10 } else { 20 }", .value = 10 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        if (expect.value) |val| {
            try testIntegerObject(obj, val);
        } else {
            try testNullObject(obj);
        }
    }
}

test "return statements" {
    const tests = [_]struct { input: []const u8, value: i32 }{
        .{ .input = "return 10;", .value = 10 },
        .{ .input = "return 10; 9;", .value = 10 },
        .{ .input = "return 2 * 5; 9;", .value = 10 },
        .{ .input = "9; return 2 * 5; 9;", .value = 10 },
        .{ .input = "if (10 > 1) { return 10; }", .value = 10 },
        .{ .input = 
        \\if (10 > 1) {
        \\  if (10 > 1) {
        \\    return 10;
        \\  }
        \\  return 1;
        \\}
        , .value = 10 },
        .{ .input = 
        \\so f = fn(x) {
        \\  return x;
        \\  x + 10;
        \\};
        \\f(10);
        , .value = 10 },
        .{ .input = 
        \\so f = fn(x) {
        \\   so result = x + 10;
        \\   return result;
        \\   return 10;
        \\};
        \\f(10);
        , .value = 20 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        try testIntegerObject(obj, expect.value);
    }
}

test "error handling" {
    const tests = [_]struct {
        input: []const u8,
        msg: []const u8,
    }{
        .{
            .input = "5 + true;",
            .msg = "type mismatch: [integer] + [boolean]",
        },
        .{
            .input = "5 + true; 5;",
            .msg = "type mismatch: [integer] + [boolean]",
        },
        .{
            .input = "-true",
            .msg = "unknown operation: -[boolean]",
        },
        .{
            .input = "true + false;",
            .msg = "unknown operation: [boolean] + [boolean]",
        },
        .{
            .input = "true + false + true + false;",
            .msg = "unknown operation: [boolean] + [boolean]",
        },
        .{
            .input = "5; true + false; 5",
            .msg = "unknown operation: [boolean] + [boolean]",
        },
        .{
            .input = "if (10 > 1) { true + false; }",
            .msg = "unknown operation: [boolean] + [boolean]",
        },
        .{
            .input = "\"Hello\" - \"World\"",
            .msg = "unknown operation: [string] - [string]",
        },
        .{
            .input = "if (10 > 1) {  if (10 > 1) {    return true + false;  }  return 1;}",
            .msg = "unknown operation: [boolean] + [boolean]",
        },
        .{
            .input = "foobar",
            .msg = "identifier 'foobar' not found",
        },
        .{
            .input = "{\"name\": \"Monkey\"}[fn(x) { x }];",
            .msg = "[function] is unusable as hash key",
        },
        .{
            .input = "999[1]",
            .msg = "index operator is not supported on [integer]",
        },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        const val = obj.@"error";

        try std.testing.expectEqualStrings(expect.msg, val.message);
    }
}

test "so statements" {
    const tests = [_]struct { input: []const u8, value: i32 }{
        .{ .input = "so a = 5; a;", .value = 5 },
        .{ .input = "so a = 5 * 5; a;", .value = 25 },
        .{ .input = "so a = 5; so b = a; b;", .value = 5 },
        .{ .input = "so a = 5; so b = a; so c = a + b + 5; c;", .value = 15 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        try testIntegerObject(obj, expect.value);
    }
}

test "function object" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input = "fn(x) { x + 2; };";

    const obj = try init(arena.allocator(), input);
    const val = obj.function;

    try std.testing.expectEqual(1, val.parameters.len);
    try std.testing.expectEqualStrings("x", val.parameters[0].value);
    try std.testing.expectEqualStrings("(x + 2)", try ast.Node.print(.{ .block = val.body }, arena.allocator()));
}

test "function calling" {
    const tests = [_]struct { input: []const u8, value: i32 }{
        .{ .input = "so identity = fn(x) { x; }; identity(5);", .value = 5 },
        .{ .input = "so identity = fn(x) { return x; }; identity(5);", .value = 5 },
        .{ .input = "so double = fn(x) { x * 2; }; double(5);", .value = 10 },
        .{ .input = "so add = fn(x, y) { x + y; }; add(5, 5);", .value = 10 },
        .{ .input = "so add = fn(x, y) { x + y; }; add(5 + 5, add(5, 5));", .value = 20 },
        .{ .input = "fn(x) { x; }(5)", .value = 5 },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        try testIntegerObject(obj, expect.value);
    }
}

test "enclosing environments" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input =
        \\so first = 10;
        \\so second = 10;
        \\so third = 10;
        \\
        \\so ourFunction = fn(first) {
        \\  so second = 20;
        \\  first + second + third;
        \\};
        \\
        \\ourFunction(20) + first + second;
    ;

    const obj = try init(arena.allocator(), input);

    try testIntegerObject(obj, 70);
}

test "closures" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input =
        \\so newAdder = fn(x) {
        \\	fn(y) {x + y};
        \\};
        \\
        \\so addTwo = newAdder(2);
        \\addTwo(2);
    ;

    const obj = try init(arena.allocator(), input);

    try testIntegerObject(obj, 4);
}

const PossibleValues = union(enum) {
    integer: i32,
    string: []const u8,
    array: []i32,
};

test "builtin functions" {
    var rest1 = [_]i32{ 2, 3 };
    var rest2 = [_]i32{1};
    const tests = [_]struct { input: []const u8, value: ?PossibleValues }{
        .{ .input = "len(\"\")", .value = .{ .integer = 0 } },
        .{ .input = "len(\"four\")", .value = .{ .integer = 4 } },
        .{ .input = "len(\"hello world\")", .value = .{ .integer = 11 } },
        .{ .input = "len(1)", .value = .{ .string = "'len' does not support [integer]" } },
        .{ .input = "len(\"one\", \"two\")", .value = .{ .string = "expected 1 argument, got 2" } },
        .{ .input = "len([1, 2, 3])", .value = .{ .integer = 3 } },
        .{ .input = "len(\"∑\")", .value = .{ .integer = 3 } },
        .{ .input = "len(\"йцукен\")", .value = .{ .integer = 12 } },
        .{ .input = "len([])", .value = .{ .integer = 0 } },
        .{ .input = "first([1, 2, 3])", .value = .{ .integer = 1 } },
        .{ .input = "first([])", .value = null },
        .{ .input = "first(1)", .value = .{ .string = "'first' does not support [integer]" } },
        .{ .input = "last([1, 2, 3])", .value = .{ .integer = 3 } },
        .{ .input = "last([])", .value = null },
        .{ .input = "last(1)", .value = .{ .string = "'last' does not support [integer]" } },
        .{ .input = "rest([1, 2, 3])", .value = .{ .array = &rest1 } },
        .{ .input = "rest([])", .value = null },
        .{ .input = "push([], 1)", .value = .{ .array = &rest2 } },
        .{ .input = "push(1, 1)", .value = .{ .string = "'push' does not support [integer]" } },
        .{ .input = "puts(\"hello\", \"world!\")", .value = null },
    };

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    for (tests) |expect| {
        const obj = try init(arena.allocator(), expect.input);
        if (expect.value) |val| {
            switch (val) {
                .integer => |v| try testIntegerObject(obj, v),
                .string => |v| try std.testing.expectEqualStrings(v, obj.@"error".message),
                .array => |v| {
                    try std.testing.expectEqual(v.len, obj.array.elements.len);
                    for (v, 0..) |msg, i| {
                        try testIntegerObject(obj.array.elements[i], msg);
                    }
                },
            }
        } else {
            try testNullObject(obj);
        }
    }
}
