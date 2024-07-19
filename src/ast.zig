const std = @import("std");
const token = @import("./token.zig");
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
        cleanup: bool,
    ) void {
        _ = switch (self) {
            .block => |node| node.deinit(allocator, cleanup),
            .@"return" => |node| node.deinit(allocator, cleanup),
            .declaration => |node| node.deinit(allocator, cleanup),
            .index => |node| node.deinit(allocator, cleanup),
            .call => |node| node.deinit(allocator, cleanup),
            .@"if" => |node| node.deinit(allocator, cleanup),
            .unary_operation => |node| node.deinit(allocator, cleanup),
            .binary_operation => |node| node.deinit(allocator, cleanup),
            .identifier => |node| node.deinit(allocator, cleanup),
            .boolean_literal => |node| node.deinit(allocator, cleanup),
            .integer_literal => |node| node.deinit(allocator, cleanup),
            .string_literal => |node| node.deinit(allocator, cleanup),
            .array_literal => |node| node.deinit(allocator, cleanup),
            .hash_literal => |node| node.deinit(allocator, cleanup),
            .function_literal => |node| node.deinit(allocator, cleanup),
        };
    }

    pub fn fmt(
        self: Node,
        allocator: std.mem.Allocator,
    ) PrintError![]const u8 {
        return switch (self) {
            .block => |node| try node.fmt(allocator),
            .@"return" => |node| try node.fmt(allocator),
            .declaration => |node| try node.fmt(allocator),
            .index => |node| try node.fmt(allocator),
            .call => |node| try node.fmt(allocator),
            .@"if" => |node| try node.fmt(allocator),
            .unary_operation => |node| try node.fmt(allocator),
            .binary_operation => |node| try node.fmt(allocator),
            .identifier => |node| try node.fmt(allocator),
            .boolean_literal => |node| try node.fmt(allocator),
            .integer_literal => |node| try node.fmt(allocator),
            .string_literal => |node| try node.fmt(allocator),
            .array_literal => |node| try node.fmt(allocator),
            .hash_literal => |node| try node.fmt(allocator),
            .function_literal => |node| try node.fmt(allocator),
        };
    }
};

pub const Block = struct {
    token: token.Token = undefined,
    statements: []Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Block {
        return try allocator.create(Block);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        for (self.statements) |stmt| {
            stmt.deinit(allocator, cleanup);
        }
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
    token: token.Token = undefined,
    return_value: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Return {
        return try allocator.create(Return);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        self.return_value.deinit(allocator, cleanup);
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
            .{ self.token.literal, return_value },
        );
    }
};

pub const Declaration = struct {
    token: token.Token = undefined,
    name: *Identifier = undefined,
    value: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Declaration {
        return try allocator.create(Declaration);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        self.name.deinit(allocator, cleanup);
        self.value.deinit(allocator, cleanup);
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
            .{ self.token.literal, self.name.value, value },
        );
    }
};

pub const Index = struct {
    token: token.Token = undefined,
    left: Node = undefined,
    index: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Index {
        return try allocator.create(Index);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        self.left.deinit(allocator, cleanup);
        self.index.deinit(allocator, cleanup);
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
    token: token.Token = undefined,
    function: Node = undefined,
    arguments: []Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Call {
        return try allocator.create(Call);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        self.function.deinit(allocator, cleanup);
        for (self.arguments) |arg| {
            arg.deinit(allocator, cleanup);
        }
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
    token: token.Token = undefined,
    condition: Node = undefined,
    consequence: *Block = undefined,
    alternative: ?*Block = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*If {
        return try allocator.create(If);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        self.condition.deinit(allocator, cleanup);
        self.consequence.deinit(allocator, cleanup);
        if (self.alternative) |alternative| {
            alternative.deinit(allocator, cleanup);
        }
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
        for (self.consequence.statements) |stmt| {
            const stmt_string = try stmt.fmt(allocator);
            try body.appendSlice(stmt_string);
            allocator.free(stmt_string);
        }

        if (self.alternative) |alternative| {
            try body.appendSlice(" else ");
            for (alternative.statements) |stmt| {
                const stmt_string = try stmt.fmt(allocator);
                try body.appendSlice(stmt_string);
                allocator.free(stmt_string);
            }
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
    token: token.Token = undefined,
    operator: token.Token = undefined,
    right: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*UnaryOperation {
        return try allocator.create(UnaryOperation);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        self.right.deinit(allocator, cleanup);
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
    token: token.Token = undefined,
    left: Node = undefined,
    operator: token.Token = undefined,
    right: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*BinaryOperation {
        return try allocator.create(BinaryOperation);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        self.left.deinit(allocator, cleanup);
        self.right.deinit(allocator, cleanup);
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
    token: token.Token = undefined,
    value: []const u8 = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Identifier {
        return try allocator.create(Identifier);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, _: bool) void {
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
    token: token.Token = undefined,
    value: bool = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*BooleanLiteral {
        return try allocator.create(BooleanLiteral);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, _: bool) void {
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
    token: token.Token = undefined,
    value: object.Integer = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*IntegerLiteral {
        return try allocator.create(IntegerLiteral);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, _: bool) void {
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
    token: token.Token = undefined,
    value: []const u8 = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*StringLiteral {
        return try allocator.create(StringLiteral);
    }

    pub fn deinit(
        self: *Self,
        allocator: std.mem.Allocator,
        cleanup: bool,
    ) void {
        if (cleanup) {
            allocator.free(self.value);
        }
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
    token: token.Token = undefined,
    elements: []Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*ArrayLiteral {
        return try allocator.create(ArrayLiteral);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        for (self.elements) |element| {
            element.deinit(allocator, cleanup);
        }
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
    token: token.Token = undefined,
    pairs: std.AutoHashMap(Node, Node) = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*HashLiteral {
        return try allocator.create(HashLiteral);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        var iterator = self.pairs.iterator();
        while (iterator.next()) |value| {
            value.key_ptr.deinit(allocator, cleanup);
            value.value_ptr.deinit(allocator, cleanup);
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
    token: token.Token = undefined,
    parameters: []*Identifier = undefined,
    body: *Block = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*FunctionLiteral {
        return try allocator.create(FunctionLiteral);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator, cleanup: bool) void {
        self.body.deinit(allocator, cleanup);
        for (self.parameters) |param| {
            param.deinit(allocator, cleanup);
        }
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

        var body = std.ArrayList(u8).init(allocator);
        for (self.body.statements) |stmt| {
            const stmt_string = try stmt.fmt(allocator);
            try body.appendSlice(stmt_string);
            allocator.free(stmt_string);
        }

        defer params.deinit();
        defer body.deinit();
        return try std.fmt.allocPrint(
            allocator,
            "{s}({s}){s}",
            .{
                self.token.literal,
                params.items,
                body.items,
            },
        );
    }
};
