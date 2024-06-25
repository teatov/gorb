package evaluator

import (
	"fmt"
	"gorb/ast"
	"gorb/object"
	"gorb/token"
)

var (
	NULL  = &object.Null{}
	TRUE  = &object.Boolean{Value: true}
	FALSE = &object.Boolean{Value: false}
)

func Eval(node ast.Node, env *object.Environment) object.Object {
	switch node := node.(type) {
	case *ast.Program:
		return evalProgram(node, env)

	// statements
	case *ast.ReturnStatement:
		val := Eval(node.ReturnValue, env)
		if isError(val) {
			return val
		}
		return &object.ReturnValue{Value: val}

	case *ast.DeclarationStatement:
		val := Eval(node.Value, env)
		if isError(val) {
			return val
		}
		env.Set(node.Name.Value, val)

	case *ast.ExpressionStatement:
		return Eval(node.Expression, env)

	case *ast.BlockStatement:
		return evalBlockStatement(node, env)

	// expressions
	case *ast.IndexExpression:
		left := Eval(node.Left, env)
		if isError(left) {
			return left
		}
		index := Eval(node.Index, env)
		if isError(index) {
			return index
		}
		return evalIndexExpression(left, index)

	case *ast.CallExpression:
		fn := Eval(node.Function, env)
		if isError(fn) {
			return fn
		}
		args := evalExpressions(node.Arguments, env)
		if len(args) == 1 && isError(args[0]) {
			return args[0]
		}
		return applyFunction(fn, args)

	case *ast.IfExpression:
		return evalIfExpression(node, env)

	case *ast.UnaryExpression:
		right := Eval(node.Right, env)
		if isError(right) {
			return right
		}
		return evalUnaryExpression(node.Operator, right)

	case *ast.BinaryExpression:
		left := Eval(node.Left, env)
		if isError(left) {
			return left
		}
		right := Eval(node.Right, env)
		if isError(right) {
			return right
		}
		return evalBinaryExpression(node.Operator, left, right)

	// literals
	case *ast.FunctionLiteral:
		params := node.Parameters
		body := node.Body
		return &object.Function{Parameters: params, Body: body, Env: env}

	case *ast.Identifier:
		return evalIdentifier(node, env)

	case *ast.BooleanLiteral:
		return boolToBooleanObject(node.Value)

	case *ast.IntegerLiteral:
		return &object.Integer{Value: node.Value}

	case *ast.StringLiteral:
		return &object.String{Value: node.Value}

	case *ast.ArrayLiteral:
		elements := evalExpressions(node.Elements, env)
		if len(elements) == 1 && isError(elements[0]) {
			return elements[0]
		}
		return &object.Array{Elements: elements}

	case *ast.HashLiteral:
		return evalHashLiteral(node, env)

	}

	return nil
}

func evalProgram(program *ast.Program, env *object.Environment) object.Object {
	var result object.Object

	for _, stmt := range program.Statements {
		result = Eval(stmt, env)

		switch result := result.(type) {
		case *object.ReturnValue:
			return result.Value
		case *object.Error:
			return result
		}
	}

	return result
}

// statements

func evalBlockStatement(
	block *ast.BlockStatement,
	env *object.Environment,
) object.Object {
	var result object.Object

	for _, stmt := range block.Statements {
		result = Eval(stmt, env)

		if result != nil {
			rt := result.Type()
			if rt == object.RETURN_VALUE || rt == object.ERROR {
				return result
			}
		}
	}

	return result
}

// expressions

func evalExpressions(
	exps []ast.Expression,
	env *object.Environment,
) []object.Object {
	var result []object.Object

	for _, e := range exps {
		val := Eval(e, env)
		if isError(val) {
			return []object.Object{val}
		}
		result = append(result, val)
	}

	return result
}

func evalIndexExpression(left, index object.Object) object.Object {
	switch {
	case left.Type() == object.ARRAY && index.Type() == object.INTEGER:
		return evalArrayIndexExpression(left, index)
	case left.Type() == object.HASH:
		return evalHashIndexExpression(left, index)
	default:
		return newError("index operator not supported: %s", left.Type())
	}
}

func evalArrayIndexExpression(array, index object.Object) object.Object {
	arrayObject := array.(*object.Array)
	idx := index.(*object.Integer).Value
	max := int64(len(arrayObject.Elements) - 1)

	if idx < 0 || idx > max {
		return NULL
	}

	return arrayObject.Elements[idx]
}

func evalHashIndexExpression(hash, index object.Object) object.Object {
	hashObject := hash.(*object.Hash)

	key, ok := index.(object.Hashable)
	if !ok {
		return newError("unusable as hash key: %s", index.Type())
	}

	pair, ok := hashObject.Pairs[key.HashKey()]
	if !ok {
		return NULL
	}

	return pair.Value
}

func evalIfExpression(
	ie *ast.IfExpression,
	env *object.Environment,
) object.Object {
	condition := Eval(ie.Condition, env)
	if isError(condition) {
		return condition
	}

	if isTruthy(condition) {
		return Eval(ie.Consequence, env)
	} else if ie.Alternative != nil {
		return Eval(ie.Alternative, env)
	} else {
		return NULL
	}
}

