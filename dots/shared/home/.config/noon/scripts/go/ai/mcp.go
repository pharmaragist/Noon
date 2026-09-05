// Command mcp exposes the Noon shell's NPC surface to agents as an MCP
// server over stdio. It is attached per-session by harness doNew, so only
// sidebar sessions get noon tools - global opencode is untouched.
//
// Tools are discovered, not hardcoded: at startup we parse
// `qs -p <root> ipc show` (targets + `function name(p: type, ...)` lines)
// and serve every NPC function as `target_name`. Calls exec
// `qs -p <root> ipc call <target> <fn> <args...>` positionally. A small
// curated fallback covers the case where discovery fails.
package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"path/filepath"
	"regexp"
	"strings"
	"time"

	"weather_service/qipc"
)

type param struct {
	name string
}

type tool struct {
	target string
	fn     string
	params []param
}

func (t tool) mcpName() string { return t.target + "_" + t.fn }

var fallback = []tool{
	{target: "global", fn: "toast", params: []param{{"info"}, {"state"}}},
	{target: "noon", fn: "translate", params: []param{{"query"}}},
	{target: "global", fn: "say", params: []param{{"text"}}},
}

func shellRoot() string {
	if d := os.Getenv("NOON_SHELL_ROOT"); d != "" {
		return d
	}
	if len(os.Args) == 0 {
		return ""
	}
	dir := os.Args[0]
	for i := 0; i < 4; i++ {
		dir = filepath.Dir(dir)
	}
	if st, err := os.Stat(dir + "/shell.qml"); err != nil || st.IsDir() {
		return ""
	}
	return dir
}

var rootDir = shellRoot()

// callNPC prefers the raw socket (no spawn) and re-resolves per attempt:
// reloads swap ipc.sock paths, so a cached socket goes stale.
func callNPC(target, fn string, args []string) (string, int, error) {
	var last error
	for attempt := 0; attempt < 3; attempt++ {
		if attempt > 0 {
			time.Sleep(200 * time.Millisecond)
		}
		sock := qipc.OwnSocket()
		if sock == "" {
			last = fmt.Errorf("no live socket")
			continue
		}
		out, code, err := qipc.Call(sock, target, fn, args, 15*time.Second)
		if err != nil {
			last = err
			continue
		}
		return out, code, nil
	}
	return "", 0, last
}

var (
	targetRe = regexp.MustCompile(`^target (\S+)\s*$`)
	fnRe     = regexp.MustCompile(`^\s*function (\w+)\(([^)]*)\)`)
)

func discover() []tool {
	if rootDir == "" {
		return fallback
	}
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	out, err := exec.CommandContext(ctx, "qs", "-p", rootDir, "ipc", "show").Output()
	if err != nil {
		return fallback
	}
	var tools []tool
	seen := map[string]bool{}
	target := ""
	for _, line := range strings.Split(string(out), "\n") {
		if m := targetRe.FindStringSubmatch(line); m != nil {
			target = m[1]
			continue
		}
		if target == "" {
			continue
		}
		if m := fnRe.FindStringSubmatch(line); m != nil {
			name := m[1]
			var params []param
			for _, p := range strings.Split(m[2], ",") {
				p = strings.TrimSpace(p)
				if p == "" {
					continue
				}
				if i := strings.Index(p, ":"); i >= 0 {
					p = strings.TrimSpace(p[:i])
				}
				if p != "" {
					params = append(params, param{p})
				}
			}
			key := target + "_" + name
			if !seen[key] {
				seen[key] = true
				tools = append(tools, tool{target, name, params})
			}
		}
	}
	if len(tools) == 0 {
		return fallback
	}
	return tools
}

var tools = discover()

type msg struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      json.RawMessage `json:"id,omitempty"`
	Method  string          `json:"method,omitempty"`
	Params  json.RawMessage `json:"params,omitempty"`
}

func reply(id json.RawMessage, result interface{}) {
	out, _ := json.Marshal(map[string]interface{}{"jsonrpc": "2.0", "id": json.RawMessage(id), "result": result})
	fmt.Println(string(out))
}

