package token

type TokenType string

const (
	ILLEGAL = "ILLEGAL"
	EOF     = "EOF"
	// identifiers and literals
	IDENTIFIER = "IDENTIFIER"
	INTEGER    = "INTEGER"
	// operators
	ASSIGNMENT   = "="
	PLUS         = "+"
	MINUS        = "-"
	BANG         = "!"
	ASTERISK     = "*"
	SLASH        = "/"
	LESS_THAN    = "<"
	GREATER_THAN = ">"
	EQUALS       = "=="
	NOT_EQUALS   = "!="
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
	TRUE        = "TRUE"
	FALSE       = "FALSE"
	IF          = "IF"
	ELSE        = "ELSE"
	RETURN      = "RETURN"
)

type Token struct {
	Type    TokenType
	Literal string
}

var keywords = map[string]TokenType{
	"fn":     FUNCTION,
	"so":     DECLARATION,
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
