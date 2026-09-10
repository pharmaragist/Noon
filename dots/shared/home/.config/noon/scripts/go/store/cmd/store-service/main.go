package main

import (
	"bufio"
	"context"
	"encoding/json"
	"fmt"
	"os"
	"path/filepath"
	"strings"
	"sync"

	"store-service/internal/download"
	"store-service/internal/install"
	"store-service/internal/ocs"
	"store-service/internal/rpc"
)

func pickFile(c ocs.Content, item *int) (ocs.Download, string) {
	if len(c.Files) == 0 {
		return ocs.Download{}, "no downloads"
	}
	idx := 0
	if item != nil {
		idx = *item
	}
	if idx < 0 || idx >= len(c.Files) {
		return ocs.Download{}, "downloadItemId out of range"
	}
	return c.Files[idx], ""
}

func destName(archive, fallback string) string {
	n := strings.TrimSuffix(filepath.Base(archive), filepath.Ext(archive))
	if strings.HasSuffix(n, ".tar") {
		n = strings.TrimSuffix(n, ".tar")
	}
	if n == "" {
		n = fallback
	}
	return strings.ReplaceAll(n, " ", "-")
}

func ensureArchive(ctx context.Context, provider, contentId string, c ocs.Content, prog func(recv, total int64, phase string)) (string, error) {
	dir := filepath.Join(download.CacheDir(), "downloads", provider, contentId)
	if es, _ := os.ReadDir(dir); len(es) > 0 {
		for _, e := range es {
			if !e.IsDir() {
				return filepath.Join(dir, e.Name()), nil
			}
		}
	}
	if len(c.Files) == 0 {
		return "", fmt.Errorf("no downloads")
	}
	dl := c.Files[0]
	os.MkdirAll(dir, 0755)
	name := dl.Name
	if name == "" {
		name = "download"
	}
	archive := filepath.Join(dir, name)
	_, _, err := download.Download(ctx, dl.Link, archive, prog)
	return archive, err
}

