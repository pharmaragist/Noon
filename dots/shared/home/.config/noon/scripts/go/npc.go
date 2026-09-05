package main

import (
	"bufio"
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
	"strings"
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
	readBufSize     = 4096
)

func runtimeDir() string {
	if d := os.Getenv("XDG_RUNTIME_DIR"); d != "" {
		return d
	}
	return "/run/user/" + strconv.Itoa(os.Getuid())
}

func writeQString(buf *bytes.Buffer, s string) error {
	units := utf16.Encode([]rune(s))
	byteLen := len(units) * 2
	if byteLen > maxStringLen {
		return fmt.Errorf("string too large")
	}
	if err := binary.Write(buf, binary.BigEndian, uint32(byteLen)); err != nil {
		return err
	}
	return binary.Write(buf, binary.BigEndian, units)
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
	if err := binary.Read(r, binary.BigEndian, units); err != nil {
		return "", err
	}
	return string(utf16.Decode(units)), nil
}

func buildRequest(target, fn string, args []string) ([]byte, error) {
	size := 1 + 4 + len(target)*2 + 4 + len(fn)*2 + 4
	for _, a := range args {
		size += 4 + len(a)*2
	}
	buf := bytes.NewBuffer(make([]byte, 0, size))
	buf.WriteByte(cmdCall)
	if err := writeQString(buf, target); err != nil {
		return nil, err
	}
	if err := writeQString(buf, fn); err != nil {
		return nil, err
	}
	if err := binary.Write(buf, binary.BigEndian, uint32(len(args))); err != nil {
		return nil, err
	}
	for _, a := range args {
		if err := writeQString(buf, a); err != nil {
			return nil, err
		}
	}
	return buf.Bytes(), nil
}

func call(sock, target, fn string, req []byte, timeout time.Duration) (out string, code int, err error) {
	conn, err := net.DialTimeout("unix", sock, timeout)
	if err != nil {
		return "", 0, err
	}
	defer conn.Close()
	_ = conn.SetDeadline(time.Now().Add(timeout))

	if _, err := conn.Write(req); err != nil {
		return "", 0, err
	}

	r := bufio.NewReaderSize(conn, readBufSize)
	var idx [1]byte
	if _, err := io.ReadFull(r, idx[:]); err != nil {
		return "", 0, err
	}
	switch idx[0] {
	case respCompleted:
		var voidFlag [1]byte
		if _, err := io.ReadFull(r, voidFlag[:]); err != nil {
			return "", 0, err
		}
		if voidFlag[0] != 0 {
			return "", 0, nil
		}
		out, err := readQString(r)
		return out, 0, err
	case respNotReady:
		return "IPC not ready", 1, nil
	case respNoTarget:
		return "Target not found: " + target, 2, nil
	case respNoFunc:
		return fmt.Sprintf("Function not found: %s %s", target, fn), 3, nil
	case respArgMismatch:
		return fmt.Sprintf("Argument mismatch calling %s %s", target, fn), 4, nil
	default:
		return fmt.Sprintf("unexpected response index %d", idx[0]), 1, nil
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
			if e.IsDir() && strings.Contains(e.Name(), instID) {
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
	socks := make([]timed, 0, len(entries))
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

func main() {
	sock := flag.String("socket", "", "exact ipc.sock path")
	pid := flag.String("pid", "", "instance pid (qs --pid equivalent)")
	instID := flag.String("id", "", "instance id substring (qs --id equivalent)")
	conf := flag.String("config", "", "forwarded to qs on fallback")
	confShort := flag.String("c", "", "shorthand for --config (forwarded to qs on fallback)")
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

	req, err := buildRequest(target, fn, args)
	if err != nil {
		fmt.Fprintln(os.Stderr, "ipc: "+err.Error())
		os.Exit(1)
	}

	socks := candidates(*sock, *pid, *instID)
	answered := false
	for _, s := range socks {
		out, code, err := call(s, target, fn, req, *timeout)
		if err != nil {
			continue
		}
		answered = true
		if code == respNoTarget && *sock == "" && *pid == "" && *instID == "" {
			continue
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
	if answered {
		fmt.Fprintf(os.Stderr, "ipc: target not found: %s\n", target)
		os.Exit(2)
	}

	qs, err := exec.LookPath("qs")
	if err != nil {
		fmt.Fprintln(os.Stderr, "ipc: no running instance and qs not found")
		os.Exit(1)
	}
	qsArgs := []string{"qs"}
	if *conf != "" {
		qsArgs = append(qsArgs, "-c", *conf)
	} else if *confShort != "" {
		qsArgs = append(qsArgs, "-c", *confShort)
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
