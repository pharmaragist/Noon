// Command npc is a fast Quickshell IPC client (stdlib only, nothing to install).
//
// It talks to the running instance's unix socket instead of booting a whole
// `qs` process per call -- the same trick as DMS #3081:
//
//	npc call <target> <function> [args...]
//
// The return value goes to stdout (like `qs ipc call`), errors to stderr.
// Exit codes: 0 ok, 2 no target, 3 no function, 4 argument mismatch, 1 other.
// Falls back to exec'ing `qs` when no live socket answers.
//
// Wire format (qs src/io/ipccomm.cpp, src/ipc/ipccommand.hpp):
// request  = byte(3) + QString(target) + QString(function) + u32(argc) + QStrings
// response = byte(index) [+ byte(isVoid) + QString(result)]  (index 5 = completed)
// QString  = u32 BE byte-length + UTF-16BE units (0xFFFFFFFF = null)
//
// ponytail: assumes one live instance per target -- with N live instances
// exposing the same target the first match wins; pin with --socket/--pid/--id.
package main

import (
	"bytes"
	"encoding/binary"
	"flag"
	"fmt"
	"io"
	"net"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strconv"
	"syscall"
	"time"
	"unicode/utf16"
)

const (
	cmdCall         = 3
	respNotReady    = 1
	respNoTarget    = 2
	respNoFunc      = 3
	respArgMismatch = 4
	respCompleted   = 5
	maxStringLen    = 1 << 20
)

func runtimeDir() string {
	if d := os.Getenv("XDG_RUNTIME_DIR"); d != "" {
		return d
	}
	return "/run/user/" + strconv.Itoa(os.Getuid())
}

func writeQString(buf *bytes.Buffer, s string) error {
	units := utf16.Encode([]rune(s))
	if len(units)*2 > maxStringLen {
		return fmt.Errorf("string too large")
	}
	if err := binary.Write(buf, binary.BigEndian, uint32(len(units)*2)); err != nil {
		return err
	}
	for _, u := range units {
		if err := binary.Write(buf, binary.BigEndian, u); err != nil {
			return err
		}
	}
	return nil
}

func readQString(r io.Reader) (string, error) {
	var ln uint32
	if err := binary.Read(r, binary.BigEndian, &ln); err != nil {
		return "", err
	}
	if ln == ^uint32(0) {
		return "", nil
	}
	if ln > maxStringLen || ln%2 != 0 {
		return "", fmt.Errorf("bad QString length %d", ln)
	}
	units := make([]uint16, ln/2)
	for i := range units {
		if err := binary.Read(r, binary.BigEndian, &units[i]); err != nil {
			return "", err
		}
	}
	return string(utf16.Decode(units)), nil
}

// call performs one StringCall transaction. Transport failures return a
// non-nil error (caller tries the next socket); protocol outcomes return
// an exit code and message instead.
func call(sock, target, fn string, args []string, timeout time.Duration) (out string, code int, err error) {
	conn, err := net.DialTimeout("unix", sock, timeout)
	if err != nil {
		return "", 0, err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(timeout))

	var msg bytes.Buffer
	msg.WriteByte(cmdCall)
	if err := writeQString(&msg, target); err != nil {
		return "", 0, err
	}
	if err := writeQString(&msg, fn); err != nil {
		return "", 0, err
	}
	if err := binary.Write(&msg, binary.BigEndian, uint32(len(args))); err != nil {
		return "", 0, err
	}
	for _, a := range args {
		if err := writeQString(&msg, a); err != nil {
			return "", 0, err
		}
	}
	if _, err := conn.Write(msg.Bytes()); err != nil {
		return "", 0, err
	}

	var idx [1]byte
	if _, err := io.ReadFull(conn, idx[:]); err != nil {
		return "", 0, err
	}
	switch idx[0] {
	case respCompleted:
		var voidFlag [1]byte
		if _, err := io.ReadFull(conn, voidFlag[:]); err != nil {
			return "", 0, err
		}
		if voidFlag[0] != 0 {
			return "", 0, nil
		}
		out, err := readQString(conn)
		return out, 0, err
	case respNoTarget:
		return "Target not found: " + target, 2, nil
	case respNoFunc:
		return fmt.Sprintf("Function not found: %s %s", target, fn), 3, nil
	case respArgMismatch:
		return fmt.Sprintf("Argument mismatch calling %s %s", target, fn), 4, nil
	default:
		return "IPC not ready", 1, nil
	}
}

func candidates(sock, pid, instID string) []string {
	byID := filepath.Join(runtimeDir(), "quickshell", "by-id")
	if sock != "" {
		return []string{sock}
	}
	if pid != "" {
		return []string{filepath.Join(runtimeDir(), "quickshell", "by-pid", pid, "ipc.sock")}
	}
	entries, err := os.ReadDir(byID)
	if err != nil {
		return nil
	}
	if instID != "" {
		var matched []string
		for _, e := range entries {
			if !e.IsDir() {
				continue
			}
			if contains(e.Name(), instID) {
				matched = append(matched, e.Name())
			}
		}
		if len(matched) != 1 {
			fmt.Fprintf(os.Stderr, "ipc: id %q matches %d instances\n", instID, len(matched))
			os.Exit(1)
		}
		return []string{filepath.Join(byID, matched[0], "ipc.sock")}
	}
	type timed struct {
		path string
		mod  time.Time
	}
	var socks []timed
	for _, e := range entries {
		p := filepath.Join(byID, e.Name(), "ipc.sock")
		fi, err := os.Stat(p)
		if err != nil {
			continue
		}
		socks = append(socks, timed{p, fi.ModTime()})
	}
	sort.Slice(socks, func(i, j int) bool { return socks[i].mod.After(socks[j].mod) })
	out := make([]string, len(socks))
	for i := range socks {
		out[i] = socks[i].path
	}
	return out
}

func contains(s, sub string) bool {
	for i := 0; i+len(sub) <= len(s); i++ {
		if s[i:i+len(sub)] == sub {
			return true
		}
	}
	return false
}

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

	socks := candidates(*sock, *pid, *instID)
	answered := false
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			// ponytail: every socket refused -- usually a shell reload
			// swapping ipc.sock; rescan instead of failing the keybind.
			time.Sleep(200 * time.Millisecond)
			socks = candidates(*sock, *pid, *instID)
		}
		for _, s := range socks {
			out, code, err := call(s, target, fn, args, *timeout)
			if err != nil {
				continue // stale socket, try next
			}
			answered = true
			if code == respNoTarget && *sock == "" && *pid == "" && *instID == "" {
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
