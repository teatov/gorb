package main

import (
	"fmt"
	"gorb/repl"
	"os"
)

func main() {
	fmt.Println("Welcome to Gorb.")
	repl.Start(os.Stdin, os.Stdout)
}
