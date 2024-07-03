const std = @import("std");
const object = @import("../object/object.zig");
const token = @import("../token/token.zig");
const evaluator = @import("./evaluator.zig");

const BuiltinTypes = enum {
    len,
    puts,
};

pub fn getBuiltin(name: []const u8) ?*const object.BuiltinFunction {
    const builtin_name = std.meta.stringToEnum(BuiltinTypes, name);

    if (builtin_name) |builtin| {
        return switch (builtin) {
            .len => &len,
            .puts => &puts,
        };
    } else {
        return null;
    }
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

fn puts(
    eval: *evaluator.Evaluator,
    args: []object.Object,
    _: token.Token,
) evaluator.Evaluator.Error!object.Object {
    const writer = std.io.getStdOut();
    for (args) |arg| {
        const text = try arg.inspect(eval.allocator);
        _ = writer.write(text) catch std.debug.print(
            "{s}",
            .{text},
        );
    }

    return .{ .null = &evaluator.null };
}
