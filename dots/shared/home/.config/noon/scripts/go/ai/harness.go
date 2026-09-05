package main

// harness bridges the Noon shell (QML) and opencode.
//
// One-shot commands (stdout = single JSON document, for Fetcher):
//   sessions            list sessions from the opencode sqlite db
//   chat <sessionId>    last 20 messages of a session from the sqlite db
//   skills              skill names from SKILL.md files on disk
//   models              model ids from `opencode models`
//
// Long-running bridge (stdin/stdout = newline-delimited JSON):
//   acp                 spawn `opencode acp`, translate between the shell's
//                       SSE-style event dialect and ACP JSON-RPC. QML writes
//                       {"cmd":...} lines, Go emits {"type":...} lines.

import (
	"bufio"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"path/filepath"
	"sort"
	"strings"
	"sync"
	"sync/atomic"
	"time"

	_ "github.com/mattn/go-sqlite3"
)

const dbPath = "$HOME/.local/share/opencode/opencode.db"

// Session matches the shape Harness.qml -> root.sessions consumes from refreshSessions.
type Session struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Created   int64  `json:"created"`
	Updated   int64  `json:"updated"`
	Directory string `json:"directory"`
	ProjectID string `json:"projectId"`
}

// ToolCall mirrors Harness.qml shapeMessage's tool entry.
type ToolCall struct {
	Tool   string          `json:"tool"`
	CallID string          `json:"callID"`
	Status string          `json:"status"`
	Input  json.RawMessage `json:"input"`
	Output string          `json:"output"`
}

// Message mirrors Harness.qml plainMessage().
type Message struct {
	Role              string        `json:"role"`
	Content           string        `json:"content"`
	RawContent        string        `json:"rawContent"`
	Model             string        `json:"model"`
	Thinking          bool          `json:"thinking"`
	Done              bool          `json:"done"`
	Queued            bool          `json:"queued"`
	Tools             []ToolCall    `json:"tools"`
	AnnotationSources []interface{} `json:"annotationSources"`
	VisibleToUser     bool          `json:"visibleToUser"`
	FunctionPending   bool          `json:"functionPending"`
	Agent             string        `json:"agent,omitempty"`
}

func open() (*sql.DB, error) {
	path := os.ExpandEnv(dbPath)
	return sql.Open("sqlite3", "file:"+path+"?mode=ro")
}

// truncateBlob mirrors Harness.qml trimBlob(x, 4000): truncate a string, or the
// .content field of an object, to max bytes (append Unicode ellipsis).
func truncateBlob(raw []byte, max int) string {
	if len(raw) == 0 {
		return ""
	}
	var obj map[string]interface{}
	if err := json.Unmarshal(raw, &obj); err == nil {
		if c, ok := obj["content"].(string); ok && len(c) > max {
			obj["content"] = c[:max] + "…"
		}
		out, _ := json.Marshal(obj)
		return string(out)
	}
	s := string(raw)
	if len(s) > max {
		return s[:max] + "…"
	}
	return s
}

func truncateString(s string, max int) string {
	if len(s) > max {
		return s[:max] + "\n\n…(truncated)"
	}
	return s
}

func cmdSessions() error {
	db, err := open()
	if err != nil {
		return err
	}
	defer db.Close()

	rows, err := db.Query(`SELECT id, title, time_created, time_updated, directory, project_id
		FROM session ORDER BY time_updated DESC`)
	if err != nil {
		return err
	}
	defer rows.Close()

	out := []Session{}
	for rows.Next() {
		var s Session
		if err := rows.Scan(&s.ID, &s.Title, &s.Created, &s.Updated, &s.Directory, &s.ProjectID); err != nil {
			return err
		}
		out = append(out, s)
	}
	return emit(out)
}



