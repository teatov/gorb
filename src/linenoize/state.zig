const std = @import("std");
const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const ArrayListUnmanaged = std.ArrayListUnmanaged;
const File = std.fs.File;
const bufferedWriter = std.io.bufferedWriter;
const math = std.math;

const Linenoise = @import("main.zig").Linenoise;
const History = @import("history.zig").History;
const term = @import("term.zig");
const getColumns = term.getColumns;

const key_tab = 9;
const key_esc = 27;

const Bias = enum {
    left,
    right,
};

pub fn width(s: []const u8) usize {
    var result: usize = 0;

    var escape_seq = false;
    const view = std.unicode.Utf8View.init(s) catch return 0;
    var iter = view.iterator();
    while (iter.nextCodepoint()) |codepoint| {
        if (escape_seq) {
            if (codepoint == 'm') {
                escape_seq = false;
            }
        } else {
            if (codepoint == '\x1b') {
                escape_seq = true;
            } else {
                result += 1;
            }
        }
    }

    return result;
}

fn binarySearchBestEffort(
    comptime T: type,
    key: T,
    items: []const T,
    context: anytype,
    comptime compareFn: fn (context: @TypeOf(context), lhs: T, rhs: T) math.Order,
    bias: Bias,
) usize {
    var left: usize = 0;
    var right: usize = items.len;

    while (left < right) {
        // Avoid overflowing in the midpoint calculation
        const mid = left + (right - left) / 2;
        // Compare the key with the midpoint element
        switch (compareFn(context, key, items[mid])) {
            .eq => return mid,
            .gt => left = mid + 1,
            .lt => right = mid,
        }
    }

    // At this point, it is guaranteed that left >= right. In order
    // for the bias to work, we need to return the exact opposite
    return switch (bias) {
        .left => right,
        .right => left,
    };
}

fn compareLeft(context: []const u8, avail_space: usize, index: usize) math.Order {
    const width_slice = width(context[0..index]);
    return math.order(avail_space, width_slice);
}

fn compareRight(context: []const u8, avail_space: usize, index: usize) math.Order {
    const width_slice = width(context[index..]);
    return math.order(width_slice, avail_space);
}

const StartOrEnd = enum {
    start,
    end,
};

/// Start mode: Calculates the optimal start position such that
/// buf[start..] fits in the available space taking into account
/// unicode codepoint widths
///
/// xxxxxxxxxxxxxxxxxxxxxxx buf
///    [------------------] available_space
///    ^                    start
///
/// End mode: Calculates the optimal end position so that buf[0..end]
/// fits
///
/// xxxxxxxxxxxxxxxxxxxxxxx buf
/// [----------]            available_space
///            ^            end
fn calculateStartOrEnd(
    allocator: Allocator,
    comptime mode: StartOrEnd,
    buf: []const u8,
    avail_space: usize,
) !usize {
    // Create a mapping from unicode codepoint indices to buf
    // indices
    var map = try std.ArrayListUnmanaged(usize).initCapacity(allocator, buf.len);
    defer map.deinit(allocator);

    var utf8 = (try std.unicode.Utf8View.init(buf)).iterator();
    while (utf8.nextCodepointSlice()) |codepoint| {
        map.appendAssumeCapacity(@intFromPtr(codepoint.ptr) - @intFromPtr(buf.ptr));
    }

    const codepoint_start = binarySearchBestEffort(
        usize,
        avail_space,
        map.items,
        buf,
        switch (mode) {
            .start => compareRight,
            .end => compareLeft,
        },
        // When calculating start or end, if in doubt, choose a
        // smaller buffer as we don't want to overflow the line. For
        // calculating start, this means that we would rather have an
        // index more to the right.
        switch (mode) {
            .start => .right,
            .end => .left,
        },
    );
    return map.items[codepoint_start];
}

