package lexer

import (
	"gorb/token"
	"strings"
)

func New(input string) *Lexer {
	l := &Lexer{input: input, pos: token.Pos{Ln: 1, Col: 0}}
	l.readChar()
	return l
}

type Lexer struct {
	input        string
	position     int
	readPosition int
	ch           byte
	pos          token.Pos
}

func (l *Lexer) readChar() {
	if l.readPosition >= len(l.input) {
		l.ch = 0
	} else {
		l.ch = l.input[l.readPosition]
	}
	l.position = l.readPosition
	l.readPosition++
	l.pos.Col++
}

func (l *Lexer) NextToken() token.Token {
	var tok token.Token

	l.skipWhitespace()

	switch l.ch {
	case '=':
		if l.peekChar() == '=' {
			ch := l.ch
			l.readChar()
			literal := string(ch) + string(l.ch)
			tok = token.Token{Type: token.EQUALS, Literal: literal}
		} else {
			tok = l.newToken(token.ASSIGN)
		}
	case '+':
		tok = l.newToken(token.PLUS)
	case '-':
		tok = l.newToken(token.MINUS)
	case '!':
		if l.peekChar() == '=' {
			ch := l.ch
			l.readChar()
			literal := string(ch) + string(l.ch)
			tok = token.Token{Type: token.NOT_EQUALS, Literal: literal}
		} else {
			tok = l.newToken(token.BANG)
		}
	case '*':
		tok = l.newToken(token.ASTERISK)
	case '/':
		tok = l.newToken(token.SLASH)
	case '<':
		tok = l.newToken(token.LESS_THAN)
	case '>':
		tok = l.newToken(token.GREATER_THAN)
	case ',':
		tok = l.newToken(token.COMMA)
	case '(':
		tok = l.newToken(token.PAREN_OPEN)
	case ')':
		tok = l.newToken(token.PAREN_CLOSE)
	case '{':
		tok = l.newToken(token.BRACE_OPEN)
	case '}':
		tok = l.newToken(token.BRACE_CLOSE)
	case '[':
		tok = l.newToken(token.BRACKET_OPEN)
	case ']':
		tok = l.newToken(token.BRACKET_CLOSE)
	case ':':
		tok = l.newToken(token.COLON)
	case ';':
		tok = l.newToken(token.SEMICOLON)
	case '"':
		tok.Pos = l.pos
		tok.Literal = l.readString()
		tok.Type = token.STRING
		tok.Len = len(tok.Literal)
	case '\n':
		l.pos.Ln++
		l.pos.Col = 0
	case 0:
		tok = l.newToken(token.EOF)
	default:
		if isLetter(l.ch) {
			tok.Pos = l.pos
			tok.Literal = l.readIdentifier()
			tok.Type = token.LookupIdentifier(tok.Literal)
			tok.Len = len(tok.Literal)
			return tok
		} else if isDigit(l.ch) {
			tok.Pos = l.pos
			tok.Type = token.INTEGER
			tok.Literal = l.readNumber()
			tok.Len = len(tok.Literal)
			return tok
		} else {
			tok = l.newToken(token.ILLEGAL)
		}
	}

	l.readChar()
	return tok
}

func (l *Lexer) newToken(tt token.TokenType) token.Token {
	return token.Token{Type: tt, Literal: string(l.ch), Pos: l.pos, Len: 1}
}

func (l *Lexer) skipWhitespace() {
	for l.ch == ' ' || l.ch == '\t' || l.ch == '\n' || l.ch == '\r' {
		l.readChar()
	}
}

func (l *Lexer) peekChar() byte {
	if l.readPosition >= len(l.input) {
		return 0
	} else {
		return l.input[l.readPosition]
	}
}

func isLetter(ch byte) bool {
	isLowercaseLetter := 'a' <= ch && ch <= 'z'
	isUppercaseLetter := 'A' <= ch && ch <= 'Z'
	isUnderscore := ch == '_'
	return isLowercaseLetter || isUppercaseLetter || isUnderscore
}

func (l *Lexer) readIdentifier() string {
	position := l.position
	for isLetter(l.ch) {
		l.readChar()
	}
	return l.input[position:l.position]
}

func isDigit(ch byte) bool {
	return '0' <= ch && ch <= '9'
}

func (l *Lexer) readNumber() string {
	position := l.position
	for isDigit(l.ch) {
		l.readChar()
	}
	return l.input[position:l.position]
}

func (l *Lexer) readString() string {
	b := strings.Builder{}

	for {
		l.readChar()
		if l.ch == '\\' {
			switch l.peekChar() {
			case 'n':
				b.WriteByte('\n')
			case 'r':
				b.WriteByte('\r')
			case 't':
				b.WriteByte('\t')
			case '\\':
				b.WriteByte('\\')
			case '"':
				b.WriteByte('"')
			}

			l.readChar()
			continue
		}

		if l.ch == '"' || l.ch == 0 {
			break
		}

		b.WriteByte(l.ch)
	}
	return b.String()
}
