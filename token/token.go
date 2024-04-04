package token

type TokenType string

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
	BANG         = "!"
	ASTERISK     = "*"
	SLASH        = "/"
	LESS_THAN    = "<"
	GREATER_THAN = ">"
	// delimiters
	COMMA     = ","
	SEMICOLON = ";"
	PAREN_L   = "("
	PAREN_R   = ")"
	BRACE_L   = "{"
	BRACE_R   = "}"
	//keywords
	FUNCTION    = "FUNCTION"
	DECLARATION = "DECLARATION"
)

type Token struct {
	Type    TokenType
	Literal string
}

var keywords = map[string]TokenType{
	"fn": FUNCTION,
	"so": DECLARATION,
}

func LookupIdentifier(ident string) TokenType {
	if tok, ok := keywords[ident]; ok {
		return tok
	}
	return IDENTIFIER
}
