// Command npc is a fast Quickshell IPC client (stdlib only, nothing to install).
//
// Thin CLI over the qipc package (the wire protocol's single source of
// truth); all socket logic lives there.
//
//	npc call <target> <function> [args...]
//
// The return value goes to stdout (like `qs ipc call`), errors to stderr.
// Exit codes: 0 ok, 2 no target, 3 no function, 4 argument mismatch, 1 other.
// Falls back to exec'ing `qs` when no live socket answers.
package main

import (
	"flag"
	"fmt"
	"os"
	"os/exec"
	"syscall"
	"time"

	"weather_service/qipc"
)

func main() {
	sock := flag.String("socket", "", "exact ipc.sock path")
	pid := flag.String("pid", "", "instance pid (qs --pid equivalent)")
	instID := flag.String("id", "", "instance id substring (qs --id equivalent)")
	conf := flag.String("config", "", "forwarded to qs on fallback")
	_ = flag.String("c", "", "shorthand for --config (forwarded to qs on fallback)")
	path := flag.String("path", "", "forwarded to qs on fallback")
	timeout := flag.Duration("timeout", 2*time.Second, "socket timeout")
	flag.Usage = func() {
		fmt.Fprintln(os.Stderr, "usage: npc call <target> <function> [args...]")
		flag.PrintDefaults()
	}
	flag.Parse()

	rest := flag.Args()
	if len(rest) < 3 || rest[0] != "call" {
		flag.Usage()
		os.Exit(1)
	}
	target, fn, args := rest[1], rest[2], rest[3:]
	if target == "" || fn == "" {
		fmt.Fprintln(os.Stderr, "ipc: target and function are required")
		os.Exit(1)
	}

	socks := qipc.Candidates(*sock, *pid, *instID)
	answered := false
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			// ponytail: every socket refused -- usually a shell reload
			// swapping ipc.sock; rescan instead of failing the keybind.
			time.Sleep(200 * time.Millisecond)
			socks = qipc.Candidates(*sock, *pid, *instID)
		}
		for _, s := range socks {
			out, code, err := qipc.Call(s, target, fn, args, *timeout)
			if err != nil {
				continue // stale socket, try next
			}
			answered = true
			if code == qipc.RespNoTarget && *sock == "" && *pid == "" && *instID == "" {
				continue // another live instance may own this target
			}
			if out != "" {
				if code == 0 {
					fmt.Println(out)
				} else {
					fmt.Fprintln(os.Stderr, "ipc: "+out)
				}
			}
			os.Exit(code)
		}
		if answered || len(socks) == 0 {
			break
		}
	}
	if answered {
		fmt.Fprintf(os.Stderr, "ipc: target not found: %s\n", target)
		os.Exit(2)
	}

	// No live socket: hand off to qs, preserving instance selection.
	qs, err := exec.LookPath("qs")
	if err != nil {
		fmt.Fprintln(os.Stderr, "ipc: no running instance and qs not found")
		os.Exit(1)
	}
	qsArgs := []string{"qs"}
	if *conf != "" {
		qsArgs = append(qsArgs, "-c", *conf)
	} else if flag.Lookup("c").Value.String() != "" {
		qsArgs = append(qsArgs, "-c", flag.Lookup("c").Value.String())
	}
	if *path != "" {
		qsArgs = append(qsArgs, "-p", *path)
	}
	if *pid != "" {
		qsArgs = append(qsArgs, "--pid", *pid)
	}
	if *instID != "" {
		qsArgs = append(qsArgs, "--id", *instID)
	}
	qsArgs = append(qsArgs, "ipc", "call", target, fn)
	qsArgs = append(qsArgs, args...)
	_ = syscall.Exec(qs, qsArgs, os.Environ())
	fmt.Fprintln(os.Stderr, "ipc: failed to exec qs")
	os.Exit(1)
}