func cmdChat(sessionID string, limit, offset int) error {
	// Clamp, don't reset: QML's recallLimit is clamped 1..50 to match, and
	// hasMoreMessages compares out.length against the requested size — a
	// silent reset to 10 would end paging early.
	if limit < 1 {
		limit = 1
	}
	if limit > 50 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}
	db, err := open()
	if err != nil {
		return err
	}
	defer db.Close()

	query := `SELECT m.id, m.data, p.data
		FROM message m LEFT JOIN part p ON p.message_id = m.id
		WHERE m.session_id = ?
		  AND m.id IN (SELECT id FROM message WHERE session_id = ? ORDER BY rowid DESC LIMIT ? OFFSET ?)
		ORDER BY m.rowid ASC`
	rows, err := db.Query(query, sessionID, sessionID, limit, offset)
	if err != nil {
		return err
	}
	defer rows.Close()

	type msg struct {
		data json.RawMessage
		part []json.RawMessage
	}
	order := []string{}
	byID := map[string]*msg{}
	for rows.Next() {
		var mid string
		var mdata string
		var pdata sql.NullString
		if err := rows.Scan(&mid, &mdata, &pdata); err != nil {
			return err
		}
		if _, ok := byID[mid]; !ok {
			byID[mid] = &msg{data: json.RawMessage(mdata)}
			order = append(order, mid)
		}
		if pdata.Valid && len(pdata.String) > 0 {
			byID[mid].part = append(byID[mid].part, json.RawMessage(pdata.String))
		}
	}
	if err := rows.Err(); err != nil {
		return err
	}

	out := []Message{}
	for _, mid := range order {
		m := byID[mid]
		var meta struct {
			Role  string `json:"role"`
			Agent string `json:"agent"`
			Model *struct {
				ModelID string `json:"modelID"`
			} `json:"model"`
		}
		json.Unmarshal(m.data, &meta)

		var txt strings.Builder
		tools := []ToolCall{}
		for _, pd := range m.part {
			var p struct {
				Type   string          `json:"type"`
				Text   string          `json:"text"`
				Tool   string          `json:"tool"`
				CallID string          `json:"callID"`
				State  json.RawMessage `json:"state"`
			}
			if err := json.Unmarshal(pd, &p); err != nil {
				continue
			}
			switch p.Type {
			case "text":
				txt.WriteString(p.Text)
			case "tool":
				var st struct {
					Status string          `json:"status"`
					Input  json.RawMessage `json:"input"`
					Output string          `json:"output"`
				}
				json.Unmarshal(p.State, &st)
				tools = append(tools, ToolCall{
					Tool:   p.Tool,
					CallID: p.CallID,
					Status: st.Status,
					Input:  st.Input,
					Output: truncateString(st.Output, 4000),
				})
			}
		}

		content := truncateString(txt.String(), 30000)
		if content == "" && len(tools) == 0 {
			continue
		}
		var model string
		if meta.Model != nil {
			model = meta.Model.ModelID
		}
		out = append(out, Message{
			Role:              meta.Role,
			Content:           content,
			RawContent:        content,
			Model:             model,
			Thinking:          false,
			Done:              true,
			Tools:             tools,
			AnnotationSources: []interface{}{},
			VisibleToUser:     true,
			Agent:             meta.Agent,
		})
	}
	return emit(out)
}

func emit(v interface{}) error {
	enc := json.NewEncoder(os.Stdout)
	enc.SetEscapeHTML(false)
	return enc.Encode(v)
}

// cmdSkills mirrors the old QML skillsDiscovery shell-out: find every SKILL.md
// under the skills dir that has a '^name:\s*\S+' line, and emit the sorted
// unique basename of each containing directory.
func cmdSkills() error {
	dir, err := os.UserConfigDir()
	if err != nil {
		return err
	}
	root := dir + "/opencode/skills"
	set := map[string]bool{}
	err = filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
		if err != nil || info.IsDir() || info.Name() != "SKILL.md" {
			return nil
		}
		b, err := os.ReadFile(path)
		if err != nil {
			return nil
		}
		for _, line := range strings.Split(string(b), "\n") {
			if strings.HasPrefix(line, "name:") && len(strings.TrimSpace(line[len("name:"):])) > 0 {
				set[filepath.Base(filepath.Dir(path))] = true
				break
			}
		}
		return nil
	})
	if err != nil {
		return err
	}
	out := make([]string, 0, len(set))
	for name := range set {
		out = append(out, name)
	}
	sort.Strings(out)
	return emit(out)
}

// cmdModels mirrors the old QML getModels shell-out: run `opencode models` and
// emit the non-empty lines as a JSON array.
func cmdModels() error {
	cmd := exec.Command("opencode", "models")
	cmd.Stdin = nil
	out, err := cmd.Output()
	if err != nil {
		return err
	}
	models := []string{}
	for _, line := range strings.Split(strings.TrimSpace(string(out)), "\n") {
		if t := strings.TrimSpace(line); t != "" {
			models = append(models, t)
		}
	}
	return emit(models)
}

