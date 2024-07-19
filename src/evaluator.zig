const std = @import("std");
const ast = @import("./ast.zig");
const object = @import("./object.zig");
const token = @import("./token.zig");
const builtin = @import("./builtin.zig");
const errors = @import("./errors.zig");

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
        const value_string = try node.print(self.allocator);
        defer self.allocator.free(value_string);
        std.debug.print("EVAL {s} - {s}\n", .{ @tagName(node), value_string });
        return switch (node) {
            .block => |obj| try self.evalBlock(obj.*, env),

            //statements

            .@"return" => |obj| blk: {
                var o = try self.eval(obj.return_value, env);
                if (isError(o)) {
                    return o;
                }
                break :blk .{ .return_value = &o };
            },

            .declaration => |obj| blk: {
                const val = try self.eval(obj.value, env);
                if (isError(val)) {
                    return val;
                }

                _ = env.set(obj.name.value, val);

                break :blk .null;
            },

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

                defer self.allocator.free(args);

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

            .boolean_literal => |obj| .{ .boolean = obj.value },

            .integer_literal => |obj| blk: {
                break :blk .{ .integer = obj.value };
            },

            .string_literal => |obj| blk: {
                break :blk .{ .string = obj.value };
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
        };
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

        return try result.toOwnedSlice();
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
        const idx = index.integer;
        const max = array.elements.len - 1;

        if (idx < 0 or idx > max) {
            return .null;
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
            return .null;
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
            return .null;
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
        _: *Self,
        right: object.Object,
    ) !?object.Object {
        return switch (right) {
            .integer => |obj| blk: {
                break :blk .{ .integer = -obj };
            },
            else => null,
        };
    }

    fn evalBooleanNotExpression(
        _: *Self,
        right: object.Object,
    ) object.Object {
        return .{ .boolean = isTruthy(right) };
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
                left.integer,
                right.integer,
            );
        }

        if (left == object.ObjectType.string and right == object.ObjectType.string) {
            obj = try self.evalStringBinaryExpression(
                operator,
                left.string,
                right.string,
            );
        }

        if (obj) |o| {
            return o;
        }

        if (operator.type == token.TokenType.equals) {
            return .{ .boolean = std.meta.eql(left, right) };
        }
        if (operator.type == token.TokenType.not_equals) {
            return .{ .boolean = !std.meta.eql(left, right) };
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
        _: *Self,
        operator: token.Token,
        left: object.Integer,
        right: object.Integer,
    ) !?object.Object {
        return switch (operator.type) {
            .plus => blk: {
                break :blk .{ .integer = left + right };
            },
            .minus => blk: {
                break :blk .{ .integer = left - right };
            },
            .asterisk => blk: {
                break :blk .{ .integer = left * right };
            },
            .slash => blk: {
                break :blk .{ .integer = @divTrunc(left, right) };
            },

            .less_than => .{ .boolean = left < right },
            .greater_than => .{ .boolean = left > right },
            .equals => .{ .boolean = left == right },
            .not_equals => .{ .boolean = left != right },

            else => null,
        };
    }

    fn evalStringBinaryExpression(
        self: *Self,
        operator: token.Token,
        left: object.String,
        right: object.String,
    ) !?object.Object {
        return switch (operator.type) {
            .plus => blk: {
                const str = try std.fmt.allocPrint(
                    self.allocator,
                    "{s}{s}",
                    .{ left, right },
                );
                break :blk .{ .string = str };
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

        const builtin_fn = builtin.builtins.get(node.value);
        if (builtin_fn) |b| {
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
            *object.HashPair,
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
            _ = try pairs.put(hash_key.?, hash_pair);
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

                for (args) |arg| {
                    arg.ref();
                }

                defer {
                    for (args) |arg| {
                        _ = arg.deref(self.allocator);
                    }
                }

                const extended_env = try self.extendFunctionEnv(
                    obj.*,
                    args,
                );

                const val = try self.eval(
                    .{ .block = obj.body },
                    extended_env,
                );

                defer extended_env.deref();
                break :blk self.unwrapReturnValue(val);
            },

            .builtin => |obj| blk: {
                defer _ = function.deref(self.allocator);
                break :blk obj.function(self, args, tok);
            },

            else => blk: {
                const fn_string = function.stringify(self.allocator);
                defer self.allocator.free(fn_string);
                break :blk try self.newError(
                    "{s} is not a function",
                    .{fn_string},
                    tok,
                );
            },
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
            .return_value => |o| o.*,
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

    fn isTruthy(obj: object.Object) bool {
        return switch (obj) {
            .boolean => |o| o,
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

test {
    _ = @import("./tests/evaluator_test.zig");
}
