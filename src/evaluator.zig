const std = @import("std");
const ast = @import("./ast.zig");
const object = @import("./object.zig");
const token = @import("./token.zig");
const builtins = @import("./builtins.zig");
const errors = @import("./errors.zig");

pub var @"null" = object.Null{};
pub var @"true" = object.Boolean{ .value = true };
pub var @"false" = object.Boolean{ .value = false };

pub const Evaluator = struct {
    allocator: std.mem.Allocator,

    const Self = @This();

    pub fn init(allocator: std.mem.Allocator) Evaluator {
        return .{ .allocator = allocator };
    }

    pub fn eval(
        self: *Self,
        node: ast.Node,
        env: *object.Environment,
    ) Error!object.Object {
        return switch (node) {
            .program => |obj| self.evalProgram(obj, env),

            //statements

            .@"return" => |obj| blk: {
                const o = try self.eval(obj.return_value, env);
                if (isError(o)) {
                    return o;
                }
                const val = try object.ReturnValue.init(
                    self.allocator,
                    o,
                );
                break :blk .{ .return_value = val };
            },

            .declaration => |obj| blk: {
                const val = try self.eval(obj.value, env);
                if (isError(val)) {
                    return val;
                }

                _ = env.set(obj.name.value, val);

                break :blk .{ .null = &@"null" };
            },

            .block => |obj| try self.evalBlock(obj.*, env),

            // expressions

            .index => |obj| blk: {
                const left = try self.eval(obj.left, env);
                if (isError(left)) {
                    return left;
                }
                const index = try self.eval(obj.index, env);
                if (isError(index)) {
                    return index;
                }

                break :blk try self.evalIndexExpression(
                    left,
                    index,
                    obj.token,
                );
            },

            .call => |obj| blk: {
                const function = try self.eval(obj.function, env);
                if (isError(function)) {
                    return function;
                }
                const args = try self.evalExpressions(
                    obj.arguments,
                    env,
                );
                if (args.len == 1 and isError(args[0])) {
                    return args[0];
                }

                break :blk try self.applyFunction(function, args, obj.token);
            },

            .@"if" => |obj| self.evalIfExpression(obj, env),

            .unary_operation => |obj| blk: {
                const right = try self.eval(obj.right, env);
                if (isError(right)) {
                    return right;
                }

                break :blk try self.evalUnaryExpression(
                    obj.operator,
                    right,
                );
            },

            .binary_operation => |obj| blk: {
                const left = try self.eval(obj.left, env);
                if (isError(left)) {
                    return left;
                }
                const right = try self.eval(obj.right, env);
                if (isError(right)) {
                    return right;
                }

                break :blk try self.evalBinaryExpression(
                    obj.operator,
                    left,
                    right,
                );
            },

            // literals

            .identifier => |obj| self.evalIdentifier(obj, env),

            .boolean_literal => |obj| boolToBooleanObject(
                obj.value,
            ),

            .integer_literal => |obj| blk: {
                const val = try object.Integer.init(
                    self.allocator,
                    obj.value,
                );
                break :blk .{ .integer = val };
            },

            .string_literal => |obj| blk: {
                const val = try object.String.init(
                    self.allocator,
                    obj.value,
                );
                break :blk .{ .string = val };
            },

            .array_literal => |obj| blk: {
                const elements = try self.evalExpressions(
                    obj.elements,
                    env,
                );
                const val = try object.Array.init(
                    self.allocator,
                    elements,
                );
                break :blk .{ .array = val };
            },

            .hash_literal => |obj| try self.evalHashLiteral(
                obj,
                env,
            ),

            .function_literal => |obj| blk: {
                const val = try object.Function.init(
                    self.allocator,
                    obj.parameters,
                    obj.body,
                    env,
                );
                break :blk .{ .function = val };
            },

            else => .{ .null = &@"null" },
        };
    }

    fn evalProgram(
        self: *Self,
        node: *ast.Program,
        env: *object.Environment,
    ) !object.Object {
        var result: object.Object = undefined;

        for (node.statements) |stmt| {
            result = try self.eval(stmt, env);

            _ = switch (result) {
                .return_value => |obj| return obj.value,
                .@"error" => |obj| return .{ .@"error" = obj },
                else => void,
            };
        }

        return result;
    }

    fn evalBlock(
        self: *Self,
        node: ast.Block,
        env: *object.Environment,
    ) !object.Object {
        var result: object.Object = undefined;

        for (node.statements) |stmt| {
            result = try self.eval(stmt, env);

            _ = switch (result) {
                .return_value => return result,
                .@"error" => return result,
                else => void,
            };
        }

        return result;
    }

    // expressions

    fn evalExpressions(
        self: *Self,
        nodes: []ast.Node,
        env: *object.Environment,
    ) ![]object.Object {
        var result = std.ArrayList(object.Object).init(
            self.allocator,
        );

        for (nodes) |n| {
            const val = try self.eval(n, env);
            try result.append(val);
            if (isError(val)) {
                return result.items[result.items.len - 1 .. result.items.len];
            }
        }

        return result.items;
    }

    fn evalIndexExpression(
        self: *Self,
        left: object.Object,
        index: object.Object,
        tok: token.Token,
    ) !object.Object {
        return switch (left) {
            .array => |obj| self.evalArrayIndexExpression(
                obj.*,
                index,
            ),
            .hash => |obj| try self.evalHashIndexExpression(
                obj.*,
                index,
                tok,
            ),
            else => try self.newError(
                "index operator is not supported on {s}",
                .{left.stringify(self.allocator)},
                tok,
            ),
        };
    }

    fn evalArrayIndexExpression(
        _: *Self,
        array: object.Array,
        index: object.Object,
    ) object.Object {
        const idx = index.integer.value;
        const max = array.elements.len - 1;

        if (idx < 0 or idx > max) {
            return .{ .null = &@"null" };
        }

        return array.elements[@intCast(idx)];
    }

    fn evalHashIndexExpression(
        self: *Self,
        hash: object.Hash,
        index: object.Object,
        tok: token.Token,
    ) !object.Object {
        const hash_key = index.hashKey();

        if (hash_key == null) {
            return try self.newError(
                "{s} is unusable as hash key",
                .{index.stringify(self.allocator)},
                tok,
            );
        }

        const pair = hash.pairs.get(hash_key.?);

        if (pair == null) {
            return .{ .null = &@"null" };
        }

        return pair.?.value;
    }

    fn evalIfExpression(
        self: *Self,
        node: *ast.If,
        env: *object.Environment,
    ) !object.Object {
        const condition = try self.eval(node.condition, env);
        if (isError(condition)) {
            return condition;
        }

        if (isTruthy(condition)) {
            return self.eval(.{ .block = node.consequence }, env);
        } else if (node.alternative) |alt| {
            return self.eval(.{ .block = alt }, env);
        } else {
            return .{ .null = &@"null" };
        }
    }

    fn evalUnaryExpression(
        self: *Self,
        operator: token.Token,
        right: object.Object,
    ) !object.Object {
        const obj: ?object.Object = switch (operator.type) {
            .minus => try self.evalNegateExpression(right),
            .bang => self.evalBooleanNotExpression(right),
            else => null,
        };

        if (obj) |o| {
            return o;
        }

        return try self.newError(
            "unknown operation: {s}{s}",
            .{ operator.literal, right.stringify(self.allocator) },
            operator,
        );
    }

    fn evalNegateExpression(
        self: *Self,
        right: object.Object,
    ) !?object.Object {
        return switch (right) {
            .integer => |obj| blk: {
                const val = try object.Integer.init(
                    self.allocator,
                    -obj.value,
                );
                break :blk .{ .integer = val };
            },
            else => null,
        };
    }

    fn evalBooleanNotExpression(
        _: *Self,
        right: object.Object,
    ) object.Object {
        var val = if (isTruthy(right)) @"false" else @"true";
        return .{ .boolean = &val };
    }

    fn evalBinaryExpression(
        self: *Self,
        operator: token.Token,
        left: object.Object,
        right: object.Object,
    ) !object.Object {
        var obj: ?object.Object = null;

        if (left == object.ObjectType.integer and right == object.ObjectType.integer) {
            obj = try self.evalIntegerBinaryExpression(
                operator,
                left.integer.*,
                right.integer.*,
            );
        }

        if (left == object.ObjectType.string and right == object.ObjectType.string) {
            obj = try self.evalStringBinaryExpression(
                operator,
                left.string.*,
                right.string.*,
            );
        }

        if (obj) |o| {
            return o;
        }

        if (operator.type == token.TokenType.equals) {
            return boolToBooleanObject(std.meta.eql(left, right));
        }
        if (operator.type == token.TokenType.not_equals) {
            return boolToBooleanObject(!std.meta.eql(left, right));
        }
        if (@intFromEnum(left) != @intFromEnum(right)) {
            return try self.newError(
                "type mismatch: {s} {s} {s}",
                .{
                    left.stringify(self.allocator),
                    operator.literal,
                    right.stringify(self.allocator),
                },
                operator,
            );
        }
        return try self.newError(
            "unknown operation: {s} {s} {s}",
            .{
                left.stringify(self.allocator),
                operator.literal,
                right.stringify(self.allocator),
            },
            operator,
        );
    }

    fn evalIntegerBinaryExpression(
        self: *Self,
        operator: token.Token,
        left: object.Integer,
        right: object.Integer,
    ) !?object.Object {
        const left_val = left.value;
        const right_val = right.value;

        return switch (operator.type) {
            .plus => blk: {
                const val = try object.Integer.init(
                    self.allocator,
                    left_val + right_val,
                );
                break :blk .{ .integer = val };
            },
            .minus => blk: {
                const val = try object.Integer.init(
                    self.allocator,
                    left_val - right_val,
                );
                break :blk .{ .integer = val };
            },
            .asterisk => blk: {
                const val = try object.Integer.init(
                    self.allocator,
                    left_val * right_val,
                );
                break :blk .{ .integer = val };
            },
            .slash => blk: {
                const val = try object.Integer.init(
                    self.allocator,
                    @divTrunc(left_val, right_val),
                );
                break :blk .{ .integer = val };
            },

            .less_than => boolToBooleanObject(left_val < right_val),
            .greater_than => boolToBooleanObject(left_val > right_val),
            .equals => boolToBooleanObject(left_val == right_val),
            .not_equals => boolToBooleanObject(left_val != right_val),

            else => null,
        };
    }

    fn evalStringBinaryExpression(
        self: *Self,
        operator: token.Token,
        left: object.String,
        right: object.String,
    ) !?object.Object {
        const left_val = left.value;
        const right_val = right.value;

        return switch (operator.type) {
            .plus => blk: {
                const str = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}{s}",
                    .{ left_val, right_val },
                );
                const val = try object.String.init(
                    self.allocator,
                    str,
                );
                break :blk .{ .string = val };
            },

            else => null,
        };
    }

    // literals

    fn evalIdentifier(
        self: *Self,
        node: *ast.Identifier,
        env: *object.Environment,
    ) !object.Object {
        const val = env.get(node.value);

        if (val) |v| {
            return v;
        }

        const builtin = try builtins.getBuiltin(self.allocator, node.value);
        if (builtin) |b| {
            const v = try object.Builtin.init(self.allocator, b);
            return .{ .builtin = v };
        }

        return try self.newError(
            "identifier '{s}' not found",
            .{node.value},
            node.token,
        );
    }

    fn evalHashLiteral(
        self: *Self,
        node: *ast.HashLiteral,
        env: *object.Environment,
    ) !object.Object {
        var pairs = std.AutoHashMap(
            object.HashKey,
            object.HashPair,
        ).init(self.allocator);

        var iterator = node.pairs.iterator();
        while (iterator.next()) |pair| {
            const key = try self.eval(pair.key_ptr.*, env);
            if (isError(key)) {
                return key;
            }

            const hash_key = key.hashKey();
            if (hash_key == null) {
                return try self.newError(
                    "{s} is unusable as hash key",
                    .{key.stringify(self.allocator)},
                    node.token,
                );
            }

            const value = try self.eval(pair.value_ptr.*, env);
            if (isError(value)) {
                return value;
            }

            const hash_pair = try object.HashPair.init(
                self.allocator,
                key,
                value,
            );
            _ = try pairs.put(hash_key.?, hash_pair.*);
        }

        const val = try object.Hash.init(self.allocator, pairs);
        return .{ .hash = val };
    }

    // function

    fn applyFunction(
        self: *Self,
        function: object.Object,
        args: []object.Object,
        tok: token.Token,
    ) !object.Object {
        return switch (function) {
            .function => |obj| blk: {
                if (obj.parameters.len != args.len) {
                    break :blk try self.invalidArgumentAmountError(
                        obj.parameters.len,
                        args.len,
                        tok,
                    );
                }

                const extended_env = try self.extendFunctionEnv(
                    obj.*,
                    args,
                );
                const val = try self.eval(
                    .{ .block = obj.body },
                    extended_env,
                );
                break :blk self.unwrapReturnValue(val);
            },

            .builtin => |obj| obj.function(self, args, tok),

            else => try self.newError(
                "{s} is not a function",
                .{function.stringify(self.allocator)},
                tok,
            ),
        };
    }

    fn extendFunctionEnv(
        self: *Self,
        function: object.Function,
        args: []object.Object,
    ) !*object.Environment {
        var env = try object.Environment.initEnclosed(
            self.allocator,
            function.env,
        );

        for (function.parameters, 0..) |param, i| {
            _ = env.set(param.value, args[i]);
        }

        return env;
    }

    fn unwrapReturnValue(
        _: *Self,
        obj: object.Object,
    ) object.Object {
        return switch (obj) {
            .return_value => |o| o.value,
            else => obj,
        };
    }

    // error

    pub fn newError(
        self: *Self,
        comptime format: []const u8,
        a: anytype,
        tok: token.Token,
    ) !object.Object {
        const msg = try std.fmt.allocPrint(
            self.allocator,
            format,
            a,
        );
        const err = try object.Error.init(
            self.allocator,
            msg,
            tok,
        );
        return .{ .@"error" = err };
    }

    pub fn invalidArgumentAmountError(
        self: *Self,
        expect: usize,
        got: usize,
        tok: token.Token,
    ) !object.Object {
        return try self.newError(
            "expected {d} argument{s}, got {d}",
            .{
                expect,
                if (expect % 10 == 1) "" else "s",
                got,
            },
            tok,
        );
    }

    // helpers

    fn isError(obj: object.Object) bool {
        return switch (obj) {
            .@"error" => true,
            else => false,
        };
    }

    fn boolToBooleanObject(input: bool) object.Object {
        return .{ .boolean = if (input) &@"true" else &@"false" };
    }

    fn isTruthy(obj: object.Object) bool {
        return switch (obj) {
            .boolean => |o| o.value,
            .null => false,
            else => true,
        };
    }

    pub const Error = error{
        OutOfMemory,
        InputOutput,
        SystemResources,
        OperationAborted,
        BrokenPipe,
        ConnectionResetByPeer,
        WouldBlock,
        AccessDenied,
        Unexpected,
        DiskQuota,
        FileTooBig,
        NoSpaceLeft,
        DeviceBusy,
        InvalidArgument,
        NotOpenForWriting,
        LockViolation,
    };
};

const evaluator_test = @import("./tests/evaluator_test.zig");

test {
    evaluator_test.hack();
}