// ---------------------------------------------------------------------------
// ACP bridge ("acp" subcommand)
// ---------------------------------------------------------------------------

type acpRequest struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int64           `json:"id,omitempty"`
	Method  string          `json:"method"`
	Params  json.RawMessage `json:"params,omitempty"`
}

type acpResponse struct {
	JSONRPC string          `json:"jsonrpc"`
	ID      int64           `json:"id"`
	Result  json.RawMessage `json:"result,omitempty"`
	Error   *acpError       `json:"error,omitempty"`
}

type acpError struct {
	Code    int             `json:"code"`
	Message string          `json:"message"`
	Data    json.RawMessage `json:"data,omitempty"`
}

// bridge owns the `opencode acp` child and the QML-facing NDJSON streams.
type bridge struct {
	stdin   io.WriteCloser
	mu      sync.Mutex // guards stdin writes + pending map
	pending map[int64]chan *acpResponse
	nextID  int64 // via atomic
	outMu   sync.Mutex // guards stdout writes
	known   map[string]string
	lastMsg map[string]string
	permOpt map[int64][]permOption
}

type permOption struct {
	optionID string
	kind     string
}

var br = &bridge{
	pending: map[int64]chan *acpResponse{},
	known:   map[string]string{},
	lastMsg: map[string]string{},
	permOpt: map[int64][]permOption{},
}

// qemit writes one compact JSON line to stdout (the QML SplitParser stream).
func qemit(v interface{}) {
	b, err := json.Marshal(v)
	if err != nil {
		return
	}
	br.outMu.Lock()
	defer br.outMu.Unlock()
	os.Stdout.Write(append(b, '\n'))
}

func (b *bridge) next() int64 {
	return atomic.AddInt64(&b.nextID, 1)
}

func (b *bridge) sendRaw(req acpRequest) error {
	data, err := json.Marshal(req)
	if err != nil {
		return err
	}
	b.mu.Lock()
	defer b.mu.Unlock()
	_, err = b.stdin.Write(append(data, '\n'))
	return err
}

// call sends a JSON-RPC request and waits for the matching response.
func (b *bridge) call(method string, params interface{}) (json.RawMessage, error) {
	p, _ := json.Marshal(params)
	id := b.next()
	ch := make(chan *acpResponse, 1)
	b.mu.Lock()
	b.pending[id] = ch
	b.mu.Unlock()
	if err := b.sendRaw(acpRequest{JSONRPC: "2.0", ID: id, Method: method, Params: p}); err != nil {
		return nil, err
	}
	select {
	case resp := <-ch:
		if resp.Error != nil {
			return nil, fmt.Errorf("ACP %s: %s", method, resp.Error.Message)
		}
		return resp.Result, nil
	case <-time.After(600 * time.Second):
		b.mu.Lock()
		delete(b.pending, id)
		b.mu.Unlock()
		return nil, fmt.Errorf("ACP %s: timeout", method)
	}
}

// notify sends a JSON-RPC notification (no response expected).
func (b *bridge) notify(method string, params interface{}) error {
	p, _ := json.Marshal(params)
	return b.sendRaw(acpRequest{JSONRPC: "2.0", Method: method, Params: p})
}

func (b *bridge) reply(id int64, result interface{}) error {
	r, _ := json.Marshal(result)
	resp := map[string]interface{}{"jsonrpc": "2.0", "id": id, "result": json.RawMessage(r)}
	data, _ := json.Marshal(resp)
	b.mu.Lock()
	defer b.mu.Unlock()
	_, err := b.stdin.Write(append(data, '\n'))
	return err
}

func cwdOf(cmd map[string]interface{}) string {
	if c, ok := cmd["cwd"].(string); ok && c != "" {
		// Belt and braces: QML url strings ("file:///home/...") must
		// never reach the server — it joins them into unusable paths.
		return strings.TrimPrefix(c, "file://")
	}
	if wd, err := os.Getwd(); err == nil {
		return wd
	}
	return os.Getenv("HOME")
}

