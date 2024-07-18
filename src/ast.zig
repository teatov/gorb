const std = @import("std");
const token = @import("./token.zig");
const object = @import("./object.zig");

pub const PrintError = error{OutOfMemory};

pub const Node = union(enum) {
    nothing: void,
    program: *Program,
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

    pub fn deinit(
        self: Node,
        allocator: std.mem.Allocator,
    ) void {
        _ = switch (self) {
            .nothing => null,
            .program => |node| node.deinit(allocator),
            .block => |node| node.deinit(allocator),
            .@"return" => |node| node.deinit(allocator),
            .declaration => |node| node.deinit(allocator),
            .index => |node| node.deinit(allocator),
            .call => |node| node.deinit(allocator),
            .@"if" => |node| node.deinit(allocator),
            .unary_operation => |node| node.deinit(allocator),
            .binary_operation => |node| node.deinit(allocator),
            .identifier => |node| node.deinit(allocator),
            .boolean_literal => |node| node.deinit(allocator),
            .integer_literal => |node| node.deinit(allocator),
            .string_literal => |node| node.deinit(allocator),
            .array_literal => |node| node.deinit(allocator),
            .hash_literal => |node| node.deinit(allocator),
            .function_literal => |node| node.deinit(allocator),
        };
    }

    pub fn print(
        self: Node,
        allocator: std.mem.Allocator,
    ) PrintError![]const u8 {
        return switch (self) {
            .nothing => "NOTHING",
            .program => |node| try node.print(allocator),
            .block => |node| try node.print(allocator),
            .@"return" => |node| try node.print(allocator),
            .declaration => |node| try node.print(allocator),
            .index => |node| try node.print(allocator),
            .call => |node| try node.print(allocator),
            .@"if" => |node| try node.print(allocator),
            .unary_operation => |node| try node.print(allocator),
            .binary_operation => |node| try node.print(allocator),
            .identifier => |node| try node.print(allocator),
            .boolean_literal => |node| try node.print(allocator),
            .integer_literal => |node| try node.print(allocator),
            .string_literal => |node| try node.print(allocator),
            .array_literal => |node| try node.print(allocator),
            .hash_literal => |node| try node.print(allocator),
            .function_literal => |node| try node.print(allocator),
        };
    }
};

pub const Program = struct {
    statements: []Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Program {
        return try allocator.create(Program);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        for (self.statements) |stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(self.statements);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var node_string = std.ArrayList(u8).init(allocator);
        for (self.statements) |stmt| {
            try node_string.appendSlice(
                try stmt.print(allocator),
            );
        }
        return node_string.items;
    }
};

pub const Block = struct {
    token: token.Token = undefined,
    statements: []Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Block {
        return try allocator.create(Block);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        for (self.statements) |stmt| {
            stmt.deinit(allocator);
        }
        allocator.free(self.statements);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var node_string = std.ArrayList(u8).init(allocator);
        for (self.statements) |stmt| {
            try node_string.appendSlice(
                try stmt.print(allocator),
            );
        }
        return node_string.items;
    }
};

pub const Return = struct {
    token: token.Token = undefined,
    return_value: Node = undefined,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Return {
        return try allocator.create(Return);
    }

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        self.return_value.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const return_value: []const u8 = try self.return_value.print(
            allocator,
        );
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        self.name.deinit(allocator);
        self.value.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const value: []const u8 = try self.value.print(
            allocator,
        );
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        self.left.deinit(allocator);
        self.index.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const left: []const u8 = try self.left.print(
            allocator,
        );
        const index: []const u8 = try self.index.print(
            allocator,
        );
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        self.function.deinit(allocator);
        for (self.arguments) |arg| {
            arg.deinit(allocator);
        }
        allocator.free(self.arguments);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const function: []const u8 = try self.function.print(
            allocator,
        );
        var args = std.ArrayList(u8).init(allocator);
        for (self.arguments, 0..) |arg, i| {
            try args.appendSlice(
                try arg.print(allocator),
            );
            if (i < self.arguments.len - 1) {
                try args.appendSlice(", ");
            }
        }
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        self.condition.deinit(allocator);
        self.consequence.deinit(allocator);
        if (self.alternative) |alternative| {
            alternative.deinit(allocator);
        }
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const condition: []const u8 = try self.condition.print(
            allocator,
        );

        var body = std.ArrayList(u8).init(allocator);
        for (self.consequence.statements) |stmt| {
            try body.appendSlice(
                try stmt.print(allocator),
            );
        }

        if (self.alternative) |alternative| {
            try body.appendSlice(" else ");
            for (alternative.statements) |stmt| {
                try body.appendSlice(
                    try stmt.print(allocator),
                );
            }
        }

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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        self.operator.deinit(allocator);
        self.right.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const right: []const u8 = try self.right.print(
            allocator,
        );
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        self.left.deinit(allocator);
        self.operator.deinit(allocator);
        self.right.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        const left: []const u8 = try self.left.print(
            allocator,
        );
        const right: []const u8 = try self.right.print(
            allocator,
        );
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        allocator.destroy(self);
    }

    pub fn print(
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        for (self.elements) |element| {
            element.deinit(allocator);
        }
        allocator.free(self.elements);
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var elements = std.ArrayList(u8).init(allocator);
        for (self.elements, 0..) |element, i| {
            try elements.appendSlice(
                try element.print(allocator),
            );
            if (i < self.elements.len - 1) {
                try elements.appendSlice(", ");
            }
        }
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        var iterator = self.pairs.iterator();
        while (iterator.next()) |value| {
            value.value_ptr.deinit(allocator);
        }
        self.pairs.deinit();
        allocator.destroy(self);
    }

    pub fn print(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var pairs = std.ArrayList(u8).init(allocator);
        var iterator = self.pairs.keyIterator();
        var i: u32 = 0;
        while (iterator.next()) |key| {
            try pairs.appendSlice(
                try key.print(allocator),
            );
            try pairs.appendSlice(":");
            try pairs.appendSlice(
                try self.pairs.get(key.*).?.print(
                    allocator,
                ),
            );
            if (i < self.pairs.count() - 1) {
                try pairs.appendSlice(", ");
            }
            i += 1;
        }
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

    pub fn deinit(self: *Self, allocator: std.mem.Allocator) void {
        self.token.deinit(allocator);
        self.body.deinit(allocator);
        for (self.parameters) |param| {
            param.deinit(allocator);
        }
        allocator.free(self.parameters);
        allocator.destroy(self);
    }

    pub fn print(
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
            try body.appendSlice(
                try stmt.print(allocator),
            );
        }

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
