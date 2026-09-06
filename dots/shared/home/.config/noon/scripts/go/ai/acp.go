package main

import (
	"bufio"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"os/exec"
	"strings"
	"sync"
	"sync/atomic"
	"time"
)

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

type bridge struct {
	stdin   io.WriteCloser
	mu      sync.Mutex // guards stdin writes + pending map
	pending map[int64]chan *acpResponse
	nextID  int64 // via atomic
	outMu   sync.Mutex // guards stdout writes
	known   map[string]string
	lastMsg map[string]string
	permOpt map[int64][]permOption
	sessMu  sync.Mutex
	sessLck map[string]*sync.Mutex
}

func (b *bridge) sessionLock(id string) *sync.Mutex {
	b.sessMu.Lock()
	defer b.sessMu.Unlock()
	if b.sessLck == nil {
		b.sessLck = map[string]*sync.Mutex{}
	}
	l, ok := b.sessLck[id]
	if !ok {
		l = &sync.Mutex{}
		b.sessLck[id] = l
	}
	return l
}

type permOption struct {
	optionID  string
	kind      string
	sessionID string
}

var br = &bridge{
	pending: map[int64]chan *acpResponse{},
	known:   map[string]string{},
	lastMsg: map[string]string{},
	permOpt: map[int64][]permOption{},
}

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

func (b *bridge) call(method string, params interface{}) (json.RawMessage, error) {
	return b.callTimeout(method, params, 60*time.Second)
}

func (b *bridge) callTimeout(method string, params interface{}, timeout time.Duration) (json.RawMessage, error) {
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
	case <-time.After(timeout):
		b.mu.Lock()
		delete(b.pending, id)
		b.mu.Unlock()
		return nil, fmt.Errorf("ACP %s: timeout", method)
	}
}

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

func (b *bridge) replyError(id int64, code int, message string) error {
	resp := map[string]interface{}{
		"jsonrpc": "2.0", "id": id,
		"error": map[string]interface{}{"code": code, "message": message},
	}
	data, _ := json.Marshal(resp)
	b.mu.Lock()
	defer b.mu.Unlock()
	_, err := b.stdin.Write(append(data, '\n'))
	return err
}

func cwdOf(cmd map[string]interface{}) string {
	if c, ok := cmd["cwd"].(string); ok && c != "" {
		// Never let QML url strings ("file:///...") reach the server.
		return strings.TrimPrefix(c, "file://")
	}
	if wd, err := os.Getwd(); err == nil {
		return wd
	}
	return os.Getenv("HOME")
}

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

// Tolerates opencode's {currentValue,options[]} and spec's {currentValueId,values[]}.
type configOption struct {
	ID             string `json:"id"`
	CurrentValue   string `json:"currentValue"`
	CurrentValueID string `json:"currentValueId"`
	Options        []struct {
		Value   string `json:"value"`
		ValueID string `json:"valueId"`
		Name    string `json:"name"`
		Label   string `json:"label"`
	} `json:"options"`
	Values []struct {
		Value   string `json:"value"`
		ValueID string `json:"valueId"`
		Name    string `json:"name"`
		Label   string `json:"label"`
	} `json:"values"`
}

func configValues(opts []configOption, id string) (values []string, current string) {
	for _, o := range opts {
		if o.ID == id {
			list := o.Options
			if len(list) == 0 {
				list = o.Values
			}
			for _, m := range list {
				if m.Value != "" {
					values = append(values, m.Value)
				} else if m.ValueID != "" {
					values = append(values, m.ValueID)
				}
			}
			current = o.CurrentValue
			if current == "" {
				current = o.CurrentValueID
			}
		}
	}
	return values, current
}

func modelsFromOptions(opts []configOption) (models []string, current string) {
	return configValues(opts, "model")
}

func effortsFromOptions(opts []configOption) (efforts []string, current string) {
	return configValues(opts, "effort")
}

func modesFromOptions(opts []configOption) (modes []string, current string) {
	return configValues(opts, "mode")
}

func parseConfig(res json.RawMessage, id string) ([]string, string) {
	var r struct {
		ConfigOptions []configOption `json:"configOptions"`
	}
	if err := json.Unmarshal(res, &r); err != nil {
		return nil, ""
	}
	return configValues(r.ConfigOptions, id)
}