// doList handles {"cmd":"list"} via session/list (paginated).
func (b *bridge) doList(cmd map[string]interface{}) {
	type info struct {
		SessionID string `json:"sessionId"`
		Cwd       string `json:"cwd"`
		Title     string `json:"title"`
		UpdatedAt string `json:"updatedAt"`
	}
	all := []info{}
	cursor := ""
	for {
		params := map[string]interface{}{"cwd": cwdOf(cmd)}
		if cursor != "" {
			params["cursor"] = cursor
		}
		res, err := b.call("session/list", params)
		if err != nil {
			qemit(map[string]interface{}{"type": "error", "message": err.Error()})
			return
		}
		var page struct {
			Sessions   []info `json:"sessions"`
			NextCursor string  `json:"nextCursor"`
		}
		if err := json.Unmarshal(res, &page); err != nil {
			qemit(map[string]interface{}{"type": "error", "message": err.Error()})
			return
		}
		all = append(all, page.Sessions...)
		if page.NextCursor == "" {
			break
		}
		cursor = page.NextCursor
	}
	qemit(map[string]interface{}{"type": "sessions", "sessions": all})
}

type configOption struct {
	ID           string `json:"id"`
	CurrentValue string `json:"currentValue"`
	Options      []struct {
		Value string `json:"value"`
		Name  string `json:"name"`
	} `json:"options"`
}

func modelsFromOptions(opts []configOption) (models []string, current string) {
	for _, o := range opts {
		if o.ID == "model" {
			for _, m := range o.Options {
				models = append(models, m.Value)
			}
			current = o.CurrentValue
		}
	}
	return models, current
}

func effortsFromOptions(opts []configOption) (efforts []string, current string) {
	for _, o := range opts {
		if o.ID == "effort" {
			for _, m := range o.Options {
				efforts = append(efforts, m.Value)
			}
			current = o.CurrentValue
		}
	}
	return efforts, current
}

// parseEfforts extracts the effort option from a set_config_option response.
func parseEfforts(res json.RawMessage) ([]string, string) {
	var r struct {
		ConfigOptions []configOption `json:"configOptions"`
	}
	if err := json.Unmarshal(res, &r); err != nil {
		return nil, ""
	}
	return effortsFromOptions(r.ConfigOptions)
}

// doModel handles {"cmd":"model","sessionId","model"}: set immediately and
// report the model's effort options.
func (b *bridge) doModel(cmd map[string]interface{}) {
	sessionID, _ := cmd["sessionId"].(string)
	model, _ := cmd["model"].(string)
	if sessionID == "" || model == "" {
		return
	}
	if err := b.ensureKnown(sessionID, cwdOf(cmd)); err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	res, err := b.call("session/set_config_option", map[string]interface{}{
		"sessionId": sessionID, "configId": "model", "value": model,
	})
	if err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	if efforts, current := parseEfforts(res); efforts != nil {
		qemit(map[string]interface{}{
			"type": "efforts", "sessionId": sessionID,
			"efforts": efforts, "effort": current,
		})
	} else {
		qemit(map[string]interface{}{
			"type": "efforts", "sessionId": sessionID,
			"efforts": []string{}, "effort": "",
		})
	}
}

// doNew handles {"cmd":"new"} via session/new.
func (b *bridge) doNew(cmd map[string]interface{}) {
	cwd := cwdOf(cmd)
	res, err := b.call("session/new", map[string]interface{}{"cwd": cwd, "mcpServers": []interface{}{}})
	if err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	var r struct {
		SessionID     string         `json:"sessionId"`
		ConfigOptions []configOption `json:"configOptions"`
		Modes         *struct {
			CurrentModeID  string `json:"currentModeId"`
			AvailableModes []struct {
				ID   string `json:"id"`
				Name string `json:"name"`
			} `json:"availableModes"`
		} `json:"modes"`
	}
	if err := json.Unmarshal(res, &r); err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	models, current := modelsFromOptions(r.ConfigOptions)
	efforts, effort := effortsFromOptions(r.ConfigOptions)
	b.mu.Lock()
	b.known[r.SessionID] = cwd
	b.mu.Unlock()
	modes := []string{}
	mode := ""
	if r.Modes != nil {
		mode = r.Modes.CurrentModeID
		for _, m := range r.Modes.AvailableModes {
			modes = append(modes, m.ID)
		}
	}
	qemit(map[string]interface{}{
		"type": "session", "sessionId": r.SessionID,
		"models": models, "model": current, "modes": modes, "mode": mode,
		"efforts": efforts, "effort": effort,
	})
}

