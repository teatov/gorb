package lexer

import (
	"gorb/token"
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
			tok.Pos = l.pos
			ch := l.ch
			l.readChar()
			tok.Type = token.EQUALS
			tok.Literal = string(ch) + string(l.ch)
			tok.Len = len(tok.Literal)
		} else {
			tok = newToken(token.ASSIGNMENT, l.ch, l.pos)
		}
	case '+':
		tok = newToken(token.PLUS, l.ch, l.pos)
	case '-':
		tok = newToken(token.MINUS, l.ch, l.pos)
	case '!':
		if l.peekChar() == '=' {
			tok.Pos = l.pos
			ch := l.ch
			l.readChar()
			tok.Type = token.NOT_EQUALS
			tok.Literal = string(ch) + string(l.ch)
			tok.Len = len(tok.Literal)
		} else {
			tok = newToken(token.BANG, l.ch, l.pos)
		}
	case '*':
		tok = newToken(token.ASTERISK, l.ch, l.pos)
	case '/':
		tok = newToken(token.SLASH, l.ch, l.pos)
	case '<':
		tok = newToken(token.LESS_THAN, l.ch, l.pos)
	case '>':
		tok = newToken(token.GREATER_THAN, l.ch, l.pos)
	case ',':
		tok = newToken(token.COMMA, l.ch, l.pos)
	case '(':
		tok = newToken(token.PAREN_L, l.ch, l.pos)
	case ')':
		tok = newToken(token.PAREN_R, l.ch, l.pos)
	case '{':
		tok = newToken(token.BRACE_L, l.ch, l.pos)
	case '}':
		tok = newToken(token.BRACE_R, l.ch, l.pos)
	case ';':
		tok = newToken(token.SEMICOLON, l.ch, l.pos)
	case '\n':
		l.pos.Ln++
		l.pos.Col = 0
	case 0:
		tok = newToken(token.EOF, l.ch, l.pos)
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
			tok = newToken(token.ILLEGAL, l.ch, l.pos)
		}
	}

	l.readChar()
	return tok
}

func newToken(tokenType token.TokenType, ch byte, pos token.Pos) token.Token {
	return token.Token{Type: tokenType, Literal: string(ch), Pos: pos, Len: 1}
}

func (l *Lexer) skipWhitespace() {
	for isWhitespace(l.ch) {
		l.readChar()
	}
}

func isWhitespace(ch byte) bool {
	return ch == ' ' || ch == '\t' || ch == '\n' || ch == '\r'
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
