// Package qipc speaks the quickshell IPC socket protocol directly:
// QDataStream framing (u8 command + big-endian u32 length + UTF-16BE
// QStrings), unix sockets under the quickshell runtime dir. Single source
// of truth for the wire format (qs src/io/ipccomm.cpp, src/ipc/ipccommand.hpp):
//
//	request  = byte(3) + QString(target) + QString(function) + u32(argc) + QStrings
//	response = byte(index) [+ byte(isVoid) + QString(result)]  (index 5 = completed)
//	QString  = u32 BE byte-length + UTF-16BE units (0xFFFFFFFF = null)
package qipc

import (
	"bufio"
	"bytes"
	"encoding/binary"
	"fmt"
	"io"
	"net"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"time"
	"unicode/utf16"
)

// Response codes and limits match scripts/npc.go behavior.
const (
	CmdCall      = 3
	RespNotReady = 1
	RespNoTarget = 2
	RespNoFunc   = 3
	RespMismatch = 4
	RespDone     = 5

	MaxStringLen = 1 << 20
	readBufSize  = 4096
)

func WriteQString(buf *bytes.Buffer, s string) error {
	units := utf16.Encode([]rune(s))
	if len(units)*2 > MaxStringLen {
		return fmt.Errorf("string too large")
	}
	if err := binary.Write(buf, binary.BigEndian, uint32(len(units)*2)); err != nil {
		return err
	}
	return binary.Write(buf, binary.BigEndian, units)
}

func ReadQString(r io.Reader) (string, error) {
	var ln uint32
	if err := binary.Read(r, binary.BigEndian, &ln); err != nil {
		return "", err
	}
	if ln == ^uint32(0) {
		return "", nil
	}
	if ln > MaxStringLen || ln%2 != 0 {
		return "", fmt.Errorf("bad QString length %d", ln)
	}
	units := make([]uint16, ln/2)
	if err := binary.Read(r, binary.BigEndian, units); err != nil {
		return "", err
	}
	return string(utf16.Decode(units)), nil
}

func BuildRequest(target, fn string, args []string) ([]byte, error) {
	buf := bytes.NewBuffer(nil)
	buf.WriteByte(CmdCall)
	if err := WriteQString(buf, target); err != nil {
		return nil, err
	}
	if err := WriteQString(buf, fn); err != nil {
		return nil, err
	}
	if err := binary.Write(buf, binary.BigEndian, uint32(len(args))); err != nil {
		return nil, err
	}
	for _, a := range args {
		if err := WriteQString(buf, a); err != nil {
			return nil, err
		}
	}
	return buf.Bytes(), nil
}

// Call performs one request on a fresh connection: the server disposes it
// after each command, so there is no persistent session to keep. Transport
// failures return err (try the next socket); protocol outcomes return code.
func Call(sock, target, fn string, args []string, timeout time.Duration) (out string, code int, err error) {
	req, err := BuildRequest(target, fn, args)
	if err != nil {
		return "", 0, err
	}
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
	case RespDone:
		var voidFlag [1]byte
		if _, err := io.ReadFull(r, voidFlag[:]); err != nil {
			return "", 0, err
		}
		if voidFlag[0] != 0 {
			return "", 0, nil
		}
		out, err := ReadQString(r)
		return out, 0, err
	case RespNotReady:
		return "IPC not ready", 1, nil
	case RespNoTarget:
		return "Target not found: " + target, 2, nil
	case RespNoFunc:
		return fmt.Sprintf("Function not found: %s %s", target, fn), 3, nil
	case RespMismatch:
		return fmt.Sprintf("Argument mismatch calling %s %s", target, fn), 4, nil
	default:
		return fmt.Sprintf("unexpected response index %d", idx[0]), 1, nil
	}
}

func RuntimeDir() string {
	if d := os.Getenv("XDG_RUNTIME_DIR"); d != "" {
		return d
	}
	return "/run/user/" + strconv.Itoa(os.Getuid())
}

// Candidates resolves ipc.sock paths: exact socket, pid, id substring, or
// all instances newest-first.
func Candidates(sock, pid, instID string) []string {
	byID := filepath.Join(RuntimeDir(), "quickshell", "by-id")
	if sock != "" {
		return []string{sock}
	}
	if pid != "" {
		return []string{filepath.Join(RuntimeDir(), "quickshell", "by-pid", pid, "ipc.sock")}
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
			return nil
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

// OwnSocket finds the ipc.sock of the qs instance that (transitively)
// spawned us: ppid-walk to the qs ancestor, then intersect its held socket
// inodes with /proc/net/unix entries under the quickshell runtime dir.
// Symlink-proof (inodes, never config paths).
func OwnSocket() string {
	if s := os.Getenv("NOON_IPC_SOCK"); s != "" {
		return s
	}
	qsPid := 0
	pid := os.Getpid()
	for i := 0; i < 16 && pid > 1; i++ {
		ppid, comm := procParent(pid)
		if ppid <= 1 {
			break
		}
		if comm == "qs" || comm == "quickshell" {
			qsPid = ppid
			break
		}
		pid = ppid
	}
	if qsPid == 0 {
		return ""
	}
	held := map[string]bool{}
	for _, fd := range fdSockets(qsPid) {
		held[fd] = true
	}
	if len(held) == 0 {
		return ""
	}
	data, err := os.ReadFile("/proc/net/unix")
	if err != nil {
		return ""
	}
	want := filepath.Join(RuntimeDir(), "quickshell")
	for _, line := range strings.Split(string(data), "\n") {
		f := strings.Fields(line)
		if len(f) < 8 {
			continue
		}
		ino, path := f[6], f[7]
		if !held["socket:["+ino+"]"] {
			continue
		}
		if strings.HasPrefix(path, want) && strings.HasSuffix(path, "ipc.sock") {
			return path
		}
	}
	return ""
}

func procParent(pid int) (int, string) {
	data, err := os.ReadFile(fmt.Sprintf("/proc/%d/stat", pid))
	if err != nil {
		return 0, ""
	}
	s := string(data)
	end := strings.LastIndex(s, ")")
	if end < 0 {
		return 0, ""
	}
	rest := strings.Fields(s[end+1:])
	if len(rest) < 2 {
		return 0, ""
	}
	ppid, _ := strconv.Atoi(rest[1])
	comm := strings.Trim(s[strings.Index(s, "(")+1:end], "")
	return ppid, comm
}

func fdSockets(pid int) []string {
	entries, err := os.ReadDir(fmt.Sprintf("/proc/%d/fd", pid))
	if err != nil {
		return nil
	}
	var out []string
	for _, e := range entries {
		target, err := os.Readlink(fmt.Sprintf("/proc/%d/fd/%s", pid, e.Name()))
		if err != nil {
			continue
		}
		if strings.HasPrefix(target, "socket:[") {
			out = append(out, target)
		}
	}
	return out
}