// ensureKnown resumes server-side sessions this bridge hasn't seen (e.g.
// created by an older shell run) so session/prompt works on them.
func (b *bridge) ensureKnown(sessionID, cwd string) error {
	b.mu.Lock()
	_, ok := b.known[sessionID]
	b.mu.Unlock()
	if ok {
		return nil
	}
	_, err := b.call("session/resume", map[string]interface{}{
		"sessionId": sessionID, "cwd": cwd, "mcpServers": []interface{}{},
	})
	if err != nil {
		return err
	}
	b.mu.Lock()
	b.known[sessionID] = cwd
	b.mu.Unlock()
	return nil
}

// doSend handles {"cmd":"send","sessionId","text"[,"model"]}.
func (b *bridge) doSend(cmd map[string]interface{}) {
	sessionID, _ := cmd["sessionId"].(string)
	text, _ := cmd["text"].(string)
	if sessionID == "" || text == "" {
		qemit(map[string]interface{}{"type": "error", "message": "send needs sessionId and text"})
		return
	}
	cwd := cwdOf(cmd)
	if err := b.ensureKnown(sessionID, cwd); err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	if model, _ := cmd["model"].(string); model != "" {
		// Model is a session config option in ACP; idempotent set.
		// The response carries the full option set, including per-model effort.
		if res, err := b.call("session/set_config_option", map[string]interface{}{
			"sessionId": sessionID, "configId": "model", "value": model,
		}); err == nil {
			if efforts, current := parseEfforts(res); efforts != nil {
				qemit(map[string]interface{}{
					"type": "efforts", "sessionId": sessionID,
					"efforts": efforts, "effort": current,
				})
			}
		}
	}
	if effort, _ := cmd["effort"].(string); effort != "" {
		// Same for effort (thought level); ignored by models without variants.
		b.call("session/set_config_option", map[string]interface{}{
			"sessionId": sessionID, "configId": "effort", "value": effort,
		})
	}
	qemit(map[string]interface{}{
		"type": "session.status", "properties": map[string]interface{}{
			"status": map[string]interface{}{"type": "busy"},
		},
	})
	res, err := b.call("session/prompt", map[string]interface{}{
		"sessionId": sessionID,
		"prompt":    []interface{}{map[string]interface{}{"type": "text", "text": text}},
	})
	qemit(map[string]interface{}{
		"type": "session.status", "properties": map[string]interface{}{
			"status": map[string]interface{}{"type": "idle"},
		},
	})
	if err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	var r struct {
		StopReason string `json:"stopReason"`
	}
	json.Unmarshal(res, &r)
	qemit(map[string]interface{}{"type": "prompt-done", "stopReason": r.StopReason})
}

// doReply handles {"cmd":"reply","reqId","approved"} for permission requests.
func (b *bridge) doReply(cmd map[string]interface{}) {
	var reqID int64
	switch v := cmd["reqId"].(type) {
	case float64:
		reqID = int64(v)
	case string:
		fmt.Sscan(v, &reqID)
	default:
		return
	}
	if reqID == 0 {
		return
	}
	approved, _ := cmd["approved"].(bool)
	optionID, _ := cmd["optionId"].(string)
	b.mu.Lock()
	stored := b.permOpt[reqID]
	delete(b.permOpt, reqID)
	b.mu.Unlock()
	var outcome interface{}
	if !approved {
		outcome = map[string]interface{}{"outcome": "cancelled"}
	} else {
		if optionID == "" {
			optionID = pickAllowOption(stored)
		}
		if optionID == "" {
			outcome = map[string]interface{}{"outcome": "cancelled"}
		} else {
			outcome = map[string]interface{}{"outcome": map[string]interface{}{"outcome": "selected", "optionId": optionID}}
		}
	}
	b.reply(reqID, map[string]interface{}{"outcome": outcome})
}

// pickAllowOption prefers allow-once, then allow-always, then any
// non-reject option, else "".
func pickAllowOption(opts []permOption) string {
	for _, o := range opts {
		if o.kind == "allow_once" {
			return o.optionID
		}
	}
	for _, o := range opts {
		if o.kind == "allow_always" {
			return o.optionID
		}
	}
	for _, o := range opts {
		if !strings.HasPrefix(o.kind, "reject") {
			return o.optionID
		}
	}
	return ""
}

// doCancel handles {"cmd":"cancel","sessionId"}.
func (b *bridge) doCancel(cmd map[string]interface{}) {
	sessionID, _ := cmd["sessionId"].(string)
	if sessionID == "" {
		return
	}
	b.notify("session/cancel", map[string]interface{}{"sessionId": sessionID})
}

