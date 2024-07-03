const std = @import("std");
const lexer = @import("./lexer.zig");
const token = @import("./token.zig");
const ast = @import("./ast.zig");

pub fn newError(
    allocator: std.mem.Allocator,
    message: []const u8,
    tok: token.Token,
) []const u8 {
    var pointer = std.ArrayList(u8).init(allocator);
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
        allocator,
        "{s}: {s}\n{s}\n{s}\n",
        .{
            tok.pos.string(allocator),
            message,
            tok.line,
            pointer.items,
        },
    ) catch |err| {
        return @errorName(err);
    };
    return msg;
}
