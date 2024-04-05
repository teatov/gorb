package lexer

import (
	"gorb/token"
	"testing"
)

func TestNextToken(t *testing.T) {
	input := `let five = 5;
	let ten = 10;
	
	let add = fn(x, y) {
		x + y;
	};
	
	let result = add(five, ten);
	!-/*5;
	5 < 10 > 5;
	
	if (5<10) {
		return true;
	} else {
		return false;
	}
	
	10 == 10;
	10!=9;`

	tests := []struct {
		expectedType    token.TokenType
		expectedLiteral string
	}{
		{token.DECLARATION, "let"},
		{token.IDENTIFIER, "five"},
		{token.ASSIGN, "="},
		{token.INTEGER, "5"},
		{token.TERMINATOR, ";"},
		{token.DECLARATION, "let"},
		{token.IDENTIFIER, "ten"},
		{token.ASSIGN, "="},
		{token.INTEGER, "10"},
		{token.TERMINATOR, ";"},
		{token.DECLARATION, "let"},
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
		{token.ADD, "+"},
		{token.IDENTIFIER, "y"},
		{token.TERMINATOR, ";"},
		{token.BRACE_R, "}"},
		{token.TERMINATOR, ";"},
		{token.DECLARATION, "let"},
		{token.IDENTIFIER, "result"},
		{token.ASSIGN, "="},
		{token.IDENTIFIER, "add"},
		{token.PAREN_L, "("},
		{token.IDENTIFIER, "five"},
		{token.COMMA, ","},
		{token.IDENTIFIER, "ten"},
		{token.PAREN_R, ")"},
		{token.TERMINATOR, ";"},
		{token.NOT, "!"},
		{token.SUBTRACT, "-"},
		{token.DIVIDE, "/"},
		{token.MULTIPLY, "*"},
		{token.INTEGER, "5"},
		{token.TERMINATOR, ";"},
		{token.INTEGER, "5"},
		{token.LESS_THAN, "<"},
		{token.INTEGER, "10"},
		{token.GREATER_THAN, ">"},
		{token.INTEGER, "5"},
		{token.TERMINATOR, ";"},
		{token.IF, "if"},
		{token.PAREN_L, "("},
		{token.INTEGER, "5"},
		{token.LESS_THAN, "<"},
		{token.INTEGER, "10"},
		{token.PAREN_R, ")"},
		{token.BRACE_L, "{"},
		{token.RETURN, "return"},
		{token.TRUE, "true"},
		{token.TERMINATOR, ";"},
		{token.BRACE_R, "}"},
		{token.ELSE, "else"},
		{token.BRACE_L, "{"},
		{token.RETURN, "return"},
		{token.FALSE, "false"},
		{token.TERMINATOR, ";"},
		{token.BRACE_R, "}"},
		{token.INTEGER, "10"},
		{token.EQUALS, "=="},
		{token.INTEGER, "10"},
		{token.TERMINATOR, ";"},
		{token.INTEGER, "10"},
		{token.NOT_EQUALS, "!="},
		{token.INTEGER, "9"},
		{token.TERMINATOR, ";"},
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