// toolText flattens ACP tool content blocks to plain text.
func toolText(content json.RawMessage) string {
	var blocks []struct {
		Type    string `json:"type"`
		Content *struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
		Text string `json:"text"`
	}
	if err := json.Unmarshal(content, &blocks); err != nil {
		return truncateBlob(content, 4000)
	}
	var sb strings.Builder
	for _, bl := range blocks {
		if bl.Content != nil && bl.Content.Text != "" {
			sb.WriteString(bl.Content.Text)
		} else if bl.Text != "" {
			sb.WriteString(bl.Text)
		}
	}
	return truncateString(sb.String(), 4000)
}

// sessionUpdate is one ACP session/update payload.
type sessionUpdate struct {
	SessionUpdate     string          `json:"sessionUpdate"`
	MessageID         string          `json:"messageId"`
	Content           json.RawMessage `json:"content"`
	ToolCallID        string          `json:"toolCallId"`
	Title             string          `json:"title"`
	Kind              string          `json:"kind"`
	Status            string          `json:"status"`
	RawInput          json.RawMessage `json:"rawInput"`
	AvailableCommands []struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	} `json:"availableCommands"`
}

// onUpdate translates agent session/update notifications to the shell's
// SSE-style event dialect (see Harness.qml handleSSE).
func (b *bridge) onUpdate(sessionID string, u sessionUpdate) {
	b.mu.Lock()
	if u.MessageID != "" {
		b.lastMsg[sessionID] = u.MessageID
	}
	msgID := b.lastMsg[sessionID]
	b.mu.Unlock()
	switch u.SessionUpdate {
	case "agent_thought_chunk":
		var c struct {
			Type string `json:"type"`
			Text string `json:"text"`
		}
		if json.Unmarshal(u.Content, &c) == nil && c.Text != "" {
			qemit(map[string]interface{}{
				"type": "message.part.updated", "properties": map[string]interface{}{
					"part": map[string]interface{}{"type": "reasoning", "messageID": u.MessageID, "text": c.Text},
				},
			})
		}
	case "agent_message_chunk":
		var c struct {
			Type string `json:"type"`
			Text string `json:"text"`
		}
		if json.Unmarshal(u.Content, &c) == nil && c.Text != "" {
			qemit(map[string]interface{}{
				"type": "message.part.updated", "properties": map[string]interface{}{
					"part": map[string]interface{}{"type": "text", "messageID": u.MessageID, "text": c.Text},
				},
			})
		}
	case "tool_call":
		input := ""
		if len(u.RawInput) > 0 {
			input = truncateBlob(u.RawInput, 4000)
		}
		qemit(map[string]interface{}{
			"type": "message.part.updated", "properties": map[string]interface{}{
				"part": map[string]interface{}{
					"type": "tool", "tool": u.Title, "callID": u.ToolCallID, "messageID": msgID,
					"state": map[string]interface{}{"status": "pending", "input": json.RawMessage(input)},
				},
			},
		})
	case "tool_call_update":
		qemit(map[string]interface{}{
			"type": "message.part.updated", "properties": map[string]interface{}{
				"part": map[string]interface{}{
					"type": "tool", "tool": u.Title, "callID": u.ToolCallID, "messageID": msgID,
					"state": map[string]interface{}{"status": u.Status, "output": toolText(u.Content)},
				},
			},
		})
	case "available_commands_update":
		names := []string{}
		for _, c := range u.AvailableCommands {
			names = append(names, c.Name)
		}
		qemit(map[string]interface{}{"type": "commands", "sessionId": sessionID, "commands": names})
	}
}

