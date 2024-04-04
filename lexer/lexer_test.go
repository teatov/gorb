package lexer

import (
	"gorb/token"
	"testing"
)

func TestNextToken(t *testing.T) {
	input := `so five = 5;
	so ten = 10;
	
	so add = fn(x, y) {
		x + y;
	};
	
	so result = add(five, ten);
	!-/*5;
	5 < 10 > 5;`

	tests := []struct {
		expectedType    token.TokenType
		expectedLiteral string
	}{
		{token.DECLARATION, "so"},
		{token.IDENTIFIER, "five"},
		{token.ASSIGN, "="},
		{token.INTEGER, "5"},
		{token.SEMICOLON, ";"},
		{token.DECLARATION, "so"},
		{token.IDENTIFIER, "ten"},
		{token.ASSIGN, "="},
		{token.INTEGER, "10"},
		{token.SEMICOLON, ";"},
		{token.DECLARATION, "so"},
		{token.IDENTIFIER, "add"},
		{token.ASSIGN, "="},
		{token.FUNCTION, "fn"},
		{token.PAREN_L, "("},
		{token.IDENTIFIER, "x"},
		{token.COMMA, ","},
		{token.IDENTIFIER, "y"},
		{token.PAREN_R, ")"},
		{token.BRACE_L, "{"},
		{token.IDENTIFIER, "x"},
		{token.PLUS, "+"},
		{token.IDENTIFIER, "y"},
		{token.SEMICOLON, ";"},
		{token.BRACE_R, "}"},
		{token.SEMICOLON, ";"},
		{token.DECLARATION, "so"},
		{token.IDENTIFIER, "result"},
		{token.ASSIGN, "="},
		{token.IDENTIFIER, "add"},
		{token.PAREN_L, "("},
		{token.IDENTIFIER, "five"},
		{token.COMMA, ","},
		{token.IDENTIFIER, "ten"},
		{token.PAREN_R, ")"},
		{token.SEMICOLON, ";"},
		{token.BANG, "!"},
		{token.MINUS, "-"},
		{token.SLASH, "/"},
		{token.ASTERISK, "*"},
		{token.INTEGER, "5"},
		{token.SEMICOLON, ";"},
		{token.INTEGER, "5"},
		{token.LESS_THAN, "<"},
		{token.INTEGER, "10"},
		{token.GREATER_THAN, ">"},
		{token.INTEGER, "5"},
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
