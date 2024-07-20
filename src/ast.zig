const std = @import("std");
const Token = @import("./Token.zig");
const object = @import("./object.zig");

pub const PrintError = error{OutOfMemory};

pub const Node = union(enum) {
    block: *Block,
    @"return": *Return,
    declaration: *Declaration,
    index: *Index,
    call: *Call,
    @"if": *If,
    unary_operation: *UnaryOperation,
    binary_operation: *BinaryOperation,

    // literals
    identifier: *Identifier,
    boolean_literal: *BooleanLiteral,
    integer_literal: *IntegerLiteral,
    string_literal: *StringLiteral,
    array_literal: *ArrayLiteral,
    hash_literal: *HashLiteral,
    function_literal: *FunctionLiteral,

    const Self = @This();

    pub fn deinit(
        self: Self,
        allocator: std.mem.Allocator,
    ) void {
        switch (self) {
            inline else => |node| node.deinit(allocator),
        }
    }

    pub fn fmt(
        self: Node,
        allocator: std.mem.Allocator,
    ) PrintError![]const u8 {
        return switch (self) {
            inline else => |node| try node.fmt(allocator),
        };
    }
};

pub const Block = struct {
    tok: Token = undefined,
    statements: []Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.statements) |stmt| stmt.deinit(allocator);
        allocator.free(self.statements);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var node_string = std.ArrayList(u8).init(allocator);
        for (self.statements) |stmt| {
            const stmt_string = try stmt.fmt(allocator);
            try node_string.appendSlice(stmt_string);
            allocator.free(stmt_string);
        }

        return try node_string.toOwnedSlice();
    }
};

pub const Return = struct {
    tok: Token = undefined,
    return_value: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.return_value.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const return_value: []const u8 = try self.return_value.fmt(
            allocator,
        );

        defer allocator.free(return_value);
        return try std.fmt.allocPrint(
            allocator,
            "{s} {s};",
            .{ self.tok.literal, return_value },
        );
    }
};

pub const Declaration = struct {
    tok: Token = undefined,
    name: *Identifier = undefined,
    value: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.name.deinit(allocator);
        self.value.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const value: []const u8 = try self.value.fmt(
            allocator,
        );

        defer allocator.free(value);
        return try std.fmt.allocPrint(
            allocator,
            "{s} {s} = {s};",
            .{ self.tok.literal, self.name.value, value },
        );
    }
};

pub const Index = struct {
    tok: Token = undefined,
    left: Node = undefined,
    index: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.left.deinit(allocator);
        self.index.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const left: []const u8 = try self.left.fmt(
            allocator,
        );
        const index: []const u8 = try self.index.fmt(
            allocator,
        );

        defer allocator.free(left);
        defer allocator.free(index);
        return try std.fmt.allocPrint(
            allocator,
            "({s}[{s}])",
            .{ left, index },
        );
    }
};

pub const Call = struct {
    tok: Token = undefined,
    function: Node = undefined,
    arguments: []Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.function.deinit(allocator);
        for (self.arguments) |arg| arg.deinit(allocator);
        allocator.free(self.arguments);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const function: []const u8 = try self.function.fmt(
            allocator,
        );
        var args = std.ArrayList(u8).init(allocator);
        for (self.arguments, 0..) |arg, i| {
            const arg_string = try arg.fmt(allocator);
            try args.appendSlice(arg_string);
            allocator.free(arg_string);
            if (i < self.arguments.len - 1) {
                try args.appendSlice(", ");
            }
        }

        defer allocator.free(function);
        defer args.deinit();
        return try std.fmt.allocPrint(
            allocator,
            "{s}({s})",
            .{ function, args.items },
        );
    }
};

pub const If = struct {
    tok: Token = undefined,
    condition: Node = undefined,
    consequence: *Block = undefined,
    alternative: ?*Block = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.condition.deinit(allocator);
        self.consequence.deinit(allocator);
        if (self.alternative) |alternative| alternative.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const condition: []const u8 = try self.condition.fmt(
            allocator,
        );

        var body = std.ArrayList(u8).init(allocator);
        const stmt_string = try self.condition.fmt(allocator);
        try body.appendSlice(stmt_string);
        defer allocator.free(stmt_string);

        if (self.alternative) |alternative| {
            try body.appendSlice(" else ");
            const alt_stmt_string = try alternative.fmt(allocator);
            try body.appendSlice(alt_stmt_string);
            allocator.free(alt_stmt_string);
        }

        defer body.deinit();
        defer allocator.free(condition);
        return try std.fmt.allocPrint(
            allocator,
            "if {s} {s}",
            .{ condition, body.items },
        );
    }
};

