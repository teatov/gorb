package main

import (
	"flag"
	"fmt"
	"gorb/run"
	"os"
	"path"
)

var (
	interactive bool
	version     bool
	debug       bool
)

func init() {
	flag.Usage = func() {
		fmt.Fprintf(
			flag.CommandLine.Output(),
			"usage: %s [options] [<filename>]\n",
			path.Base(os.Args[0]),
		)
		flag.PrintDefaults()
		os.Exit(0)
	}

	flag.BoolVar(&debug, "d", false, "enable debug mode")
	flag.BoolVar(&interactive, "i", false, "enable interactive mode")
	flag.BoolVar(&version, "v", false, "display version information")
}

func main() {
	flag.Parse()
	
	if flag.NArg() == 1 {
		env := run.ExecuteFile(os.Stdout, flag.Arg(0))
		if env != nil && interactive {
			run.StartRepl(os.Stdin, os.Stdout, env)
		}
	} else {
		run.StartRepl(os.Stdin, os.Stdout, nil)
	}
}
