const std = @import("std");
const token = @import("./token.zig");
const object = @import("./object.zig");

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

    pub fn string(
        self: Node,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        return switch (self) {
            .nothing => "NOTHING",

            .program => |node| blk: {
                var node_string = std.ArrayList(u8).init(allocator);
                for (node.statements) |statement| {
                    try node_string.appendSlice(
                        try statement.string(allocator),
                    );
                }
                break :blk node_string.items;
            },

            .block => |node| blk: {
                var node_string = std.ArrayList(u8).init(allocator);
                for (node.statements) |statement| {
                    try node_string.appendSlice(
                        try statement.string(allocator),
                    );
                }
                break :blk node_string.items;
            },

            .@"return" => |node| blk: {
                const return_value: []const u8 = try node.return_value.string(
                    allocator,
                );
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{s} {s};",
                    .{ node.token.literal, return_value },
                );
            },

            .declaration => |node| blk: {
                const value: []const u8 = try node.value.string(
                    allocator,
                );
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{s} {s} = {s};",
                    .{ node.token.literal, node.name.value, value },
                );
            },

            .index => |node| blk: {
                const left: []const u8 = try node.left.string(
                    allocator,
                );
                const index: []const u8 = try node.index.string(
                    allocator,
                );
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "({s}[{s}])",
                    .{ left, index },
                );
            },

            .call => |node| blk: {
                const function: []const u8 = try node.function.string(
                    allocator,
                );
                var args = std.ArrayList(u8).init(allocator);
                for (node.arguments, 0..) |argument, i| {
                    try args.appendSlice(
                        try argument.string(allocator),
                    );
                    if (i < node.arguments.len - 1) {
                        try args.appendSlice(", ");
                    }
                }
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{s}({s})",
                    .{ function, args.items },
                );
            },

            .@"if" => |node| blk: {
                const condition: []const u8 = try node.condition.string(
                    allocator,
                );

                var body = std.ArrayList(u8).init(allocator);
                for (node.consequence.statements) |statement| {
                    try body.appendSlice(
                        try statement.string(allocator),
                    );
                }

                if (node.alternative) |alternative| {
                    try body.appendSlice(" else ");
                    for (alternative.statements) |statement| {
                        try body.appendSlice(
                            try statement.string(allocator),
                        );
                    }
                }

                break :blk try std.fmt.allocPrint(
                    allocator,
                    "if {s} {s}",
                    .{ condition, body.items },
                );
            },

            .unary_operation => |node| blk: {
                const right: []const u8 = try node.right.string(
                    allocator,
                );
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "({s}{s})",
                    .{ node.operator.literal, right },
                );
            },

            .binary_operation => |node| blk: {
                const left: []const u8 = try node.left.string(
                    allocator,
                );
                const right: []const u8 = try node.right.string(
                    allocator,
                );
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "({s} {s} {s})",
                    .{ left, node.operator.literal, right },
                );
            },

            .identifier => |node| blk: {
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{s}",
                    .{node.value},
                );
            },

            .boolean_literal => |node| blk: {
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{any}",
                    .{node.value},
                );
            },

            .integer_literal => |node| blk: {
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{d}",
                    .{node.value},
                );
            },

            .string_literal => |node| blk: {
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{s}",
                    .{node.value},
                );
            },

            .array_literal => |node| blk: {
                var elements = std.ArrayList(u8).init(allocator);
                for (node.elements, 0..) |element, i| {
                    try elements.appendSlice(
                        try element.string(allocator),
                    );
                    if (i < node.elements.len - 1) {
                        try elements.appendSlice(", ");
                    }
                }
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "[{s}]",
                    .{elements.items},
                );
            },

            .hash_literal => |node| blk: {
                var pairs = std.ArrayList(u8).init(allocator);
                var iterator = node.pairs.keyIterator();
                var i: u32 = 0;
                while (iterator.next()) |key| {
                    try pairs.appendSlice(
                        try key.string(allocator),
                    );
                    try pairs.appendSlice(":");
                    try pairs.appendSlice(
                        try node.pairs.get(key.*).?.string(
                            allocator,
                        ),
                    );
                    if (i < node.pairs.count() - 1) {
                        try pairs.appendSlice(", ");
                    }
                    i += 1;
                }
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{{{s}}}",
                    .{pairs.items},
                );
            },

            .function_literal => |node| blk: {
                var params = std.ArrayList(u8).init(allocator);
                for (node.parameters, 0..) |parameter, i| {
                    try params.appendSlice(parameter.value);
                    if (i < node.parameters.len - 1) {
                        try params.appendSlice(", ");
                    }
                }

                var body = std.ArrayList(u8).init(allocator);
                for (node.body.statements) |statement| {
                    try body.appendSlice(
                        try statement.string(allocator),
                    );
                }

                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{s}({s}){s}",
                    .{
                        node.token.literal,
                        params.items,
                        body.items,
                    },
                );
            },
        };
    }
};