func parseEfforts(res json.RawMessage) ([]string, string) {
	efforts, current := parseConfig(res, "effort")
	return efforts, current
}

func (b *bridge) doSync(cmd map[string]interface{}) {
	if sessionID := cmdStr(cmd, "sessionId"); sessionID != "" {
		if err := b.ensureKnown(sessionID, cwdOf(cmd)); err != nil {
			qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		}
	}
}

type sessionModes struct {
	CurrentModeID  string `json:"currentModeId"`
	AvailableModes []struct {
		ID   string `json:"id"`
		Name string `json:"name"`
	} `json:"availableModes"`
}

func modeIDs(m *sessionModes) []string {
	if m == nil {
		return nil
	}
	out := []string{}
	for _, a := range m.AvailableModes {
		out = append(out, a.ID)
	}
	return out
}

// emitSessionState reports one session's full config surface. Shared by
// resume/sync so every path tells QML the same truth in the same shape.
func (b *bridge) emitSessionState(sessionID string, opts []configOption, fallback *sessionModes) {
	if models, _ := configValues(opts, "model"); len(models) > 0 {
		qemit(map[string]interface{}{"type": "models", "sessionId": sessionID, "models": models})
	}
	if _, current := configValues(opts, "model"); current != "" {
		qemit(map[string]interface{}{"type": "model", "sessionId": sessionID, "model": current})
	}
	if efforts, current := configValues(opts, "effort"); efforts != nil {
		qemit(map[string]interface{}{"type": "efforts", "sessionId": sessionID, "efforts": efforts, "effort": current})
	}
	if list, mode := configValues(opts, "mode"); len(list) > 0 || mode != "" {
		qemit(map[string]interface{}{"type": "mode", "sessionId": sessionID, "mode": mode, "modes": list})
	} else if fallback != nil {
		qemit(map[string]interface{}{"type": "mode", "sessionId": sessionID, "mode": fallback.CurrentModeID, "modes": modeIDs(fallback)})
	}
}

// cmdStr reads an optional string field from a QML command object.
func cmdStr(cmd map[string]interface{}, key string) string {
	s, _ := cmd[key].(string)
	return s
}

// applyConfig sets one session config option, surfaces failures, and
// returns the raw response plus the server-confirmed value.
func (b *bridge) applyConfig(sessionID, id, value string) (json.RawMessage, string) {
	res, err := b.call("session/set_config_option", map[string]interface{}{
		"sessionId": sessionID, "configId": id, "value": value,
	})
	if err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return nil, ""
	}
	_, confirmed := parseConfig(res, id)
	return res, confirmed
}

// setConfigQuiet is applyConfig without state events (doNew folds the
// confirmed values into its session event instead).
func (b *bridge) setConfigQuiet(sessionID, id, value string) string {
	_, confirmed := b.applyConfig(sessionID, id, value)
	return confirmed
}

// setConfig applies one option and emits the server-confirmed state.
func (b *bridge) setConfig(sessionID, id, value string) string {
	res, confirmed := b.applyConfig(sessionID, id, value)
	if res == nil {
		return ""
	}
	switch id {
	case "model":
		if confirmed != "" {
			qemit(map[string]interface{}{"type": "model", "sessionId": sessionID, "model": confirmed})
		}
		if efforts, cur := parseEfforts(res); efforts != nil {
			qemit(map[string]interface{}{"type": "efforts", "sessionId": sessionID, "efforts": efforts, "effort": cur})
		} else {
			qemit(map[string]interface{}{"type": "efforts", "sessionId": sessionID, "efforts": []string{}, "effort": ""})
		}
	case "effort":
		if efforts, cur := parseEfforts(res); efforts != nil {
			qemit(map[string]interface{}{"type": "efforts", "sessionId": sessionID, "efforts": efforts, "effort": cur})
		}
	case "mode":
		if confirmed != "" {
			qemit(map[string]interface{}{"type": "mode", "sessionId": sessionID, "mode": confirmed})
		}
	}
	return confirmed
}

// "mode" is a config option in opencode's ACP, not an ACP mode object.
func (b *bridge) doMode(cmd map[string]interface{}) {
	sessionID, mode := cmdStr(cmd, "sessionId"), cmdStr(cmd, "mode")
	if sessionID == "" || mode == "" {
		return
	}
	sl := b.sessionLock(sessionID)
	sl.Lock()
	defer sl.Unlock()
	if err := b.ensureKnown(sessionID, cwdOf(cmd)); err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	b.setConfig(sessionID, "mode", mode)
}

