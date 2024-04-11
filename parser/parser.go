package parser

import (
	"fmt"
	"gorb/ast"
	"gorb/lexer"
	"gorb/token"
	"strconv"
)

func New(l *lexer.Lexer) *Parser {
	p := &Parser{
		l:      l,
		errors: []string{},
	}

	p.unaryParseFns = make(map[token.TokenType]unaryParseFn)
	p.registerUnary(token.PAREN_OPEN, p.parseGroupedExpression)
	p.registerUnary(token.IF, p.parseIfExpression)
	p.registerUnary(token.NEGATE, p.parseUnaryExpression)
	p.registerUnary(token.MINUS, p.parseUnaryExpression)
	p.registerUnary(token.FUNCTION, p.parseFunctionLiteral)
	p.registerUnary(token.IDENTIFIER, p.parseIdentifier)
	p.registerUnary(token.TRUE, p.parseBoolean)
	p.registerUnary(token.FALSE, p.parseBoolean)
	p.registerUnary(token.INTEGER, p.parseIntegerLiteral)

	p.binaryParseFns = make(map[token.TokenType]binaryParseFn)
	p.registerBinary(token.PAREN_OPEN, p.parseCallExpression)
	p.registerBinary(token.PLUS, p.parseBinaryExpression)
	p.registerBinary(token.MINUS, p.parseBinaryExpression)
	p.registerBinary(token.SLASH, p.parseBinaryExpression)
	p.registerBinary(token.ASTERISK, p.parseBinaryExpression)
	p.registerBinary(token.EQUALS, p.parseBinaryExpression)
	p.registerBinary(token.NOT_EQUALS, p.parseBinaryExpression)
	p.registerBinary(token.LESS_THAN, p.parseBinaryExpression)
	p.registerBinary(token.GREATER_THAN, p.parseBinaryExpression)

	p.nextToken()
	p.nextToken()

	return p
}

type Parser struct {
	l      *lexer.Lexer
	errors []string

	curToken  token.Token
	peekToken token.Token

	unaryParseFns  map[token.TokenType]unaryParseFn
	binaryParseFns map[token.TokenType]binaryParseFn
}

type (
	unaryParseFn  func() ast.Expression
	binaryParseFn func(ast.Expression) ast.Expression
)

func (p *Parser) registerUnary(tt token.TokenType, fn unaryParseFn) {
	p.unaryParseFns[tt] = fn
}

func (p *Parser) registerBinary(tt token.TokenType, fn binaryParseFn) {
	p.binaryParseFns[tt] = fn
}

func (p *Parser) nextToken() {
	p.curToken = p.peekToken
	p.peekToken = p.l.NextToken()
}

func (p *Parser) ParseProgram() *ast.Program {
	program := &ast.Program{}
	program.Statements = []ast.Statement{}

	for !p.curTokenIs(token.EOF) {
		stmt := p.parseStatement()
		if stmt != nil {
			program.Statements = append(program.Statements, stmt)
		}
		p.nextToken()
	}

	return program
}

// statements

func (p *Parser) parseStatement() ast.Statement {
	switch p.curToken.Type {
	case token.RETURN:
		return p.parseReturnStatement()
	case token.DECLARATION:
		return p.parseDeclarationStatement()
	default:
		return p.parseExpressionStatement()
	}
}

func (p *Parser) parseReturnStatement() *ast.ReturnStatement {
	stmt := &ast.ReturnStatement{Token: p.curToken}

	p.nextToken()

	stmt.ReturnValue = p.parseExpression(LOWEST)

	for p.peekTokenIs(token.TERMINATOR) {
		p.nextToken()
	}

	return stmt
}

func (p *Parser) parseDeclarationStatement() *ast.DeclarationStatement {
	stmt := &ast.DeclarationStatement{Token: p.curToken}

	if !p.expectPeek(token.IDENTIFIER) {
		return nil
	}

	stmt.Name = &ast.Identifier{Token: p.curToken, Value: p.curToken.Literal}

	if !p.expectPeek(token.ASSIGN) {
		return nil
	}

	p.nextToken()

	stmt.Value = p.parseExpression(LOWEST)

	for p.peekTokenIs(token.TERMINATOR) {
		p.nextToken()
	}

	return stmt
}