func evalUnaryExpression(
	operator token.TokenType,
	right object.Object,
) object.Object {
	switch operator {
	case token.MINUS:
		return evalInverseExpression(right)
	case token.BANG:
		return evalNegateExpression(right)
	default:
		return newError("unknown operation: %s%s", operator, right.Type())
	}
}

func evalInverseExpression(right object.Object) object.Object {
	if right.Type() != object.INTEGER {
		return newError("unknown operation: -%s", right.Type())
	}

	val := right.(*object.Integer).Value
	return &object.Integer{Value: -val}
}

func evalNegateExpression(right object.Object) object.Object {
	switch right {
	case TRUE:
		return FALSE
	case FALSE:
		return TRUE
	case NULL:
		return TRUE
	default:
		return FALSE
	}
}

func evalBinaryExpression(
	operator token.TokenType,
	left, right object.Object,
) object.Object {
	switch {
	case left.Type() == object.INTEGER && right.Type() == object.INTEGER:
		return evalIntegerBinaryExpression(operator, left, right)

	case left.Type() == object.STRING && right.Type() == object.STRING:
		return evalStringBinaryExpression(operator, left, right)

	case operator == "==":
		return boolToBooleanObject(left == right)
	case operator == "!=":
		return boolToBooleanObject(left != right)

	case left.Type() != right.Type():
		return newError(
			"type mismatch: %s %s %s",
			left.Type(),
			operator,
			right.Type(),
		)
	default:
		return newError(
			"unknown operation: %s %s %s",
			left.Type(),
			operator,
			right.Type(),
		)
	}
}

func evalIntegerBinaryExpression(
	operator token.TokenType,
	left, right object.Object,
) object.Object {
	leftVal := left.(*object.Integer).Value
	rightVal := right.(*object.Integer).Value

	switch operator {
	case token.PLUS:
		return &object.Integer{Value: leftVal + rightVal}
	case token.MINUS:
		return &object.Integer{Value: leftVal - rightVal}
	case token.ASTERISK:
		return &object.Integer{Value: leftVal * rightVal}
	case token.SLASH:
		return &object.Integer{Value: leftVal / rightVal}

	case token.LESS_THAN:
		return boolToBooleanObject(leftVal < rightVal)
	case token.GREATER_THAN:
		return boolToBooleanObject(leftVal > rightVal)
	case token.EQUALS:
		return boolToBooleanObject(leftVal == rightVal)
	case token.NOT_EQUALS:
		return boolToBooleanObject(leftVal != rightVal)

	default:
		return newError(
			"unknown operation: %s %s %s",
			left.Type(),
			operator,
			right.Type(),
		)
	}
}

func evalStringBinaryExpression(
	operator token.TokenType,
	left, right object.Object,
) object.Object {
	if operator != token.PLUS {
		return newError(
			"unknown operation: %s %s %s",
			left.Type(),
			operator,
			right.Type(),
		)
	}

	leftVal := left.(*object.String).Value
	rightVal := right.(*object.String).Value

	return &object.String{Value: leftVal + rightVal}
}

// literals

func evalIdentifier(
	node *ast.Identifier,
	env *object.Environment,
) object.Object {
	if val, ok := env.Get(node.Value); ok {
		return val
	}

	if builtin, ok := builtins[node.Value]; ok {
		return builtin
	}

	return newError("identifier not found: " + node.Value)
}

func evalHashLiteral(
	node *ast.HashLiteral,
	env *object.Environment,
) object.Object {
	pairs := make(map[object.HashKey]object.HashPair)

	for keyNode, valueNode := range node.Pairs {
		key := Eval(keyNode, env)
		if isError(key) {
			return key
		}

		hashKey, ok := key.(object.Hashable)
		if !ok {
			return newError("unusable as hash key: %s", key.Type())
		}

		value := Eval(valueNode, env)
		if isError(value) {
			return value
		}

		hashed := hashKey.HashKey()
		pairs[hashed] = object.HashPair{Key: key, Value: value}
	}

	return &object.Hash{Pairs: pairs}
}

// function

func applyFunction(function object.Object, args []object.Object) object.Object {
	switch function := function.(type) {

	case *object.Function:
		extendedEnv := extendFunctionEnv(function, args)
		evaluated := Eval(function.Body, extendedEnv)
		return unwrapReturnValue(evaluated)

	case *object.Builtin:
		return function.Fn(args...)

	default:
		return newError("not a function: %s", function.Type())
	}
}

func extendFunctionEnv(
	fn *object.Function,
	args []object.Object,
) *object.Environment {
	env := object.NewEnclosedEnvironment(fn.Env)

	for i, param := range fn.Parameters {
		env.Set(param.Value, args[i])
	}

	return env
}

func unwrapReturnValue(obj object.Object) object.Object {
	if val, ok := obj.(*object.ReturnValue); ok {
		return val.Value
	}

	return obj
}

// helpers

func boolToBooleanObject(input bool) *object.Boolean {
	if input {
		return TRUE
	}
	return FALSE
}

func isTruthy(obj object.Object) bool {
	switch obj {
	case NULL:
		return false
	case TRUE:
		return true
	case FALSE:
		return false
	default:
		return true
	}
}

func isError(obj object.Object) bool {
	if obj != nil {
		return obj.Type() == object.ERROR
	}

	return false
}

func newError(format string, a ...interface{}) *object.Error {
	return &object.Error{Message: fmt.Sprintf(format, a...)}
}
