package lexer

import (
	"gorb/token"
	"testing"
)

func TestNextToken(t *testing.T) {
	input := `=+(){},;`

	tests := []struct {
		expectedType    token.TokenType
		expectedLiteral string
	}{
		{token.ASSIGN, "="},
		{token.PLUS, "+"},
		{token.PAREN_L, "("},
		{token.PAREN_R, ")"},
		{token.BRACE_L, "{"},
		{token.BRACE_R, "}"},
		{token.COMMA, ","},
		{token.SEMICOLON, ";"},
		{token.EOF, ""},
	}

	l := New(input)

	for i, tt := range tests {
		tok := l.NextToken()

		if tok.Type != tt.expectedType {
			t.Fatalf("tests[%d] - TokenType wrong, expected=%q, got %q", i, tt.expectedType, tok.Type)
		}
	}
}