// onAgentRequest forwards agent->client requests (permissions, fs, terminal)
// to QML; QML answers with {"cmd":"reply","reqId","approved"}.
func (b *bridge) onAgentRequest(id int64, method string, params json.RawMessage) {
	if method == "session/request_permission" {
		var p struct {
			SessionID string `json:"sessionId"`
			ToolCall  struct {
				ToolCallID string `json:"toolCallId"`
				Title      string `json:"title"`
			} `json:"toolCall"`
			Options []struct {
				OptionID string `json:"optionId"`
				Name     string `json:"name"`
				Kind     string `json:"kind"`
			} `json:"options"`
		}
		json.Unmarshal(params, &p)
		opts := []interface{}{}
		stored := []permOption{}
		for _, o := range p.Options {
			opts = append(opts, map[string]interface{}{
				"optionId": o.OptionID, "name": o.Name, "kind": o.Kind,
			})
			stored = append(stored, permOption{optionID: o.OptionID, kind: o.Kind})
		}
		b.mu.Lock()
		msgID := b.lastMsg[p.SessionID]
		b.permOpt[id] = stored
		b.mu.Unlock()
		qemit(map[string]interface{}{
			"type": "permission.asked", "properties": map[string]interface{}{
				"id": fmt.Sprint(id), "sessionID": p.SessionID,
				"tool": map[string]interface{}{"messageID": msgID, "callID": p.ToolCall.ToolCallID, "title": p.ToolCall.Title},
				"options": opts,
			},
		})
		return
	}
	qemit(map[string]interface{}{
		"type": "agent-request", "reqId": id, "method": method, "params": string(params),
	})
}

// readLoop demuxes ACP stdout: responses by id, updates, agent requests.
func (b *bridge) readLoop(r *bufio.Reader) {
	for {
		line, err := r.ReadString('\n')
		if line != "" {
			b.handleLine(strings.TrimSpace(line))
		}
		if err != nil {
			return
		}
	}
}

func (b *bridge) handleLine(line string) {
	if line == "" {
		return
	}
	// Response to our request? (has id, no method key)
	var probe map[string]json.RawMessage
	if err := json.Unmarshal([]byte(line), &probe); err != nil {
		return
	}
	_, hasID := probe["id"]
	_, hasMethod := probe["method"]
	if hasID && !hasMethod {
		var resp acpResponse
		if err := json.Unmarshal([]byte(line), &resp); err != nil {
			return
		}
		b.mu.Lock()
		ch, ok := b.pending[resp.ID]
		if ok {
			delete(b.pending, resp.ID)
		}
		b.mu.Unlock()
		if ok {
			ch <- &resp
		}
		return
	}
	// Agent->client request (has id + method)?
	if hasID && hasMethod {
		var req acpRequest
		if err := json.Unmarshal([]byte(line), &req); err == nil {
			b.onAgentRequest(req.ID, req.Method, req.Params)
		}
		return
	}
	// Notification? Single parse: method + session update.
	var msg struct {
		Method string `json:"method"`
		Params *struct {
			SessionID string         `json:"sessionId"`
			Update    sessionUpdate  `json:"update"`
		} `json:"params"`
	}
	if err := json.Unmarshal([]byte(line), &msg); err != nil || msg.Method == "" {
		return
	}
	if msg.Method != "session/update" || msg.Params == nil {
		return
	}
	b.onUpdate(msg.Params.SessionID, msg.Params.Update)
}

// cmdAcp runs the long-lived QML<->ACP bridge.
func cmdAcp() error {
	cmd := exec.Command("opencode", "acp")
	acpIn, err := cmd.StdinPipe()
	if err != nil {
		return err
	}
	acpOut, err := cmd.StdoutPipe()
	if err != nil {
		return err
	}
	cmd.Stderr = os.Stderr
	if err := cmd.Start(); err != nil {
		return err
	}
	br.stdin = acpIn
	go br.readLoop(bufio.NewReaderSize(acpOut, 64*1024))

	if _, err := br.call("initialize", map[string]interface{}{
		"protocolVersion":    1,
		"clientCapabilities": map[string]interface{}{},
	}); err != nil {
		return err
	}
	qemit(map[string]interface{}{"type": "ready"})

	in := bufio.NewReader(os.Stdin)
	for {
		line, err := in.ReadString('\n')
		if line != "" {
			var c map[string]interface{}
			if jerr := json.Unmarshal([]byte(strings.TrimSpace(line)), &c); jerr == nil {
				switch c["cmd"] {
				case "list":
					go br.doList(c)
				case "new":
					go br.doNew(c)
				case "send":
					go br.doSend(c)
				case "model":
					go br.doModel(c)
				case "reply":
					go br.doReply(c)
				case "cancel":
					go br.doCancel(c)
				}
			}
		}
		if err != nil {
			break
		}
	}
	return nil
}

func usage() {
	fmt.Fprintln(os.Stderr, "usage: harness <sessions|chat <sessionId>|skills|models|acp>")
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
	case "models":
		err = cmdModels()
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