func replyErr(id json.RawMessage, code int, message string) {
	out, _ := json.Marshal(map[string]interface{}{"jsonrpc": "2.0", "id": json.RawMessage(id), "error": map[string]interface{}{"code": code, "message": message}})
	fmt.Println(string(out))
}

func main() {
	scanner := bufio.NewScanner(os.Stdin)
	scanner.Buffer(make([]byte, 1024*1024), 1024*1024)
	for scanner.Scan() {
		var m msg
		if err := json.Unmarshal(scanner.Bytes(), &m); err != nil {
			continue
		}
		switch m.Method {
		case "initialize":
			var p struct {
				ProtocolVersion string `json:"protocolVersion"`
			}
			json.Unmarshal(m.Params, &p)
			if p.ProtocolVersion == "" {
				p.ProtocolVersion = "2025-06-18"
			}
			reply(m.ID, map[string]interface{}{
				"protocolVersion": p.ProtocolVersion,
				"capabilities":    map[string]interface{}{"tools": map[string]interface{}{}},
				"serverInfo":      map[string]interface{}{"name": "noon", "version": "1"},
			})
		case "notifications/initialized", "notifications/cancelled":
		case "ping":
			reply(m.ID, map[string]interface{}{})
		case "tools/list":
			list := []map[string]interface{}{}
			for _, t := range tools {
				props := map[string]interface{}{}
				required := []string{}
				for _, p := range t.params {
					props[p.name] = map[string]interface{}{"type": "string"}
					required = append(required, p.name)
				}
				list = append(list, map[string]interface{}{
					"name":        t.mcpName(),
					"description": "Noon shell: " + t.target + " " + t.fn,
					"inputSchema": map[string]interface{}{"type": "object", "properties": props, "required": required},
				})
			}
			reply(m.ID, map[string]interface{}{"tools": list})
		case "tools/call":
			var p struct {
				Name      string                 `json:"name"`
				Arguments map[string]interface{} `json:"arguments"`
			}
			json.Unmarshal(m.Params, &p)
			handleCall(m.ID, p.Name, p.Arguments)
		default:
			if len(m.ID) > 0 {
				replyErr(m.ID, -32601, "method not found: "+m.Method)
			}
		}
	}
}

func handleCall(id json.RawMessage, name string, args map[string]interface{}) {
	if rootDir == "" {
		reply(id, map[string]interface{}{"content": []map[string]interface{}{{"type": "text", "text": "error: noon shell root unknown (NOON_SHELL_ROOT unset)"}}, "isError": true})
		return
	}
	for _, t := range tools {
		if t.mcpName() != name {
			continue
		}
		strs := make([]string, 0, len(t.params))
		for _, p := range t.params {
			v := ""
			if args != nil {
				v, _ = args[p.name].(string)
			}
			strs = append(strs, v)
		}
		if out, code, err := callNPC(t.target, t.fn, strs); err == nil {
			if code != 0 {
				reply(id, map[string]interface{}{"content": []map[string]interface{}{{"type": "text", "text": "error: " + out}}, "isError": true})
				return
			}
			reply(id, map[string]interface{}{"content": []map[string]interface{}{{"type": "text", "text": out}}})
			return
		}
		argv := []string{"-p", rootDir, "ipc", "call", t.target, t.fn}
		argv = append(argv, strs...)
		ctx, cancel := context.WithTimeout(context.Background(), 15*time.Second)
		defer cancel()
		out, err := exec.CommandContext(ctx, "qs", argv...).CombinedOutput()
		if err != nil {
			reply(id, map[string]interface{}{"content": []map[string]interface{}{{"type": "text", "text": "error: " + err.Error() + ": " + string(out)}}, "isError": true})
			return
		}
		reply(id, map[string]interface{}{"content": []map[string]interface{}{{"type": "text", "text": string(out)}}})
		return
	}
	replyErr(id, -32602, "unknown tool: "+name)
}
