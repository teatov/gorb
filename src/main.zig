const std = @import("std");
const run = @import("./run/run.zig");

pub fn main() !void {
    const stdin = std.io.getStdIn().reader();
    const stdout = std.io.getStdOut().writer();

    var arena = std.heap.ArenaAllocator.init(
        std.heap.page_allocator,
    );
    defer arena.deinit();

    try run.startRepl(arena.allocator(), stdin, stdout, null);
}

test {
    std.testing.refAllDecls(@This());
}
