const std = @import("std");
const ast = @import("./ast.zig");
const Token = @import("./Token.zig");
const evaluator = @import("./evaluator.zig");
const errors = @import("./errors.zig");

pub const InspectError = error{OutOfMemory};

pub const Environment = struct {
    store: std.StringHashMap(Object),
    outer: ?*Environment,

    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) !*Environment {
        var env = try allocator.create(Environment);
        env.store = std.StringHashMap(Object).init(allocator);
        env.outer = null;
        env.allocator = allocator;
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

    // pub fn close(self: *Self) void {
    //     var iterator = self.store.iterator();
    //     while (iterator.next()) |value| {
    //         value.value_ptr.deref(self.allocator);
    //     }
    //     self.store.deinit();
    //     self.allocator.destroy(self);
    // }

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

    const Self = @This();

    // pub fn ref(self: Self) void {
    //     _ = switch (self) {
    //         .function => |obj| obj.ref_counter.ref(),
    //         .builtin => |obj| obj.ref_counter.ref(),
    //         .array => |obj| obj.ref_counter.ref(),
    //         .hash => |obj| obj.ref_counter.ref(),
    //         // .return_value => |obj| obj.ref(),
    //         .@"error" => |obj| obj.ref_counter.ref(),
    //         else => null,
    //     };
    // }

    // pub fn deref(
    //     self: Self,
    //     allocator: std.mem.Allocator,
    // ) void {
    //     _ = switch (self) {
    //         .function => |obj| obj.ref_counter.deref(allocator, obj),
    //         .builtin => |obj| obj.ref_counter.deref(allocator, obj),
    //         .array => |obj| obj.ref_counter.deref(allocator, obj),
    //         .hash => |obj| obj.ref_counter.deref(allocator, obj),
    //         // .return_value => |obj| obj.deref(allocator),
    //         .@"error" => |obj| obj.ref_counter.deref(allocator, obj),
    //         else => null,
    //     };
    // }

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
    ) InspectError![]const u8 {
        return switch (self) {
            .function => |obj| obj.inspect(allocator),
            .builtin => |obj| obj.inspect(allocator),
            .null => try std.fmt.allocPrint(allocator, "null", .{}),
            .boolean => |obj| try std.fmt.allocPrint(
                allocator,
                "{s}",
                .{if (obj) "true" else "false"},
            ),
            .integer => |obj| try std.fmt.allocPrint(allocator, "{d}", .{obj}),
            .string => |obj| try std.fmt.allocPrint(allocator, "{s}", .{obj}),
            .array => |obj| obj.inspect(allocator),
            .hash => |obj| obj.inspect(allocator),
            .return_value => |obj| obj.inspect(allocator),
            .@"error" => |obj| obj.inspect(allocator),
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

// pub fn RefCounter(ObjType: type) type {
//     return struct {
//         refs: i32 = undefined,
//         deinit_fn: *const fn (*ObjType, std.mem.Allocator) void = undefined,

//         const Self = @This();

//         pub fn init(
//             allocator: std.mem.Allocator,
//             deinit_fn: *const fn (*ObjType, std.mem.Allocator) void,
//         ) !*Self {
//             const ref_counter = try allocator.create(Self);
//             ref_counter.refs = 1;
//             ref_counter.deinit_fn = deinit_fn;
//             return ref_counter;
//         }

//         pub fn ref(self: *Self) void {
//             self.refs += 1;
//         }

//         pub fn deref(
//             self: *Self,
//             allocator: std.mem.Allocator,
//             obj: *ObjType,
//         ) void {
//             self.refs -= 1;
//             if (self.refs == 0) {
//                 self.deinit_fn(obj, allocator);
//                 allocator.destroy(self);
//             }
//         }
//     };
// }

pub const Function = struct {
    // ref_counter: *RefCounter(Self) = undefined,
    parameters: []*ast.Identifier = undefined,
    body: *ast.Block = undefined,
    env: *Environment = undefined,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        parameters: []*ast.Identifier,
        body: *ast.Block,
        env: *Environment,
    ) !*Self {
        var obj = try allocator.create(Self);
        // obj.ref_counter = try RefCounter(Self).init(allocator, &Self.deinit);
        obj.parameters = parameters;
        obj.body = body;
        obj.env = env;
        return obj;
    }

    // fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    //     const value_string = self.inspect(allocator) catch unreachable;
    //     defer allocator.free(value_string);
    //     // self.env.deinit();
    //     // self.body.deinit(allocator, false);
    //     // for (self.parameters) |param| {
    //     //     param.deinit(allocator, false);
    //     // }
    //     // allocator.free(self.parameters);
    //     allocator.destroy(self);
    // }

    pub fn inspect(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var params = std.ArrayList(u8).init(allocator);
        for (self.parameters, 0..) |param, i| {
            const param_string = try (ast.Node{
                .identifier = param,
            }).fmt(allocator);
            try params.appendSlice(param_string);
            // allocator.free(param_string);
            if (i < self.parameters.len - 1) {
                try params.appendSlice(", ");
            }
        }
        var body = std.ArrayList(u8).init(allocator);
        for (self.body.statements) |node| {
            const node_string = try node.fmt(allocator);
            try body.appendSlice(node_string);
            // allocator.free(node_string);
        }
        // defer params.deinit();
        // defer body.deinit();
        return try std.fmt.allocPrint(
            allocator,
            "fn({s}){{{s}}}",
            .{ params.items, body.items },
        );
    }
};

pub const BuiltinFunction = fn (
    *evaluator.Evaluator,
    []Object,
    Token,
) evaluator.Evaluator.Error!Object;

pub const Builtin = struct {
    // ref_counter: *RefCounter(Self) = undefined,
    function: *const BuiltinFunction = undefined,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        function: *const BuiltinFunction,
    ) !*Self {
        var obj = try allocator.create(Self);
        // obj.ref_counter = try RefCounter(Self).init(allocator, &Self.deinit);
        obj.function = function;
        return obj;
    }

    // fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    //     const value_string = self.inspect(allocator) catch unreachable;
    //     defer allocator.free(value_string);
    //     allocator.destroy(self);
    // }

    pub fn inspect(
        _: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        return try std.fmt.allocPrint(allocator, "builtin function", .{});
    }
};

