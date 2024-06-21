package main

import (
	"gorb/run"
	"os"
)

func main() {
	if len(os.Args) > 1 {
		run.ExecuteFile(os.Args[1], os.Stdout)
		return
	}

	run.StartRepl(os.Stdin, os.Stdout)
}
