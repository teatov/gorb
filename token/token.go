package token

import "fmt"

type Token struct {
	Type    TokenType
	Literal string
	Pos     Pos
	Len     int
}

func (t Token) String() string {
	typeAndLiteral := string(t.Type)
	if typeAndLiteral != t.Literal {
		typeAndLiteral += " " + t.Literal
	}
	return fmt.Sprintf("{%s %v}", typeAndLiteral, t.Pos)
}

type TokenType string

func (tt TokenType) String() string { return string(tt) }

type Pos struct {
	Ln  int
	Col int
}

func (p Pos) String() string { return fmt.Sprintf("%d:%d", p.Ln, p.Col) }

const (
	ILLEGAL = "ILLEGAL"
	EOF     = "EOF"

	// identifiers and literals
	IDENTIFIER = "IDENTIFIER"
	INTEGER    = "INTEGER"

	// operators
	ASSIGN       = "="
	PLUS         = "+"
	MINUS        = "-"
	NEGATE       = "!"
	ASTERISK     = "*"
	SLASH        = "/"
	LESS_THAN    = "<"
	GREATER_THAN = ">"
	EQUALS       = "=="
	NOT_EQUALS   = "!="

	// delimiters
	COMMA       = ","
	PAREN_OPEN  = "("
	PAREN_CLOSE = ")"
	BRACE_OPEN  = "{"
	BRACE_CLOSE = "}"
	TERMINATOR  = ";"

	//keywords
	FUNCTION    = "FUNCTION"
	DECLARATION = "DECLARATION"
	TRUE        = "TRUE"
	FALSE       = "FALSE"
	IF          = "IF"
	ELSE        = "ELSE"
	RETURN      = "RETURN"
)

var keywords = map[string]TokenType{
	"fn":     FUNCTION,
	"let":    DECLARATION,
	"true":   TRUE,
	"false":  FALSE,
	"if":     IF,
	"else":   ELSE,
	"return": RETURN,
}

func LookupIdentifier(ident string) TokenType {
	if tok, ok := keywords[ident]; ok {
		return tok
	}
	return IDENTIFIER
}
