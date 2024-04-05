package evaluator

import (
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
		return evalStatements(node.Statements)

	// statements
	case *ast.ExpressionStatement:
		return Eval(node.Expression)

	// expressions
	case *ast.UnaryExpression:
		right := Eval(node.Right)
		return evalUnaryExpression(node.Operator, right)

	case *ast.BinaryExpression:
		left := Eval(node.Left)
		right := Eval(node.Right)
		return evalBinaryExpression(node.Operator, left, right)

	// literals
	case *ast.BooleanLiteral:
		return boolToBooleanObject(node.Value)

	case *ast.IntegerLiteral:
		return &object.Integer{Value: node.Value}
	}

	return nil
}

func evalStatements(statements []ast.Statement) object.Object {
	var result object.Object

	for _, stmt := range statements {
		result = Eval(stmt)
	}

	return result
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
		return NULL
	}
}

func evalInverseExpression(right object.Object) object.Object {
	if right.Type() != object.INTEGER {
		return NULL
	}

	value := right.(*object.Integer).Value
	return &object.Integer{Value: -value}
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
	default:
		return NULL
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
	default:
		return NULL
	}
}

func boolToBooleanObject(input bool) *object.Boolean {
	if input {
		return TRUE
	}
	return FALSE
}
