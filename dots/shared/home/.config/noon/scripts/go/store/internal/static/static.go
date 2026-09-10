package static

import (
	"encoding/json"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

const userAgent = "store-service/1.0"

// ponytail: static hubs are plain JSON indexes (multi-user via git PRs).
// Upgrade path: graduate to a real server reusing the same item schema.
type Hub struct {
	Id    string `json:"id"`
	Name  string `json:"name"`
	Index string `json:"index"`
}

type Plugin struct {
	Id          string   `json:"id"`
	Name        string   `json:"name"`
	Icon        string   `json:"icon"`
	Group       string   `json:"group"`
	Description string   `json:"description"`
	Version     string   `json:"version"`
	Maintainer  string   `json:"maintainer"`
	Preview     string   `json:"preview"`
	Previews    []string `json:"previews"`
	Download    string   `json:"download"`
}

func (p Plugin) AllPreviews() []string {
	out := append([]string{}, p.Previews...)
	if p.Preview != "" {
		seen := false
		for _, u := range out {
			if u == p.Preview {
				seen = true
				break
			}
		}
		if !seen {
			out = append([]string{p.Preview}, out...)
		}
	}
	if out == nil {
		out = []string{}
	}
	return out
}

type hit struct {
	plugins []Plugin
	exp     time.Time
}

var (
	mu     sync.RWMutex
	cache  = map[string]hit{}
	client = &http.Client{Timeout: 15 * time.Second}
)

func Title(s string) string {
	if s == "" {
		return s
	}
	return strings.ToUpper(s[:1]) + s[1:]
}

func CustomProvidersFile() string {
	if f := os.Getenv("STORE_PROVIDERS_FILE"); f != "" {
		return f
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".noon", "user", "store-providers.json")
}

func LoadHubs() []Hub {
	body, err := os.ReadFile(CustomProvidersFile())
	if err != nil {
		return nil
	}
	var env struct {
		Static []Hub `json:"static"`
	}
	if json.Unmarshal(body, &env) != nil {
		return nil
	}
	var out []Hub
	for _, h := range env.Static {
		if h.Id != "" && h.Index != "" {
			if h.Name == "" {
				h.Name = h.Id
			}
			out = append(out, h)
		}
	}
	return out
}

func FetchIndex(indexURL string) ([]Plugin, error) {
	mu.RLock()
	if h, ok := cache[indexURL]; ok && time.Now().Before(h.exp) {
		mu.RUnlock()
		return h.plugins, nil
	}
	mu.RUnlock()
	var body []byte
	var err error
	if strings.HasPrefix(indexURL, "file://") {
		body, err = os.ReadFile(strings.TrimPrefix(indexURL, "file://"))
	} else {
		var req *http.Request
		if req, err = http.NewRequest("GET", indexURL, nil); err == nil {
			req.Header.Set("User-Agent", userAgent)
			var resp *http.Response
			if resp, err = client.Do(req); err == nil {
				defer resp.Body.Close()
				if resp.StatusCode != 200 {
					err = fmt.Errorf("ocs_unreachable: status %d", resp.StatusCode)
				} else {
					body, err = io.ReadAll(io.LimitReader(resp.Body, 4<<20))
				}
			}
		}
		if err != nil {
			err = fmt.Errorf("ocs_unreachable: %w", err)
		}
	}
	if err != nil {
		return nil, err
	}
	var env struct {
		Plugins []Plugin `json:"plugins"`
	}
	if json.Unmarshal(body, &env) != nil {
		return nil, fmt.Errorf("ocs_unreachable: bad index")
	}
	mu.Lock()
	if len(cache) > 32 {
		cache = map[string]hit{}
	}
	cache[indexURL] = hit{plugins: env.Plugins, exp: time.Now().Add(5 * time.Minute)}
	mu.Unlock()
	return env.Plugins, nil
}
