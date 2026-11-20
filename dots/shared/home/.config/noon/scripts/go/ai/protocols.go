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
	ThinkText         string        `json:"thinkText,omitempty"`
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

var injectedTags = []string{"skill"}

var skillHeaderRe = regexp.MustCompile(`(?s)Follow the skill named "([^"]*)".*?<skill>.*?</skill>\s*Task:\s*`)

var injectedTagRes = map[string]*regexp.Regexp{}

func init() {
	for _, tag := range injectedTags {
		injectedTagRes[tag] = regexp.MustCompile(`(?s)<` + tag + `>.*?</` + tag + `>`)
	}
}

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
		FROM session_v2 ORDER BY time_updated DESC`)
	if err != nil {
		return err
	}
	defer rows.Close()

	out := []Session{}
	for rows.Next() {
		var s Session
		var title sql.NullString
		if err := rows.Scan(&s.ID, &title, &s.Created, &s.Updated, &s.Directory, &s.ProjectID); err != nil {
			return err
		}
		if title.Valid {
			s.Title = title.String
		}
		out = append(out, s)
	}
	return emit(out)
}



func cmdChat(sessionID string, limit, offset int) error {
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

	rows, err := db.Query(`SELECT seq, type, data FROM session_message WHERE session_id = ? ORDER BY seq DESC LIMIT ? OFFSET ?`, sessionID, limit, offset)
	if err != nil {
		return err
	}
	defer rows.Close()

	type row struct {
		seq  int64
		typ  string
		data string
	}
	collected := []row{}
	for rows.Next() {
		var r row
		if err := rows.Scan(&r.seq, &r.typ, &r.data); err != nil {
			return err
		}
		collected = append(collected, r)
	}
	if err := rows.Err(); err != nil {
		return err
	}
	for i, j := 0, len(collected)-1; i < j; i, j = i+1, j-1 {
		collected[i], collected[j] = collected[j], collected[i]
	}

	out := []Message{}
	for _, r := range collected {
		var d struct {
			Agent   string `json:"agent"`
			Model   struct {
				ID string `json:"id"`
			} `json:"model"`
			Content []struct {
				Type  string          `json:"type"`
				Text  string          `json:"text"`
				ID    string          `json:"id"`
				Name  string          `json:"name"`
				State json.RawMessage `json:"state"`
			} `json:"content"`
			Text string `json:"text"`
		}
		if err := json.Unmarshal([]byte(r.data), &d); err != nil {
			continue
		}

		var txt strings.Builder
		var think strings.Builder
		tools := []ToolCall{}
		if r.typ == "user" {
			txt.WriteString(d.Text)
		} else {
			for _, part := range d.Content {
				switch part.Type {
				case "text":
					txt.WriteString(part.Text)
				case "reasoning":
					think.WriteString(part.Text)
				case "tool":
					var st struct {
						Status string          `json:"status"`
						Input  json.RawMessage `json:"input"`
						Output string          `json:"output"`
						Error  interface{}     `json:"error"`
					}
					json.Unmarshal(part.State, &st)
					output := st.Output
					if output == "" && st.Error != nil {
						if s, ok := st.Error.(string); ok {
							output = s
						} else {
							b, _ := json.Marshal(st.Error)
							output = string(b)
						}
					}
					tools = append(tools, ToolCall{
						Tool:   part.Name,
						CallID: part.ID,
						Status: st.Status,
						Input:  st.Input,
						Output: truncateString(output, 4000),
					})
				}
			}
		}

		content := txt.String()
		thinkText := think.String()
		if r.typ == "user" && strings.TrimSpace(content) == "" {
			continue
		}
		if r.typ != "user" && strings.TrimSpace(content) == "" && strings.TrimSpace(thinkText) == "" && len(tools) == 0 {
			continue
		}

		raw := truncateString(content, 100000)
		content = truncateString(collapseInjectedBlocks(content), 30000)
		role := r.typ
		if role != "user" && role != "assistant" {
			role = "assistant"
		}
		out = append(out, Message{
			Role:              role,
			Content:           content,
			ThinkText:         truncateString(thinkText, 30000),
			RawContent:        raw,
			Model:             d.Model.ID,
			Thinking:          false,
			Done:              true,
			Tools:             tools,
			AnnotationSources: []interface{}{},
			VisibleToUser:     true,
			Agent:             d.Agent,
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
	home := os.ExpandEnv("$HOME")
	if h, err := os.UserHomeDir(); err == nil && h != "" {
		home = h
	}
	root := filepath.Join(home, ".config", "opencode", "skills")
	set := map[string]bool{}
	err := filepath.Walk(root, func(path string, info os.FileInfo, err error) error {
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