pub const Array = struct {
    // ref_counter: *RefCounter(Self) = undefined,
    elements: []Object = undefined,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        elements: []Object,
    ) !*Self {
        var obj = try allocator.create(Self);
        // obj.ref_counter = try RefCounter(Self).init(allocator, &Self.deinit);
        obj.elements = elements;
        return obj;
    }

    // fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    //     const value_string = self.inspect(allocator) catch unreachable;
    //     defer allocator.free(value_string);
    //     for (self.elements) |element| {
    //         _ = element.deref(allocator);
    //     }
    //     allocator.free(self.elements);
    //     allocator.destroy(self);
    // }

    pub fn inspect(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var elements = std.ArrayList(u8).init(allocator);
        for (self.elements, 0..) |element, i| {
            const element_string = try element.inspect(allocator);
            try elements.appendSlice(element_string);
            // allocator.free(element_string);
            if (i < self.elements.len - 1) {
                try elements.appendSlice(", ");
            }
        }
        // defer elements.deinit();
        return try std.fmt.allocPrint(
            allocator,
            "[{s}]",
            .{elements.items},
        );
    }
};

pub const HashKey = struct {
    type: ObjectType = undefined,
    value: u64 = undefined,

    const Self = @This();

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

    const Self = @This();

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
    // ref_counter: *RefCounter(Self) = undefined,
    pairs: std.AutoHashMap(HashKey, *HashPair) = undefined,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        pairs: std.AutoHashMap(HashKey, *HashPair),
    ) !*Self {
        var obj = try allocator.create(Self);
        // obj.ref_counter = try RefCounter(Self).init(allocator, &Self.deinit);
        obj.pairs = pairs;
        return obj;
    }

    // fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    //     const value_string = self.inspect(allocator) catch unreachable;
    //     defer allocator.free(value_string);
    //     var iterator = self.pairs.iterator();
    //     while (iterator.next()) |hash_pair| {
    //         const pair = hash_pair.value_ptr.*;
    //         _ = pair.key.deref(allocator);
    //         _ = pair.value.deref(allocator);
    //         // allocator.destroy(hash_pair.key_ptr);
    //         allocator.destroy(pair);
    //     }
    //     self.pairs.deinit();
    //     allocator.destroy(self);
    // }

    pub fn inspect(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        var pairs = std.ArrayList(u8).init(allocator);
        var i: u32 = 0;
        var iterator = self.pairs.iterator();
        while (iterator.next()) |hash_pair| : (i += 1) {
            const pair = hash_pair.value_ptr.*;
            const key_string = try pair.key.inspect(allocator);
            try pairs.appendSlice(key_string);
            // allocator.free(key_string);
            try pairs.appendSlice(": ");
            const value_string = try pair.value.inspect(allocator);
            try pairs.appendSlice(value_string);
            // allocator.free(value_string);
            if (i < self.pairs.count() - 1) {
                try pairs.appendSlice(", ");
            }
        }
        // defer pairs.deinit();
        return try std.fmt.allocPrint(
            allocator,
            "{{{s}}}",
            .{pairs.items},
        );
    }
};

pub const Error = struct {
    // ref_counter: *RefCounter(Self) = undefined,
    message: []const u8 = undefined,
    tok: Token = undefined,

    const Self = @This();

    pub fn init(
        allocator: std.mem.Allocator,
        message: []const u8,
        tok: Token,
    ) !*Self {
        var obj = try allocator.create(Self);
        // obj.ref_counter = try RefCounter(Self).init(allocator, &Self.deinit);
        obj.message = message;
        obj.tok = tok;
        return obj;
    }

    // fn deinit(self: *Self, allocator: std.mem.Allocator) void {
    //     const value_string = self.inspect(allocator) catch unreachable;
    //     defer allocator.free(value_string);
    //     allocator.free(self.message);
    //     allocator.destroy(self);
    // }

    pub fn inspect(
        self: Self,
        allocator: std.mem.Allocator,
    ) ![]const u8 {
        return errors.formatError(allocator, self.message, self.tok);
    }
};
