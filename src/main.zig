const std = @import("std");
const run = @import("run/run.zig");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        _ = gpa.deinit();
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();

    const options: run.RunOptions = .{
        .main_alloc = gpa.allocator(),
        .lexer_alloc = arena.allocator(),
    };

    try run.startRepl(options, stdin, stdout);
}

test {
    std.testing.refAllDecls(@This());
}
