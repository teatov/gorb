package run

import (
	"bufio"
	"fmt"
	"gorb/evaluator"
	"gorb/lexer"
	"gorb/object"
	"gorb/parser"
	"io"
	"os"
)

func ExecuteFile(path string, out io.Writer) {
	data, err := os.ReadFile(os.Args[1])

	if err != nil {
		fmt.Println("can't read file:", os.Args[1])
		fmt.Println(err.Error())
		return
	}

	text := string(data)

	env := object.NewEnvironment()
	val := Run(text, env, out)
	fmt.Println()

	if val != nil && val.Type() == object.ERROR {
		io.WriteString(out, val.Inspect())
		io.WriteString(out, "\n")
	}
}

const PROMPT = ">> "

func StartRepl(in io.Reader, out io.Writer) {
	fmt.Println("welcome to gorb.")

	scanner := bufio.NewScanner(in)
	env := object.NewEnvironment()

	for {
		io.WriteString(out, PROMPT)
		scanned := scanner.Scan()
		if !scanned {
			return
		}

		line := scanner.Text()
		val := Run(line, env, out)

		if val != nil {
			io.WriteString(out, val.Inspect())
			io.WriteString(out, "\n")
		}
	}
}

func Run(text string, env *object.Environment, out io.Writer) object.Object {
	l := lexer.New(text)
	p := parser.New(l)

	program := p.ParseProgram()
	if len(p.Errors()) != 0 {
		printParserErrors(out, p.Errors())
		return nil
	}
	// io.WriteString(out, program.String())
	// io.WriteString(out, "\n")

	return evaluator.Eval(program, env)
}

func printParserErrors(out io.Writer, errors []string) {
	io.WriteString(out, "syntax error!\n")
	for _, msg := range errors {
		io.WriteString(out, "\t"+msg+"\n")
	}
}