func handleRequest(rawId json.RawMessage, method string, params json.RawMessage) {
	progress := func(recv, total int64, phase string) {
		rpc.WriteProgress(rawId, recv, total, phase)
	}
	switch method {
	case "providers.list":
		out := []map[string]interface{}{}
		for _, p := range ocs.Providers() {
			has := false
			if cats, ok := ocs.CategoriesCached(p.Id); ok && len(cats) > 0 {
				has = true
			}
			out = append(out, map[string]interface{}{"id": p.Id, "name": p.Name, "baseUrl": p.BaseURL, "hasCategories": has, "static": p.Static})
		}
		rpc.WriteResult(rawId, map[string]interface{}{"providers": out})
	case "categories.list":
		var p struct {
			Provider string `json:"provider"`
		}
		if err := json.Unmarshal(params, &p); err != nil || p.Provider == "" {
			rpc.WriteError(rawId, "invalid_params", "provider required")
			return
		}
		cats, err := ocs.Categories(p.Provider)
		if err != nil {
			rpc.WriteError(rawId, "ocs_unreachable", err.Error())
			return
		}
		rpc.WriteResult(rawId, map[string]interface{}{"categories": cats})
	case "content.search":
		var p struct {
			Provider    string   `json:"provider"`
			CategoryIds []string `json:"categoryIds"`
			XdgType     string   `json:"xdgType"`
			Query       string   `json:"query"`
			Sort        string   `json:"sort"`
			Page        *int     `json:"page"`
			PageSize    *int     `json:"pageSize"`
		}
		if err := json.Unmarshal(params, &p); err != nil || p.Provider == "" {
			rpc.WriteError(rawId, "invalid_params", "provider required")
			return
		}
		page := 0
		if p.Page != nil {
			page = *p.Page
		}
		pageSize := 30
		if p.PageSize != nil {
			pageSize = *p.PageSize
		}
		var catIds []string
		for _, c := range p.CategoryIds {
			catIds = append(catIds, fmt.Sprintf("%v", c))
		}
		items, hasMore, err := ocs.Search(p.Provider, catIds, p.XdgType, p.Query, p.Sort, page, pageSize)
		if err != nil {
			rpc.WriteError(rawId, "ocs_unreachable", err.Error())
			return
		}
		rpc.WriteResult(rawId, map[string]interface{}{"items": items, "page": page, "hasMore": hasMore})
	case "content.get":
		var p struct {
			Provider  string `json:"provider"`
			ContentId string `json:"contentId"`
		}
		if err := json.Unmarshal(params, &p); err != nil || p.Provider == "" || p.ContentId == "" {
			rpc.WriteError(rawId, "invalid_params", "provider and contentId required")
			return
		}
		c, err := ocs.GetContent(p.Provider, p.ContentId)
		if err != nil {
			rpc.WriteError(rawId, "ocs_unreachable", err.Error())
			return
		}
		rpc.WriteResult(rawId, map[string]interface{}{"content": c})
	case "content.previewImage":
		var p struct {
			Provider  string   `json:"provider"`
			ContentId string   `json:"contentId"`
			Size      string   `json:"size"`
			URL       string   `json:"url"`
			Previews  []string `json:"previews"`
		}
		if err := json.Unmarshal(params, &p); err != nil || p.Provider == "" || p.ContentId == "" {
			rpc.WriteError(rawId, "invalid_params", "provider and contentId required")
			return
		}
		ctx := context.Background()
		u := p.URL
		if u == "" {
			pvs := p.Previews
			if len(pvs) == 0 {
				c, err := ocs.GetContent(p.Provider, p.ContentId)
				if err != nil {
					rpc.WriteError(rawId, "ocs_unreachable", err.Error())
					return
				}
				pvs = c.Previews
			}
			if len(pvs) == 0 {
				rpc.WriteError(rawId, "ocs_unreachable", "no preview")
				return
			}
			u = ocs.PickPreview(pvs, p.Size)
		}
		os.MkdirAll(filepath.Join(download.CacheDir(), "previews"), 0755)
		dest := ocs.PreviewDest(p.ContentId, p.Size, u)
		if st, err := os.Stat(dest); err == nil && st.Size() > 0 {
			rpc.WriteResult(rawId, map[string]interface{}{"path": dest})
			return
		}
		local, _, err := download.Download(ctx, u, dest, progress)
		if err != nil {
			rpc.WriteError(rawId, "download_failed", err.Error())
			return
		}
		rpc.WriteResult(rawId, map[string]interface{}{"path": local})
	case "content.download":
		var p struct {
			Provider       string `json:"provider"`
			ContentId      string `json:"contentId"`
			DownloadItemId *int   `json:"downloadItemId"`
		}
		if err := json.Unmarshal(params, &p); err != nil || p.Provider == "" || p.ContentId == "" {
			rpc.WriteError(rawId, "invalid_params", "provider and contentId required")
			return
		}
		ctx := context.Background()
		c, err := ocs.GetContent(p.Provider, p.ContentId)
		if err != nil {
			rpc.WriteError(rawId, "ocs_unreachable", err.Error())
			return
		}
		dl, msg := pickFile(c, p.DownloadItemId)
		if msg != "" {
			code := "not_found"
			if msg == "downloadItemId out of range" {
				code = "invalid_params"
			}
			rpc.WriteError(rawId, code, msg)
			return
		}
		name := dl.Name
		if name == "" {
			name = ocs.BaseName(dl.Link)
		}
		dir := filepath.Join(download.CacheDir(), "downloads", p.Provider, p.ContentId)
		os.MkdirAll(dir, 0755)
		local, ftype, err := download.Download(ctx, dl.Link, filepath.Join(dir, name), progress)
		if err != nil {
			rpc.WriteError(rawId, "download_failed", err.Error())
			return
		}
		rpc.WriteResult(rawId, map[string]interface{}{"path": local, "fileType": ftype, "downloadName": name})
	case "content.install":
		var p struct {
			Provider  string `json:"provider"`
			ContentId string `json:"contentId"`
			Kind      string `json:"kind"`
			Name      string `json:"name"`
		}
		if err := json.Unmarshal(params, &p); err != nil || p.Provider == "" || p.ContentId == "" || p.Kind == "" {
			rpc.WriteError(rawId, "invalid_params", "provider, contentId and kind required")
			return
		}
		if !install.ValidKind(p.Kind) {
			rpc.WriteError(rawId, "invalid_params", "invalid kind")
			return
		}
		c, err := ocs.GetContent(p.Provider, p.ContentId)
		if err != nil {
			rpc.WriteError(rawId, "ocs_unreachable", err.Error())
			return
		}
		archive, err := ensureArchive(context.Background(), p.Provider, p.ContentId, c, progress)
		if err != nil {
			rpc.WriteError(rawId, "download_failed", err.Error())
			return
		}
		name := p.Name
		if name == "" {
			name = destName(archive, c.Name)
		}
		rpc.WriteEvent(rawId, "progress", map[string]interface{}{"phase": "installing", "receivedBytes": 0, "totalBytes": 0})
		target, err := install.Install(p.Kind, archive, name)
		if err != nil {
			rpc.WriteError(rawId, "install_failed", err.Error())
			return
		}
		rpc.WriteResult(rawId, map[string]interface{}{"path": target, "kind": p.Kind})
	default:
		rpc.WriteError(rawId, "method_not_found", "unknown method "+method)
	}
}

