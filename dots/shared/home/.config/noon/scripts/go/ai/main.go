package main


import (
	"fmt"
	"os"
)

func usage() {
	fmt.Fprintln(os.Stderr, "usage: harness <sessions|chat <sessionId>|skills|gen-tools <shellRoot>|sync-config <globalCfg> <sideDir>|acp>")
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
	case "sync-config":
		if len(os.Args) < 4 {
			usage()
		}
		err = cmdSyncConfig(os.Args[2], os.Args[3])
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