func (p *Parser) parseExpressionStatement() *ast.ExpressionStatement {
	stmt := &ast.ExpressionStatement{Token: p.curToken}

	stmt.Expression = p.parseExpression(LOWEST)

	for p.peekTokenIs(token.TERMINATOR) {
		p.nextToken()
	}

	return stmt
}

func (p *Parser) parseBlockStatement() *ast.BlockStatement {
	block := &ast.BlockStatement{Token: p.curToken}
	block.Statements = []ast.Statement{}

	p.nextToken()

	for !p.curTokenIs(token.BRACE_CLOSE) && !p.curTokenIs(token.EOF) {
		stmt := p.parseStatement()
		if stmt != nil {
			block.Statements = append(block.Statements, stmt)
		}
		p.nextToken()
	}

	return block
}

// expressions

func (p *Parser) parseGroupedExpression() ast.Expression {
	p.nextToken()

	exp := p.parseExpression(LOWEST)

	if !p.expectPeek(token.PAREN_CLOSE) {
		return nil
	}

	return exp
}

func (p *Parser) parseCallExpression(function ast.Expression) ast.Expression {
	exp := &ast.CallExpression{Token: p.curToken, Function: function}
	exp.Arguments = p.parseCallArguments()

	return exp
}

func (p *Parser) parseCallArguments() []ast.Expression {
	args := []ast.Expression{}

	if p.peekTokenIs(token.PAREN_CLOSE) {
		p.nextToken()
		return args
	}

	p.nextToken()

	args = append(args, p.parseExpression(LOWEST))

	for p.peekTokenIs(token.COMMA) {
		p.nextToken()
		p.nextToken()
		args = append(args, p.parseExpression(LOWEST))
	}

	if !p.expectPeek(token.PAREN_CLOSE) {
		return nil
	}

	return args
}

func (p *Parser) parseIfExpression() ast.Expression {
	exp := &ast.IfExpression{Token: p.curToken}

	if !p.expectPeek(token.PAREN_OPEN) {
		return nil
	}

	p.nextToken()
	exp.Condition = p.parseExpression(LOWEST)

	if !p.expectPeek(token.PAREN_CLOSE) {
		return nil
	}

	if !p.expectPeek(token.BRACE_OPEN) {
		return nil
	}

	exp.Consequence = p.parseBlockStatement()

	if p.peekTokenIs(token.ELSE) {
		p.nextToken()

		if !p.expectPeek(token.BRACE_OPEN) {
			return nil
		}

		exp.Alternative = p.parseBlockStatement()
	}

	return exp
}

func (p *Parser) parseExpression(precedence int) ast.Expression {
	parseUnary := p.unaryParseFns[p.curToken.Type]
	if parseUnary == nil {
		p.noUnaryParseFnError(p.curToken.Type)
		return nil
	}
	leftExp := parseUnary()

	for !p.peekTokenIs(token.TERMINATOR) && precedence < p.peekPrecedence() {
		parseBinary := p.binaryParseFns[p.peekToken.Type]
		if parseBinary == nil {
			return leftExp
		}

		p.nextToken()

		leftExp = parseBinary(leftExp)
	}

	return leftExp
}

func (p *Parser) parseUnaryExpression() ast.Expression {
	exp := &ast.UnaryExpression{
		Token:    p.curToken,
		Operator: p.curToken.Type,
	}

	p.nextToken()

	exp.Right = p.parseExpression(UNARY)

	return exp
}

func (p *Parser) parseBinaryExpression(left ast.Expression) ast.Expression {
	exp := &ast.BinaryExpression{
		Token:    p.curToken,
		Operator: p.curToken.Type,
		Left:     left,
	}

	precedence := p.curPrecedence()
	p.nextToken()
	exp.Right = p.parseExpression(precedence)

	return exp
}

