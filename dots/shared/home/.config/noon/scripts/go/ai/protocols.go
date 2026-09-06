package main

import (
	"database/sql"
	"encoding/json"
	"os"
	"path/filepath"
	"regexp"
	"sort"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

func dataHome() string {
	if d := os.Getenv("SESSION_DIR"); d != "" {
		return d
	}
	if d := os.Getenv("XDG_DATA_HOME"); d != "" {
		return d
	}
	return os.ExpandEnv("$HOME/.local/share")
}

func dbFile() string {
	return dataHome() + "/opencode/opencode.db"
}

// opencodeDataDir points at the standard data dir that holds auth.json.
// The vision plugin/script resolves its auth source from OPENCODE_DATA_DIR
// (falling back to XDG_DATA_HOME); the harness redirects XDG_DATA_HOME to the
// session dir, so without this the plugin can never find the saved provider
// credentials. opencode itself ignores this variable.
func opencodeDataDir() string {
	home := os.ExpandEnv("$HOME")
	if h, err := os.UserHomeDir(); err == nil && h != "" {
		home = h
	}
	return filepath.Join(home, ".local", "share", "opencode")
}

type Session struct {
	ID        string `json:"id"`
	Title     string `json:"title"`
	Created   int64  `json:"created"`
	Updated   int64  `json:"updated"`
	Directory string `json:"directory"`
	ProjectID string `json:"projectId"`
}

type ToolCall struct {
	Tool   string          `json:"tool"`
	CallID string          `json:"callID"`
	Status string          `json:"status"`
	Input  json.RawMessage `json:"input"`
	Output string          `json:"output"`
}

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
	return sql.Open("sqlite3", "file:"+dbFile()+"?mode=ro")
}

func truncateBlob(raw []byte, max int) string {
	if len(raw) == 0 {
		return ""
	}
	dec := json.NewDecoder(strings.NewReader(string(raw)))
	dec.UseNumber()
	var obj map[string]interface{}
	if err := dec.Decode(&obj); err == nil {
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

// Wrapper tags treated as machine context; extend as more appear.
var injectedTags = []string{"skill"}

var skillHeaderRe = regexp.MustCompile(`(?s)Follow the skill named "([^"]*)".*?<skill>.*?</skill>\s*Task:\s*`)

var injectedTagRes = map[string]*regexp.Regexp{}

func init() {
	for _, tag := range injectedTags {
		injectedTagRes[tag] = regexp.MustCompile(`(?s)<` + tag + `>.*?</` + tag + `>`)
	}
}

// Long <tag>...</tag> blocks collapse to a marker; short ones are kept.
func collapseInjectedBlocks(s string) string {
	s = skillHeaderRe.ReplaceAllStringFunc(s, func(m string) string {
		if len(m) < 200 {
			return m
		}
		sub := skillHeaderRe.FindStringSubmatch(m)
		name := ""
		if len(sub) > 1 {
			name = sub[1]
		}
		if name != "" {
			return "[Skill \"" + name + "\" injected]\n\n"
		}
		return "[<skill> context hidden]"
	})
	for tag, re := range injectedTagRes {
		s = re.ReplaceAllStringFunc(s, func(m string) string {
			if len(m) < 200 {
				return m
			}
			return "[<" + tag + "> context hidden]"
		})
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
	// Clamp, don't reset: QML compares out.length against the requested
	// size — a silent reset would end paging early.
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
			case "reasoning":
				if strings.TrimSpace(p.Text) != "" {
					txt.WriteString("<think>" + p.Text + "</think>")
				}
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

		content := txt.String()
		if content == "" && len(tools) == 0 {
			continue
		}
		// View shows collapsed context; RawContent keeps the full text.
		raw := content
		content = truncateString(collapseInjectedBlocks(content), 30000)
		var model string
		if meta.Model != nil {
			model = meta.Model.ModelID
		}
		out = append(out, Message{
			Role:              meta.Role,
			Content:           content,
			RawContent:        raw,
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
