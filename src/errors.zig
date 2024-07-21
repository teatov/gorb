const std = @import("std");
const Lexer = @import("./Lexer.zig");
const Token = @import("./Token.zig");
const ast = @import("./ast.zig");

const esc = "\x1B";
const reset = esc ++ "[0m";
const bold = esc ++ "[1m";
const red = esc ++ "[0;31m";
const dim = esc ++ "[2m";

pub fn formatError(
    allocator: std.mem.Allocator,
    message: []const u8,
    tok: Token,
) []const u8 {
    var pointer = std.ArrayList(u8).init(allocator);
    defer pointer.deinit();
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

    const pos_string = tok.pos.fmt(allocator);
    defer allocator.free(pos_string);
    const msg = std.fmt.allocPrint(
        allocator,
        "{s}error:{s} {s}\n{s}{s}:{s}:{s}\n{s}\n{s}{s}{s}",
        .{
            red,
            reset,
            message,
            bold,
            tok.file_path orelse "",
            pos_string,
            reset,
            tok.line,
            dim,
            pointer.items,
            reset,
        },
    ) catch |err| {
        return @errorName(err);
    };
    return msg;
}