func (b *bridge) doModel(cmd map[string]interface{}) {
	sessionID, model := cmdStr(cmd, "sessionId"), cmdStr(cmd, "model")
	if sessionID == "" || model == "" {
		return
	}
	sl := b.sessionLock(sessionID)
	sl.Lock()
	defer sl.Unlock()
	if err := b.ensureKnown(sessionID, cwdOf(cmd)); err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	b.setConfig(sessionID, "model", model)
}

func (b *bridge) doNew(cmd map[string]interface{}) {
	cwd := cwdOf(cmd)
	res, err := b.callTimeout("session/new", map[string]interface{}{"cwd": cwd, "mcpServers": []interface{}{}}, 180*time.Second)
	if err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	var r struct {
		SessionID     string         `json:"sessionId"`
		ConfigOptions []configOption `json:"configOptions"`
		Modes         *sessionModes  `json:"modes"`
	}
	if err := json.Unmarshal(res, &r); err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	models, current := modelsFromOptions(r.ConfigOptions)
	efforts, effort := effortsFromOptions(r.ConfigOptions)
	modes, mode := modesFromOptions(r.ConfigOptions)
	if len(modes) == 0 && r.Modes != nil {
		mode = r.Modes.CurrentModeID
		modes = modeIDs(r.Modes)
	}
	b.mu.Lock()
	b.known[r.SessionID] = cwd
	b.mu.Unlock()
	apply := func(id, value, old string) string {
		if value == "" || value == old {
			return old
		}
		if cur := b.setConfigQuiet(r.SessionID, id, value); cur != "" {
			return cur
		}
		return old
	}
	current = apply("model", cmdStr(cmd, "model"), current)
	effort = apply("effort", cmdStr(cmd, "effort"), effort)
	mode = apply("mode", cmdStr(cmd, "mode"), mode)
	qemit(map[string]interface{}{
		"type": "session", "sessionId": r.SessionID,
		"models": models, "model": current, "modes": modes, "mode": mode,
		"efforts": efforts, "effort": effort,
	})
}

// Resumes sessions this bridge hasn't seen (older shell run).
func (b *bridge) ensureKnown(sessionID, cwd string) error {
	b.mu.Lock()
	_, ok := b.known[sessionID]
	b.mu.Unlock()
	if ok {
		return nil
	}
	res, err := b.call("session/resume", map[string]interface{}{
		"sessionId": sessionID, "cwd": cwd, "mcpServers": []interface{}{},
	})
	if err != nil {
		return err
	}
	var r struct {
		ConfigOptions []configOption `json:"configOptions"`
		Modes         *sessionModes  `json:"modes"`
	}
	if json.Unmarshal(res, &r) == nil {
		b.emitSessionState(sessionID, r.ConfigOptions, r.Modes)
	}
	b.mu.Lock()
	b.known[sessionID] = cwd
	b.mu.Unlock()
	return nil
}

func (b *bridge) doSend(cmd map[string]interface{}) {
	sessionID, text := cmdStr(cmd, "sessionId"), cmdStr(cmd, "text")
	if sessionID == "" || text == "" {
		qemit(map[string]interface{}{"type": "error", "message": "send needs sessionId and text"})
		return
	}
	sl := b.sessionLock(sessionID)
	sl.Lock()
	defer sl.Unlock()
	cwd := cwdOf(cmd)
	if err := b.ensureKnown(sessionID, cwd); err != nil {
		qemit(map[string]interface{}{"type": "error", "message": err.Error()})
		return
	}
	if model := cmdStr(cmd, "model"); model != "" {
		b.setConfig(sessionID, "model", model)
	}
	if effort := cmdStr(cmd, "effort"); effort != "" {
		b.setConfig(sessionID, "effort", effort)
	}
	if mode := cmdStr(cmd, "mode"); mode != "" {
		b.setConfig(sessionID, "mode", mode)
	}
	qemit(map[string]interface{}{
		"type": "session.status", "properties": map[string]interface{}{
			"status": map[string]interface{}{"type": "busy"},
		},
	})
	res, err := b.callTimeout("session/prompt", map[string]interface{}{
		"sessionId": sessionID,
		"prompt":    []interface{}{map[string]interface{}{"type": "text", "text": text}},
	}, 600*time.Second)
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
		Usage      *struct {
			InputTokens  int `json:"inputTokens"`
			OutputTokens int `json:"outputTokens"`
			TotalTokens  int `json:"totalTokens"`
		} `json:"usage"`
	}
	json.Unmarshal(res, &r)
	if r.Usage != nil {
		qemit(map[string]interface{}{
			"type": "usage", "sessionId": sessionID,
			"input": r.Usage.InputTokens, "output": r.Usage.OutputTokens, "total": r.Usage.TotalTokens,
		})
	}
	qemit(map[string]interface{}{"type": "prompt-done", "stopReason": r.StopReason})
}

