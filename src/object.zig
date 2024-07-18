const std = @import("std");
const ast = @import("./ast.zig");
const token = @import("./token.zig");
const evaluator = @import("./evaluator.zig");
const errors = @import("./errors.zig");

pub const Environment = struct {
    store: std.StringHashMap(Object),
    outer: ?*Environment,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Environment {
        var env = try allocator.create(Environment);
        const s = std.StringHashMap(Object).init(allocator);
        env.store = s;
        env.outer = null;
        return env;
    }

    pub fn initEnclosed(
        allocator: std.mem.Allocator,
        outer_env: *Environment,
    ) !*Environment {
        var env = try Environment.init(allocator);
        env.outer = outer_env;
        return env;
    }

    pub fn get(self: *Self, name: []const u8) ?Object {
        var obj = self.store.get(name);
        if (obj == null) {
            if (self.outer) |outer| {
                obj = outer.get(name);
            }
        }
        return obj;
    }

    pub fn set(
        self: *Self,
        name: []const u8,
        value: Object,
    ) Object {
        _ = self.store.put(name, value) catch |err| std.debug.print(
            "{s}",
            .{@errorName(err)},
        );
        return value;
    }
};

pub const ObjectType = enum {
    function,
    builtin,
    null,
    boolean,
    integer,
    string,
    array,
    hash,
    return_value,
    @"error",
};

pub const Integer = i32;
pub const String = []const u8;

pub const Object = union(ObjectType) {
    function: *Function,
    builtin: *Builtin,
    null: void,
    boolean: bool,
    integer: Integer,
    string: String,
    array: *Array,
    hash: *Hash,
    return_value: *Object,
    @"error": *Error,

    pub fn stringify(
        self: Object,
        allocator: std.mem.Allocator,
    ) []const u8 {
        return std.fmt.allocPrint(
            allocator,
            "[{s}]",
            .{@tagName(self)},
        ) catch |err| @errorName(err);
    }

    pub fn inspect(
        self: Object,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        return switch (self) {
            .function => |obj| blk: {
                var params = std.ArrayList(u8).init(allocator);
                for (obj.parameters, 0..) |param, i| {
                    try params.appendSlice(
                        try (ast.Node{
                            .identifier = param,
                        }).print(allocator),
                    );
                    if (i < obj.parameters.len - 1) {
                        try params.appendSlice(", ");
                    }
                }
                var body = std.ArrayList(u8).init(allocator);
                for (obj.body.statements) |node| {
                    try body.appendSlice(
                        try node.print(allocator),
                    );
                }
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "fn({s}){{{s}}}",
                    .{ params.items, body.items },
                );
            },

            .builtin => "builtin function",

            .null => "null",

            .boolean => |obj| if (obj) "true" else "false",

            .integer => |obj| try std.fmt.allocPrint(
                allocator,
                "{d}",
                .{obj},
            ),

            .string => |obj| obj,

            .array => |obj| blk: {
                var elements = std.ArrayList(u8).init(allocator);
                for (obj.elements, 0..) |element, i| {
                    try elements.appendSlice(
                        try element.inspect(allocator),
                    );
                    if (i < obj.elements.len - 1) {
                        try elements.appendSlice(", ");
                    }
                }
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "[{s}]",
                    .{elements.items},
                );
            },

            .hash => |obj| blk: {
                var pairs = std.ArrayList(u8).init(allocator);
                var i: u32 = 0;
                var iterator = obj.pairs.iterator();
                while (iterator.next()) |hash_pair| : (i += 1) {
                    const pair = hash_pair.value_ptr.*;
                    try pairs.appendSlice(
                        try pair.key.inspect(allocator),
                    );
                    try pairs.appendSlice(": ");
                    try pairs.appendSlice(
                        try pair.value.inspect(allocator),
                    );
                    if (i < obj.pairs.count() - 1) {
                        try pairs.appendSlice(", ");
                    }
                }
                break :blk try std.fmt.allocPrint(
                    allocator,
                    "{{{s}}}",
                    .{pairs.items},
                );
            },

            .return_value => |obj| obj.inspect(allocator),

            .@"error" => |obj| errors.formatError(allocator, obj.message, obj.tok),
        };
    }

    pub fn hashKey(self: Object) ?HashKey {
        return switch (self) {
            .boolean => |obj| .{
                .type = .boolean,
                .value = @intFromBool(obj),
            },
            .integer => |obj| .{
                .type = .integer,
                .value = @intCast(obj),
            },
            .string => |obj| .{
                .type = .string,
                .value = std.hash.Fnv1a_64.hash(obj),
            },
            else => null,
        };
    }
};

pub const Function = struct {
    parameters: []*ast.Identifier = undefined,
    body: *ast.Block = undefined,
    env: *Environment = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        parameters: []*ast.Identifier,
        body: *ast.Block,
        env: *Environment,
    ) !*Function {
        var obj = try allocator.create(Function);
        obj.parameters = parameters;
        obj.body = body;
        obj.env = env;
        return obj;
    }
};

pub const BuiltinFunction = fn (
    *evaluator.Evaluator,
    []Object,
    token.Token,
) evaluator.Evaluator.Error!Object;

pub const Builtin = struct {
    function: *const BuiltinFunction = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        function: *const BuiltinFunction,
    ) !*Builtin {
        var obj = try allocator.create(Builtin);
        obj.function = function;
        return obj;
    }
};

pub const Array = struct {
    elements: []Object = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        elements: []Object,
    ) !*Array {
        var obj = try allocator.create(Array);
        obj.elements = elements;
        return obj;
    }
};

pub const HashKey = struct {
    type: ObjectType = undefined,
    value: u64 = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        @"type": ObjectType,
        value: u64,
    ) !*HashKey {
        var obj = try allocator.create(HashKey);
        obj.type = @"type";
        obj.value = value;
        return obj;
    }
};

pub const HashPair = struct {
    key: Object = undefined,
    value: Object = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        key: Object,
        value: Object,
    ) !*HashPair {
        var obj = try allocator.create(HashPair);
        obj.key = key;
        obj.value = value;
        return obj;
    }
};

pub const Hash = struct {
    pairs: std.AutoHashMap(HashKey, HashPair) = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        pairs: std.AutoHashMap(HashKey, HashPair),
    ) !*Hash {
        var obj = try allocator.create(Hash);
        obj.pairs = pairs;
        return obj;
    }
};

pub const Error = struct {
    message: []const u8 = undefined,
    tok: token.Token = undefined,

    pub fn init(
        allocator: std.mem.Allocator,
        message: []const u8,
        tok: token.Token,
    ) !*Error {
        var obj = try allocator.create(Error);
        obj.message = message;
        obj.tok = tok;
        return obj;
    }
};
