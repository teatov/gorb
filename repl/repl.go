package repl

import (
	"bufio"
	"gorb/evaluator"
	"gorb/lexer"
	"gorb/parser"
	"io"
)

const PROMPT = ">> "

func Start(in io.Reader, out io.Writer) {
	scanner := bufio.NewScanner(in)

	for {
		io.WriteString(out, PROMPT)
		scanned := scanner.Scan()
		if !scanned {
			return
		}

		line := scanner.Text()
		l := lexer.New(line)
		p := parser.New(l)

		program := p.ParseProgram()
		if len(p.Errors()) != 0 {
			printParserErrors(out, p.Errors())
			continue
		}
		io.WriteString(out, program.String())
		io.WriteString(out, "\n")

		val := evaluator.Eval(program)
		if val != nil {
			io.WriteString(out, val.Inspect())
			io.WriteString(out, "\n")
		}
	}
}

func printParserErrors(out io.Writer, errors []string) {
	io.WriteString(out, "syntax error!\n")
	for _, msg := range errors {
		io.WriteString(out, "\t"+msg+"\n")
	}
}
