package evaluator

import (
	"gorb/ast"
	"gorb/object"
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

func boolToBooleanObject(input bool) *object.Boolean {
	if input {
		return TRUE
	}
	return FALSE
}
