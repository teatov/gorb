const std = @import("std");
const object = @import("./object.zig");
const token = @import("./token.zig");
const evaluator = @import("./evaluator.zig");

pub fn getBuiltin(allocator: std.mem.Allocator, name: []const u8) !?*const object.BuiltinFunction {
    const builtins = try std.StaticStringMap(*const object.BuiltinFunction).init(
        [_]struct { []const u8, *const object.BuiltinFunction }{
            .{ "len", &len },
            .{ "first", &first },
            .{ "last", &last },
            .{ "rest", &rest },
            .{ "push", &push },
            .{ "puts", &puts },
        },
        allocator,
    );
    return builtins.get(name);
}

fn len(
    eval: *evaluator.Evaluator,
    args: []object.Object,
    tok: token.Token,
) evaluator.Evaluator.Error!object.Object {
    if (args.len != 1) {
        return try eval.invalidArgumentAmountError(
            1,
            args.len,
            tok,
        );
    }

    return switch (args[0]) {
        .string => |obj| blk: {
            const val = try object.Integer.init(
                eval.allocator,
                @intCast(obj.value.len),
            );
            break :blk .{ .integer = val };
        },
        .array => |obj| blk: {
            const val = try object.Integer.init(
                eval.allocator,
                @intCast(obj.elements.len),
            );
            break :blk .{ .integer = val };
        },
        else => try eval.newError(
            "'len' does not support {s}",
            .{args[0].stringify(eval.allocator)},
            tok,
        ),
    };
}

fn first(
    eval: *evaluator.Evaluator,
    args: []object.Object,
    tok: token.Token,
) evaluator.Evaluator.Error!object.Object {
    if (args.len != 1) {
        return try eval.invalidArgumentAmountError(
            1,
            args.len,
            tok,
        );
    }

    return switch (args[0]) {
        .array => |obj| blk: {
            if (obj.elements.len == 0) {
                break :blk .{ .null = &evaluator.null };
            }

            break :blk obj.elements[0];
        },
        else => try eval.newError(
            "'first' does not support {s}",
            .{args[0].stringify(eval.allocator)},
            tok,
        ),
    };
}

fn last(
    eval: *evaluator.Evaluator,
    args: []object.Object,
    tok: token.Token,
) evaluator.Evaluator.Error!object.Object {
    if (args.len != 1) {
        return try eval.invalidArgumentAmountError(
            1,
            args.len,
            tok,
        );
    }

    return switch (args[0]) {
        .array => |obj| blk: {
            if (obj.elements.len == 0) {
                break :blk .{ .null = &evaluator.null };
            }

            break :blk obj.elements[obj.elements.len - 1];
        },
        else => try eval.newError(
            "'last' does not support {s}",
            .{args[0].stringify(eval.allocator)},
            tok,
        ),
    };
}

fn rest(
    eval: *evaluator.Evaluator,
    args: []object.Object,
    tok: token.Token,
) evaluator.Evaluator.Error!object.Object {
    if (args.len != 1) {
        return try eval.invalidArgumentAmountError(
            1,
            args.len,
            tok,
        );
    }

    return switch (args[0]) {
        .array => |obj| blk: {
            if (obj.elements.len == 0) {
                break :blk .{ .null = &evaluator.null };
            }

            const val = try object.Array.init(
                eval.allocator,
                obj.elements[1..],
            );
            break :blk .{ .array = val };
        },
        else => try eval.newError(
            "'rest' does not support {s}",
            .{args[0].stringify(eval.allocator)},
            tok,
        ),
    };
}

fn push(
    eval: *evaluator.Evaluator,
    args: []object.Object,
    tok: token.Token,
) evaluator.Evaluator.Error!object.Object {
    if (args.len != 2) {
        return try eval.invalidArgumentAmountError(
            2,
            args.len,
            tok,
        );
    }

    return switch (args[0]) {
        .array => |obj| blk: {
            var elements = std.ArrayList(object.Object).init(eval.allocator);
            try elements.appendSlice(obj.elements);
            try elements.append(args[1]);

            const val = try object.Array.init(
                eval.allocator,
                elements.items,
            );
            break :blk .{ .array = val };
        },
        else => try eval.newError(
            "'push' does not support {s}",
            .{args[0].stringify(eval.allocator)},
            tok,
        ),
    };
}

fn puts(
    eval: *evaluator.Evaluator,
    args: []object.Object,
    _: token.Token,
) evaluator.Evaluator.Error!object.Object {
    // const writer = std.io.getStdOut();
    for (args) |arg| {
        const text = try arg.inspect(eval.allocator);
        std.debug.print("{s}", .{text});
        // _ = try writer.write(text);
    }

    return .{ .null = &evaluator.null };
}