func (b *bridge) doReply(cmd map[string]interface{}) {
	var reqID int64
	idSeen := false
	switch v := cmd["reqId"].(type) {
	case float64:
		reqID, idSeen = int64(v), true
	case string:
		var n int64
		if _, err := fmt.Sscan(v, &n); err == nil {
			reqID, idSeen = n, true
		}
	case int64:
		reqID, idSeen = v, true
	}
	if !idSeen {
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
			outcome = map[string]interface{}{"outcome": "selected", "optionId": optionID}
		}
	}
	b.reply(reqID, map[string]interface{}{"outcome": outcome})
}

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

// Cancelling must answer pending permission requests, or the agent waits forever.
func (b *bridge) doCancel(cmd map[string]interface{}) {
	sessionID := cmdStr(cmd, "sessionId")
	if sessionID == "" {
		return
	}
	b.mu.Lock()
	pending := []int64{}
	for id, opts := range b.permOpt {
		hit := false
		for _, o := range opts {
			if o.sessionID == sessionID {
				hit = true
				break
			}
		}
		if hit {
			pending = append(pending, id)
			delete(b.permOpt, id)
		}
	}
	b.mu.Unlock()
	for _, id := range pending {
		b.reply(id, map[string]interface{}{"outcome": map[string]interface{}{"outcome": "cancelled"}})
	}
	b.notify("session/cancel", map[string]interface{}{"sessionId": sessionID})
}

func toolText(content json.RawMessage) string {
	var blocks []struct {
		Type string `json:"type"`
		Content *struct {
			Type string `json:"type"`
			Text string `json:"text"`
		} `json:"content"`
		Text string `json:"text"`
		Diff *struct {
			Path    string `json:"path"`
			OldText string `json:"oldText"`
			NewText string `json:"newText"`
		} `json:"diff"`
		TerminalID string `json:"terminalId"`
	}
	if err := json.Unmarshal(content, &blocks); err != nil {
		return truncateBlob(content, 4000)
	}
	var sb strings.Builder
	for _, bl := range blocks {
		switch {
		case bl.Content != nil && bl.Content.Text != "":
			sb.WriteString(bl.Content.Text)
		case bl.Text != "":
			sb.WriteString(bl.Text)
		case bl.Diff != nil:
			sb.WriteString("diff " + bl.Diff.Path + "\n" + bl.Diff.NewText)
		case bl.TerminalID != "":
			sb.WriteString("[terminal " + bl.TerminalID + "]")
		}
	}
	return truncateString(sb.String(), 4000)
}

// Tool updates are flat per spec; message chunks carry messageId + content.
type sessionUpdate struct {
	SessionUpdate     string          `json:"sessionUpdate"`
	MessageID         string          `json:"messageId"`
	Content           json.RawMessage `json:"content"`
	ToolCallID        string          `json:"toolCallId"`
	Title             string          `json:"title"`
	Kind              string          `json:"kind"`
	Status            string          `json:"status"`
	RawInput          json.RawMessage `json:"rawInput"`
	Locations         json.RawMessage `json:"locations"`
	AvailableCommands []struct {
		Name        string `json:"name"`
		Description string `json:"description"`
	} `json:"availableCommands"`
}

