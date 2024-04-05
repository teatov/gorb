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

func Eval(node ast.Node) object.Object {
	switch node := node.(type) {
	case *ast.Program:
		return evalProgram(node)

	// statements
	case *ast.ReturnStatement:
		val := Eval(node.ReturnValue)
		if isError(val) {
			return val
		}
		return &object.ReturnValue{Value: val}

	case *ast.ExpressionStatement:
		return Eval(node.Expression)

	case *ast.BlockStatement:
		return evalBlockStatement(node)

	// expressions
	case *ast.IfExpression:
		return evalIfExpression(node)

	case *ast.UnaryExpression:
		right := Eval(node.Right)
		if isError(right) {
			return right
		}
		return evalUnaryExpression(node.Operator, right)

	case *ast.BinaryExpression:
		left := Eval(node.Left)
		if isError(left) {
			return left
		}
		right := Eval(node.Right)
		if isError(right) {
			return right
		}
		return evalBinaryExpression(node.Operator, left, right)

	// literals
	case *ast.BooleanLiteral:
		return boolToBooleanObject(node.Value)

	case *ast.IntegerLiteral:
		return &object.Integer{Value: node.Value}
	}

	return nil
}

func evalProgram(program *ast.Program) object.Object {
	var result object.Object

	for _, stmt := range program.Statements {
		result = Eval(stmt)

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

func evalBlockStatement(block *ast.BlockStatement) object.Object {
	var result object.Object

	for _, stmt := range block.Statements {
		result = Eval(stmt)

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

func evalIfExpression(ie *ast.IfExpression) object.Object {
	condition := Eval(ie.Condition)
	if isError(condition) {
		return condition
	}
	if isTruthy(condition) {
		return Eval(ie.Consequence)
	} else if ie.Alternative != nil {
		return Eval(ie.Alternative)
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
	case token.NEGATE:
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
