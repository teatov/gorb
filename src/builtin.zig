const std = @import("std");
const object = @import("./object.zig");
const token = @import("./token.zig");
const evaluator = @import("./evaluator.zig");

pub const builtins = std.StaticStringMap(
    *const object.BuiltinFunction,
).initComptime(
    .{
        .{ "len", &len },
        .{ "first", &first },
        .{ "last", &last },
        .{ "rest", &rest },
        .{ "push", &push },
        .{ "puts", &puts },
    },
);

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
            break :blk .{ .integer = @intCast(obj.len) };
        },
        .array => |obj| blk: {
            break :blk .{ .integer = @intCast(obj.elements.len) };
        },
        else => blk: {
            const obj_string = args[0].stringify(eval.allocator);
            // defer eval.allocator.free(obj_string);
            break :blk try eval.newError(
                "'len' does not support {s}",
                .{obj_string},
                tok,
            );
        },
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
                break :blk .null;
            }

            break :blk obj.elements[0];
        },
        else => blk: {
            const obj_string = args[0].stringify(eval.allocator);
            // defer eval.allocator.free(obj_string);
            break :blk try eval.newError(
                "'first' does not support {s}",
                .{obj_string},
                tok,
            );
        },
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
                break :blk .null;
            }

            break :blk obj.elements[obj.elements.len - 1];
        },
        else => blk: {
            const obj_string = args[0].stringify(eval.allocator);
            // defer eval.allocator.free(obj_string);
            break :blk try eval.newError(
                "'last' does not support {s}",
                .{obj_string},
                tok,
            );
        },
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
                break :blk .null;
            }

            const val = try object.Array.init(
                eval.allocator,
                obj.elements[1..],
            );
            break :blk .{ .array = val };
        },
        else => blk: {
            const obj_string = args[0].stringify(eval.allocator);
            // defer eval.allocator.free(obj_string);
            break :blk try eval.newError(
                "'rest' does not support {s}",
                .{obj_string},
                tok,
            );
        },
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
        else => blk: {
            const obj_string = args[0].stringify(eval.allocator);
            // defer eval.allocator.free(obj_string);
            break :blk try eval.newError(
                "'push' does not support {s}",
                .{obj_string},
                tok,
            );
        },
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
        // eval.allocator.free(text);
        // try writer.writeAll(text);
    }

    return .null;
}
