package main

// harness bridges the Noon shell (QML) and opencode.
//
// One-shot commands (stdout = single JSON document, for Fetcher):
//   sessions            list sessions from the opencode sqlite db
//   chat <sessionId>    session messages from the sqlite db
//   skills              skill names from SKILL.md files on disk
//   gen-tools <root>    print native opencode tools file for shell IPC
//
// Long-running bridge (stdin/stdout = newline-delimited JSON):
//   acp                 spawn `opencode acp`, translate between the shell's
//                       SSE-style event dialect and ACP JSON-RPC. QML writes
//                       {"cmd":...} lines, Go emits {"type":...} lines.

import (
	"fmt"
	"os"
)

func usage() {
	fmt.Fprintln(os.Stderr, "usage: harness <sessions|chat <sessionId>|skills|gen-tools <shellRoot>|acp>")
	os.Exit(2)
}

func main() {
	if len(os.Args) < 2 {
		usage()
	}
	var err error
	switch os.Args[1] {
	case "sessions":
		err = cmdSessions()
	case "chat":
		if len(os.Args) < 3 {
			usage()
		}
		limit, offset := 10, 0
		if len(os.Args) > 3 {
			fmt.Sscan(os.Args[3], &limit)
		}
		if len(os.Args) > 4 {
			fmt.Sscan(os.Args[4], &offset)
		}
		err = cmdChat(os.Args[2], limit, offset)
	case "skills":
		err = cmdSkills()
	case "gen-tools":
		if len(os.Args) < 3 {
			usage()
		}
		err = cmdGenTools(os.Args[2])
	case "acp":
		err = cmdAcp()
	default:
		usage()
	}
	if err != nil {
		fmt.Fprintln(os.Stderr, "harness:", err)
		os.Exit(1)
	}
}