// literals

func (p *Parser) parseFunctionLiteral() ast.Expression {
	lit := &ast.FunctionLiteral{Token: p.curToken}

	if !p.expectPeek(token.PAREN_OPEN) {
		return nil
	}

	lit.Parameters = p.parseFunctionParameters()

	if !p.expectPeek(token.BRACE_OPEN) {
		return nil
	}

	lit.Body = p.parseBlockStatement()

	return lit
}

func (p *Parser) parseFunctionParameters() []*ast.Identifier {
	identifiers := []*ast.Identifier{}

	if p.peekTokenIs(token.PAREN_CLOSE) {
		p.nextToken()
		return identifiers
	}

	p.nextToken()

	ident := &ast.Identifier{Token: p.curToken, Value: p.curToken.Literal}
	identifiers = append(identifiers, ident)

	for p.peekTokenIs(token.COMMA) {
		p.nextToken()
		p.nextToken()
		ident := &ast.Identifier{Token: p.curToken, Value: p.curToken.Literal}
		identifiers = append(identifiers, ident)
	}

	if !p.expectPeek(token.PAREN_CLOSE) {
		return nil
	}

	return identifiers
}

func (p *Parser) parseIdentifier() ast.Expression {
	return &ast.Identifier{Token: p.curToken, Value: p.curToken.Literal}
}

func (p *Parser) parseBoolean() ast.Expression {
	return &ast.BooleanLiteral{Token: p.curToken, Value: p.curTokenIs(token.TRUE)}
}

func (p *Parser) parseIntegerLiteral() ast.Expression {
	lit := &ast.IntegerLiteral{Token: p.curToken}

	val, err := strconv.ParseInt(p.curToken.Literal, 0, 64)

	if err != nil {
		msg := fmt.Sprintf(
			"%v could not parse %q as integer",
			p.curToken.Pos,
			p.curToken.Literal,
		)
		p.errors = append(p.errors, msg)
		return nil
	}

	lit.Value = val

	return lit
}

// helpers

func (p *Parser) curTokenIs(tt token.TokenType) bool {
	return p.curToken.Type == tt
}

func (p *Parser) peekTokenIs(tt token.TokenType) bool {
	return p.peekToken.Type == tt
}

func (p *Parser) expectPeek(tt token.TokenType) bool {
	if p.peekTokenIs(tt) {
		p.nextToken()
		return true
	} else {
		p.peekError(tt)
		return false
	}
}

const (
	_ int = iota
	LOWEST
	EQUALITY
	COMPARISON
	SUM
	PRODUCT
	UNARY
	CALL
)

var precedences = map[token.TokenType]int{
	token.EQUALS:       EQUALITY,
	token.NOT_EQUALS:   EQUALITY,
	token.LESS_THAN:    COMPARISON,
	token.GREATER_THAN: COMPARISON,
	token.PLUS:          SUM,
	token.MINUS:     SUM,
	token.ASTERISK:     PRODUCT,
	token.SLASH:       PRODUCT,
	token.PAREN_OPEN:   CALL,
}

func (p *Parser) peekPrecedence() int {
	if p, ok := precedences[p.peekToken.Type]; ok {
		return p
	}

	return LOWEST
}

func (p *Parser) curPrecedence() int {
	if p, ok := precedences[p.curToken.Type]; ok {
		return p
	}

	return LOWEST
}

// errors

func (p *Parser) Errors() []string {
	return p.errors
}

func (p *Parser) peekError(t token.TokenType) {
	msg := fmt.Sprintf(
		"%v expected %s, got %s",
		p.curToken.Pos,
		t,
		p.peekToken.Type,
	)
	p.errors = append(p.errors, msg)
}

func (p *Parser) noUnaryParseFnError(t token.TokenType) {
	msg := fmt.Sprintf(
		"%v no unary parse function for %s found",
		p.curToken.Pos,
		t,
	)
	p.errors = append(p.errors, msg)
}