pub const Program = struct {
    statements: []Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Program {
        return try allocator.create(Program);
    }
};

pub const Block = struct {
    token: token.Token = undefined,
    statements: []Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Block {
        return try allocator.create(Block);
    }
};

pub const Return = struct {
    token: token.Token = undefined,
    return_value: Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Return {
        return try allocator.create(Return);
    }
};

pub const Declaration = struct {
    token: token.Token = undefined,
    name: *Identifier = undefined,
    value: Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Declaration {
        return try allocator.create(Declaration);
    }
};

pub const Index = struct {
    token: token.Token = undefined,
    left: Node = undefined,
    index: Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Index {
        return try allocator.create(Index);
    }
};

pub const Call = struct {
    token: token.Token = undefined,
    function: Node = undefined,
    arguments: []Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Call {
        return try allocator.create(Call);
    }
};

pub const If = struct {
    token: token.Token = undefined,
    condition: Node = undefined,
    consequence: *Block = undefined,
    alternative: ?*Block = undefined,

    pub fn init(allocator: std.mem.Allocator) !*If {
        return try allocator.create(If);
    }
};

pub const UnaryOperation = struct {
    token: token.Token = undefined,
    operator: token.Token = undefined,
    right: Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*UnaryOperation {
        return try allocator.create(UnaryOperation);
    }
};

pub const BinaryOperation = struct {
    token: token.Token = undefined,
    left: Node = undefined,
    operator: token.Token = undefined,
    right: Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*BinaryOperation {
        return try allocator.create(BinaryOperation);
    }
};

// literals

pub const Identifier = struct {
    token: token.Token = undefined,
    value: []const u8 = undefined,

    pub fn init(allocator: std.mem.Allocator) !*Identifier {
        return try allocator.create(Identifier);
    }
};

pub const BooleanLiteral = struct {
    token: token.Token = undefined,
    value: bool = undefined,

    pub fn init(allocator: std.mem.Allocator) !*BooleanLiteral {
        return try allocator.create(BooleanLiteral);
    }
};

pub const IntegerLiteral = struct {
    token: token.Token = undefined,
    value: object.Integer = undefined,

    pub fn init(allocator: std.mem.Allocator) !*IntegerLiteral {
        return try allocator.create(IntegerLiteral);
    }
};

pub const StringLiteral = struct {
    token: token.Token = undefined,
    value: []const u8 = undefined,

    pub fn init(allocator: std.mem.Allocator) !*StringLiteral {
        return try allocator.create(StringLiteral);
    }
};

pub const ArrayLiteral = struct {
    token: token.Token = undefined,
    elements: []Node = undefined,

    pub fn init(allocator: std.mem.Allocator) !*ArrayLiteral {
        return try allocator.create(ArrayLiteral);
    }
};

pub const HashLiteral = struct {
    token: token.Token = undefined,
    pairs: std.AutoHashMap(Node, Node) = undefined,

    pub fn init(allocator: std.mem.Allocator) !*HashLiteral {
        return try allocator.create(HashLiteral);
    }
};

pub const FunctionLiteral = struct {
    token: token.Token = undefined,
    parameters: []*Identifier = undefined,
    body: *Block = undefined,

    pub fn init(allocator: std.mem.Allocator) !*FunctionLiteral {
        return try allocator.create(FunctionLiteral);
    }
};
