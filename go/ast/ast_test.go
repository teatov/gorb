package ast

import (
	"gorb/token"
	"testing"
)

func TestString(t *testing.T) {
	program := &Program{
		Statements: []Statement{
			&DeclarationStatement{
				Token: token.Token{Type: token.ASSIGN, Literal: "let"},
				Name: &Identifier{
					Token: token.Token{Type: token.IDENTIFIER, Literal: "myVar"},
					Value: "myVar",
				},
				Value: &Identifier{
					Token: token.Token{Type: token.IDENTIFIER, Literal: "anotherVar"},
					Value: "anotherVar",
				},
			},
		},
	}

	if program.String() != "let myVar = anotherVar;" {
		t.Errorf("program.String() wrong. got=%q", program.String())
	}
}
