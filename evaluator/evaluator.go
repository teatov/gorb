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
		return evalPrefixExpression(node.Operator, right)

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

func evalPrefixExpression(
	operator token.TokenType,
	right object.Object,
) object.Object {
	switch operator {
	case token.NOT:
		return evalNegateOperatorExpression(right)
	default:
		return NULL
	}
}

func evalNegateOperatorExpression(right object.Object) object.Object {
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

func boolToBooleanObject(input bool) *object.Boolean {
	if input {
		return TRUE
	}
	return FALSE
}