func isTTY() bool {
	fi, err := os.Stdin.Stat()
	if err != nil {
		return false
	}
	return fi.Mode()&os.ModeCharDevice != 0
}

func printUsage() {
	fmt.Fprintln(os.Stderr, "store-service - Noon Store backend (themes, plugins)")
	fmt.Fprintln(os.Stderr, "usage:")
	fmt.Fprintln(os.Stderr, "  store-service          # bridge mode (newline JSON over stdin/stdout)")
	fmt.Fprintln(os.Stderr, "  store-service --help   # this text")
	fmt.Fprintln(os.Stderr, "")
	fmt.Fprintln(os.Stderr, "kinds: "+strings.Join(install.Kinds, ", "))
}

func main() {
	if len(os.Args) > 1 {
		printUsage()
		if os.Args[1] == "help" || os.Args[1] == "--help" || os.Args[1] == "-h" {
			os.Exit(0)
		}
		os.Exit(2)
	}
	if isTTY() {
		printUsage()
		os.Exit(2)
	}
	scanner := bufio.NewScanner(os.Stdin)
	buf := make([]byte, 0, 64*1024)
	scanner.Buffer(buf, 10*1024*1024)
	var wg sync.WaitGroup
	sem := make(chan struct{}, 16)
	for scanner.Scan() {
		line := strings.TrimSpace(scanner.Text())
		if line == "" {
			continue
		}
		var req rpc.Request
		if err := json.Unmarshal([]byte(line), &req); err != nil {
			rpc.WriteError(nil, "parse_error", "bad json")
			continue
		}
		if req.Method == "" || len(req.Id) == 0 || string(req.Id) == "null" {
			rpc.WriteError(req.Id, "invalid_request", "method and id required")
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func(r rpc.Request) {
			defer wg.Done()
			defer func() { <-sem }()
			defer func() {
				if rec := recover(); rec != nil {
					rpc.WriteError(r.Id, "internal_error", fmt.Sprintf("%v", rec))
				}
			}()
			handleRequest(r.Id, r.Method, r.Params)
		}(req)
	}
	wg.Wait()
	if err := scanner.Err(); err != nil {
		_ = err
	}
}