pub const LinenoiseState = struct {
    allocator: Allocator,
    ln: *Linenoise,

    stdin: File,
    stdout: File,
    buf: ArrayListUnmanaged(u8) = .{},
    prompt: []const u8,
    pos: usize = 0,
    old_pos: usize = 0,
    cols: usize,
    max_rows: usize = 0,

    const Self = @This();

    pub fn init(ln: *Linenoise, in: File, out: File, prompt: []const u8) Self {
        return Self{
            .allocator = ln.allocator,
            .ln = ln,

            .stdin = in,
            .stdout = out,
            .prompt = prompt,
            .cols = getColumns(in, out) catch 80,
        };
    }

    pub fn refreshLine(self: *Self) !void {
        var buf = bufferedWriter(self.stdout.writer());
        var writer = buf.writer();

        // Calculate widths
        const pos = width(self.buf.items[0..self.pos]);
        const prompt_width = width(self.prompt);
        const buf_width = width(self.buf.items);

        // Don't show hint/prompt when there is no space
        const show_prompt = prompt_width < self.cols;
        const display_prompt_width = if (show_prompt) prompt_width else 0;

        // buffer -> display_buf mapping
        const avail_space = self.cols - display_prompt_width - 1;
        const whole_buffer_fits = buf_width <= avail_space;
        var start: usize = undefined;
        var end: usize = undefined;
        if (whole_buffer_fits) {
            start = 0;
            end = self.buf.items.len;
        } else {
            if (pos < avail_space) {
                start = 0;
                end = try calculateStartOrEnd(
                    self.allocator,
                    .end,
                    self.buf.items,
                    avail_space,
                );
            } else {
                end = self.pos;
                start = try calculateStartOrEnd(
                    self.allocator,
                    .start,
                    self.buf.items[0..end],
                    avail_space,
                );
            }
        }
        const display_buf = self.buf.items[start..end];

        // Move cursor to left edge
        try writer.writeAll("\r");

        // Write prompt
        if (show_prompt) try writer.writeAll(self.prompt);

        // Write current buffer content
        try writer.writeAll(display_buf);

        // Erase to the right
        try writer.writeAll("\x1b[0K");

        // Move cursor to original position
        const cursor_pos = if (pos > avail_space) self.cols - 1 else display_prompt_width + pos;
        try writer.print("\r\x1b[{}C", .{cursor_pos});

        // Write buffer
        try buf.flush();
    }

    pub fn editInsert(self: *Self, c: []const u8) !void {
        try self.buf.resize(self.allocator, self.buf.items.len + c.len);
        if (self.buf.items.len > 0 and self.pos < self.buf.items.len - c.len) {
            std.mem.copyBackwards(
                u8,
                self.buf.items[self.pos + c.len .. self.buf.items.len],
                self.buf.items[self.pos .. self.buf.items.len - c.len],
            );
        }

        @memcpy(self.buf.items[self.pos..][0..c.len], c);
        self.pos += c.len;
        try self.refreshLine();
    }

    fn prevCodepointLen(self: *Self, pos: usize) usize {
        if (pos >= 1 and @clz(~self.buf.items[pos - 1]) == 0) {
            return 1;
        } else if (pos >= 2 and @clz(~self.buf.items[pos - 2]) == 2) {
            return 2;
        } else if (pos >= 3 and @clz(~self.buf.items[pos - 3]) == 3) {
            return 3;
        } else if (pos >= 4 and @clz(~self.buf.items[pos - 4]) == 4) {
            return 4;
        } else {
            return 0;
        }
    }

    pub fn editMoveLeft(self: *Self) !void {
        if (self.pos == 0) return;
        self.pos -= self.prevCodepointLen(self.pos);
        try self.refreshLine();
    }

    pub fn editMoveRight(self: *Self) !void {
        if (self.pos < self.buf.items.len) {
            const utf8_len = std.unicode.utf8ByteSequenceLength(self.buf.items[self.pos]) catch 1;
            self.pos += utf8_len;
            try self.refreshLine();
        }
    }

    pub fn editMoveWordEnd(self: *Self) !void {
        if (self.pos < self.buf.items.len) {
            while (self.pos < self.buf.items.len and self.buf.items[self.pos] == ' ')
                self.pos += 1;
            while (self.pos < self.buf.items.len and self.buf.items[self.pos] != ' ')
                self.pos += 1;
            try self.refreshLine();
        }
    }

    pub fn editMoveWordStart(self: *Self) !void {
        if (self.buf.items.len > 0 and self.pos > 0) {
            while (self.pos > 0 and self.buf.items[self.pos - 1] == ' ')
                self.pos -= 1;
            while (self.pos > 0 and self.buf.items[self.pos - 1] != ' ')
                self.pos -= 1;
            try self.refreshLine();
        }
    }

    pub fn editMoveHome(self: *Self) !void {
        if (self.pos > 0) {
            self.pos = 0;
            try self.refreshLine();
        }
    }

    pub fn editMoveEnd(self: *Self) !void {
        if (self.pos < self.buf.items.len) {
            self.pos = self.buf.items.len;
            try self.refreshLine();
        }
    }

    pub const HistoryDirection = enum {
        next,
        prev,
    };

    pub fn editHistoryNext(self: *Self, dir: HistoryDirection) !void {
        if (self.ln.history.hist.items.len > 0) {
            // Update the current history with the current line
            const old_index = self.ln.history.current;
            const current_entry = self.ln.history.hist.items[old_index];
            self.ln.history.allocator.free(current_entry);
            self.ln.history.hist.items[old_index] = try self.ln.history.allocator.dupe(u8, self.buf.items);

            // Update history index
            const new_index = switch (dir) {
                .next => if (old_index < self.ln.history.hist.items.len - 1) old_index + 1 else self.ln.history.hist.items.len - 1,
                .prev => if (old_index > 0) old_index - 1 else 0,
            };
            self.ln.history.current = new_index;

            // Copy history entry to the current line buffer
            self.buf.deinit(self.allocator);
            self.buf = .{};
            try self.buf.appendSlice(self.allocator, self.ln.history.hist.items[new_index]);
            self.pos = self.buf.items.len;

            try self.refreshLine();
        }
    }

    pub fn editDelete(self: *Self) !void {
        if (self.buf.items.len == 0 or self.pos >= self.buf.items.len) return;

        const utf8_len = std.unicode.utf8CodepointSequenceLength(self.buf.items[self.pos]) catch 1;
        std.mem.copyForwards(
            u8,
            self.buf.items[self.pos .. self.buf.items.len - utf8_len],
            self.buf.items[self.pos + utf8_len .. self.buf.items.len],
        );
        try self.buf.resize(self.allocator, self.buf.items.len - utf8_len);
        try self.refreshLine();
    }

    pub fn editBackspace(self: *Self) !void {
        if (self.buf.items.len == 0 or self.pos == 0) return;

        const utf8_len = self.prevCodepointLen(self.pos);
        std.mem.copyForwards(
            u8,
            self.buf.items[self.pos - utf8_len .. self.buf.items.len - utf8_len],
            self.buf.items[self.pos..self.buf.items.len],
        );
        self.pos -= utf8_len;
        try self.buf.resize(self.allocator, self.buf.items.len - utf8_len);
        try self.refreshLine();
    }

    pub fn editSwapPrev(self: *Self) !void {
        //    aaa bb            =>   bb aaa
        //   ^   ^  ^- pos_end      ^  ^   ^- pos_end
        //   |   |                  |  |
        //   |   pos_1              |  pos_2
        // pos_begin            pos_begin

        const pos_end = self.pos;
        const b_len = self.prevCodepointLen(pos_end);
        const pos_1 = pos_end - b_len;
        const a_len = self.prevCodepointLen(pos_1);
        const pos_begin = pos_1 - a_len;
        const pos_2 = pos_begin + b_len;

        if (a_len == 0 or b_len == 0) return;

        // save both codepoints
        var tmp: [8]u8 = undefined;
        @memcpy(
            tmp[0 .. a_len + b_len],
            self.buf.items[pos_begin..pos_end],
        );
        // write b from tmp
        @memcpy(
            self.buf.items[pos_begin..pos_2],
            tmp[a_len .. a_len + b_len],
        );
        // write a from tmp
        @memcpy(
            self.buf.items[pos_2..pos_end],
            tmp[0..a_len],
        );

        try self.refreshLine();
    }

    pub fn editDeletePrevWord(self: *Self) !void {
        if (self.buf.items.len == 0 or self.pos == 0) return;

        const old_pos = self.pos;
        while (self.pos > 0 and self.buf.items[self.pos - 1] == ' ')
            self.pos -= 1;
        while (self.pos > 0 and self.buf.items[self.pos - 1] != ' ')
            self.pos -= 1;

        const diff = old_pos - self.pos;
        const new_len = self.buf.items.len - diff;
        std.mem.copyForwards(
            u8,
            self.buf.items[self.pos..new_len],
            self.buf.items[old_pos..self.buf.items.len],
        );
        try self.buf.resize(self.allocator, new_len);
        try self.refreshLine();
    }

    pub fn editKillLineForward(self: *Self) !void {
        try self.buf.resize(self.allocator, self.pos);
        try self.refreshLine();
    }

    pub fn editKillLineBackward(self: *Self) !void {
        const new_len = self.buf.items.len - self.pos;
        std.mem.copyForwards(
            u8,
            self.buf.items[0..new_len],
            self.buf.items[self.pos..self.buf.items.len],
        );
        self.pos = 0;
        try self.buf.resize(self.allocator, new_len);
        try self.refreshLine();
    }
};
