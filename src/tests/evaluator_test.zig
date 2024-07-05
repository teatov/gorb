const std = @import("std");
const token = @import("../token.zig");
const lexer = @import("../lexer.zig");
const ast = @import("../ast.zig");
const parser = @import("../parser.zig");
const object = @import("../object.zig");
const evaluator = @import("../evaluator.zig");

pub fn hack() void {}

fn init(allocator: std.mem.Allocator, input: []const u8) !object.Object {
    var l = try lexer.Lexer.init(allocator, input);
    var p = parser.Parser.init(allocator, &l);
    const program = try p.parseProgram();
    var e = evaluator.Evaluator.init(allocator);
    const env = try object.Environment.init(allocator);
    return try e.eval(program, env);
}

fn testIntegerObject(obj: object.Object, expected: i32) !void {
    const val = obj.integer;
    try std.testing.expectEqual(expected, val.value);
}

fn testBooleanObject(obj: object.Object, expected: bool) !void {
    const val = obj.boolean;
    try std.testing.expectEqual(expected, val.value);
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

    try std.testing.expectEqualStrings("Hello World!", val.value);
}

test "string concatenation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();

    const input = "\"Hello\" + \" \" + \"World!\"";

    const obj = try init(arena.allocator(), input);
    const val = obj.string;

    try std.testing.expectEqualStrings("Hello World!", val.value);
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
        \\let two = "two";
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
        .{ .key = (object.Object{ .string = try object.String.init(allocator, "one") }).hashKey().?, .value = 1 },
        .{ .key = (object.Object{ .string = try object.String.init(allocator, "two") }).hashKey().?, .value = 2 },
        .{ .key = (object.Object{ .string = try object.String.init(allocator, "three") }).hashKey().?, .value = 3 },
        .{ .key = (object.Object{ .integer = try object.Integer.init(allocator, 4) }).hashKey().?, .value = 4 },
        .{ .key = (object.Object{ .boolean = try object.Boolean.init(allocator, true) }).hashKey().?, .value = 5 },
        .{ .key = (object.Object{ .boolean = try object.Boolean.init(allocator, false) }).hashKey().?, .value = 6 },
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
        .{ .input = "let i = 0; [1][i];", .value = 1 },
        .{ .input = "[1, 2, 3][1 + 1];", .value = 3 },
        .{ .input = "let myArray = [1, 2, 3]; myArray[2];", .value = 3 },
        .{ .input = "let myArray = [1, 2, 3]; myArray[0] + myArray[1] + myArray[2];", .value = 6 },
        .{ .input = "let myArray = [1, 2, 3]; let i = myArray[0]; myArray[i]", .value = 2 },
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
        .{ .input = "let key = \"foo\"; {\"foo\": 5}[key]", .value = 5 },
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