// raw carries the full update for kinds with their own shapes.
func (b *bridge) onUpdate(sessionID string, u sessionUpdate, raw json.RawMessage) {
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
					"kind": u.Kind, "locations": json.RawMessage(u.Locations),
					"state": map[string]interface{}{"status": "pending", "input": json.RawMessage(input)},
				},
			},
		})
	case "tool_call_update":
		qemit(map[string]interface{}{
			"type": "message.part.updated", "properties": map[string]interface{}{
				"part": map[string]interface{}{
					"type": "tool", "tool": u.Title, "callID": u.ToolCallID, "messageID": msgID,
					"kind": u.Kind, "locations": json.RawMessage(u.Locations),
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
	case "usage_update":
		var m map[string]interface{}
		if json.Unmarshal(raw, &m) == nil {
			qemit(map[string]interface{}{
				"type": "context", "sessionId": sessionID,
				"used": m["used"], "size": m["size"],
			})
		}
	case "session_info_update":
		var m map[string]interface{}
		if json.Unmarshal(raw, &m) == nil {
			if title, _ := m["title"].(string); title != "" {
				qemit(map[string]interface{}{
					"type": "session.info", "sessionId": sessionID, "title": title,
				})
			}
		}
	case "current_mode_update":
		var m map[string]interface{}
		if json.Unmarshal(raw, &m) == nil {
			if mode, _ := m["currentModeId"].(string); mode != "" {
				qemit(map[string]interface{}{
					"type": "mode", "sessionId": sessionID, "mode": mode,
				})
			}
		}
	case "config_option_update":
		var m map[string]interface{}
		if json.Unmarshal(raw, &m) == nil {
			qemit(map[string]interface{}{
				"type": "config", "sessionId": sessionID, "update": m,
			})
		}
	case "plan":
		var m map[string]interface{}
		if json.Unmarshal(raw, &m) == nil {
			qemit(map[string]interface{}{
				"type": "plan", "sessionId": sessionID, "plan": m,
			})
		}
	default:
		qemit(map[string]interface{}{
			"type": "update", "sessionId": sessionID, "kind": u.SessionUpdate,
		})
	}
}

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
			stored = append(stored, permOption{optionID: o.OptionID, kind: o.Kind, sessionID: p.SessionID})
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
	switch {
	case method == "fs/read_text_file" || method == "fs/write_text_file" ||
		strings.HasPrefix(method, "terminal/"):
		b.replyError(id, -32601, "client does not implement "+method)
		return
	}
	qemit(map[string]interface{}{
		"type": "agent-request", "reqId": id, "method": method, "params": string(params),
	})
}

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
	// Response (id, no method) vs agent request (id + method) vs notification.
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
	// Agent->client request?
	if hasID && hasMethod {
		var req acpRequest
		if err := json.Unmarshal([]byte(line), &req); err == nil {
			b.onAgentRequest(req.ID, req.Method, req.Params)
		}
		return
	}
	var msg struct {
		Method string `json:"method"`
		Params *struct {
			SessionID string          `json:"sessionId"`
			RawUpdate json.RawMessage `json:"update"`
		} `json:"params"`
	}
	if err := json.Unmarshal([]byte(line), &msg); err != nil || msg.Method == "" {
		return
	}
	if msg.Method != "session/update" || msg.Params == nil {
		return
	}
	var u sessionUpdate
	if err := json.Unmarshal(msg.Params.RawUpdate, &u); err != nil {
		return
	}
	b.onUpdate(msg.Params.SessionID, u, msg.Params.RawUpdate)
}

func cmdAcp() error {
	cmd := exec.Command("opencode", "acp")
	cmd.Env = append(os.Environ(), "XDG_DATA_HOME="+dataHome(), "OPENCODE_DATA_DIR="+opencodeDataDir())
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
	go func() {
		if err := cmd.Wait(); err != nil {
			b := br
			b.mu.Lock()
			for id, ch := range b.pending {
				delete(b.pending, id)
				select {
				case ch <- &acpResponse{ID: id, Error: &acpError{Code: -32603, Message: "agent process exited"}}:
				default:
				}
			}
			b.mu.Unlock()
			qemit(map[string]interface{}{"type": "agent.exited", "message": err.Error()})
		}
	}()

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
				case "mode":
					go br.doMode(c)
				case "reply":
					go br.doReply(c)
				case "cancel":
					go br.doCancel(c)
				case "sync":
					go br.doSync(c)
				default:
					qemit(map[string]interface{}{"type": "error", "message": fmt.Sprintf("unknown cmd: %v", c["cmd"])})
				}
			}
		}
		if err != nil {
			break
		}
	}
	return nil
}