pub const UnaryOperation = struct {
    tok: Token = undefined,
    operator: Token = undefined,
    right: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.right.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const right: []const u8 = try self.right.fmt(
            allocator,
        );

        defer allocator.free(right);
        return try std.fmt.allocPrint(
            allocator,
            "({s}{s})",
            .{ self.operator.literal, right },
        );
    }
};

pub const BinaryOperation = struct {
    tok: Token = undefined,
    left: Node = undefined,
    operator: Token = undefined,
    right: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.left.deinit(allocator);
        self.right.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const left: []const u8 = try self.left.fmt(
            allocator,
        );
        const right: []const u8 = try self.right.fmt(
            allocator,
        );

        defer allocator.free(left);
        defer allocator.free(right);
        return try std.fmt.allocPrint(
            allocator,
            "({s} {s} {s})",
            .{ left, self.operator.literal, right },
        );
    }
};

// literals

pub const Identifier = struct {
    tok: Token = undefined,
    value: []const u8 = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "{s}",
            .{self.value},
        );
    }
};

pub const BooleanLiteral = struct {
    tok: Token = undefined,
    value: bool = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "{any}",
            .{self.value},
        );
    }
};

pub const IntegerLiteral = struct {
    tok: Token = undefined,
    value: object.Integer = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "{d}",
            .{self.value},
        );
    }
};

pub const StringLiteral = struct {
    tok: Token = undefined,
    value: []const u8 = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        allocator.free(self.value);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        return try std.fmt.allocPrint(
            allocator,
            "{s}",
            .{self.value},
        );
    }
};

pub const ArrayLiteral = struct {
    tok: Token = undefined,
    elements: []Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.elements) |element| element.deinit(allocator);
        allocator.free(self.elements);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var elements = std.ArrayList(u8).init(allocator);
        for (self.elements, 0..) |element, i| {
            const element_string = try element.fmt(allocator);
            try elements.appendSlice(element_string);
            allocator.free(element_string);
            if (i < self.elements.len - 1) {
                try elements.appendSlice(", ");
            }
        }

        defer elements.deinit();
        return try std.fmt.allocPrint(
            allocator,
            "[{s}]",
            .{elements.items},
        );
    }
};

pub const HashLiteral = struct {
    tok: Token = undefined,
    pairs: std.AutoHashMap(Node, Node) = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        var iterator = self.pairs.iterator();
        while (iterator.next()) |value| {
            value.key_ptr.deinit(allocator);
            value.value_ptr.deinit(allocator);
        }
        self.pairs.deinit();
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var pairs = std.ArrayList(u8).init(allocator);
        var iterator = self.pairs.keyIterator();
        var i: u32 = 0;
        while (iterator.next()) |key| {
            const key_string = try key.fmt(allocator);
            try pairs.appendSlice(key_string);
            allocator.free(key_string);
            try pairs.appendSlice(":");
            const value_string = try self.pairs.get(key.*).?.fmt(
                allocator,
            );
            try pairs.appendSlice(value_string);
            allocator.free(value_string);
            if (i < self.pairs.count() - 1) {
                try pairs.appendSlice(", ");
            }
            i += 1;
        }

        defer pairs.deinit();
        return try std.fmt.allocPrint(
            allocator,
            "{{{s}}}",
            .{pairs.items},
        );
    }
};

pub const FunctionLiteral = struct {
    tok: Token = undefined,
    parameters: []*Identifier = undefined,
    body: *Block = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Self {
        return try allocator.create(Self);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.body.deinit(allocator);
        for (self.parameters) |param| param.deinit(allocator);
        allocator.free(self.parameters);
        allocator.destroy(self);
    }

    pub fn fmt(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var params = std.ArrayList(u8).init(allocator);
        for (self.parameters, 0..) |param, i| {
            try params.appendSlice(param.value);
            if (i < self.parameters.len - 1) {
                try params.appendSlice(", ");
            }
        }

        const body_string = try self.body.fmt(allocator);

        defer params.deinit();
        defer allocator.free(body_string);
        return try std.fmt.allocPrint(
            allocator,
            "{s}({s}){s}",
            .{
                self.tok.literal,
                params.items,
                body_string,
            },
        );
    }
};
