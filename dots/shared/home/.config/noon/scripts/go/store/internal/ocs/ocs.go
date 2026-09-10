package ocs

import (
	"bytes"
	"encoding/xml"
	"fmt"
	"io"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"sort"
	"strconv"
	"strings"
	"sync"
	"time"

	"store-service/internal/install"
	"store-service/internal/static"
)

const UserAgent = "store-service/1.0"

const fallbackOCS = "https://api.kde-look.org/ocs/v1"

var httpClient = &http.Client{Timeout: 15 * time.Second}

type Provider struct {
	Id            string `json:"id"`
	Name          string `json:"name"`
	BaseURL       string `json:"baseUrl"`
	HasCategories bool   `json:"hasCategories"`
	Static        bool   `json:"static"`
}

type Category struct {
	Id       string `json:"id"`
	Name     string `json:"name"`
	ParentId string `json:"parentId"`
	XdgType  string `json:"xdgType"`
}

type Download struct {
	Link string `json:"link"`
	Name string `json:"name"`
	Type string `json:"type"`
	Size int64  `json:"size,omitempty"`
}

type Content struct {
	Id         string     `json:"id"`
	Name       string     `json:"name"`
	Icon       string     `json:"icon,omitempty"`
	Installed  bool       `json:"installed,omitempty"`
	TypeId     string     `json:"typeId"`
	TypeName   string     `json:"typeName"`
	Desc       string     `json:"description"`
	Summary    string     `json:"summary"`
	Score      string     `json:"score"`
	Downloads  int        `json:"downloadsCount"`
	PersonId   string     `json:"personId"`
	XdgType    string     `json:"xdgType"`
	Previews   []string   `json:"previews"`
	Files      []Download `json:"downloads"`
	DetailPage string     `json:"detailPage"`
	Changed    string     `json:"changed"`
}

func builtin() []Provider {
	return []Provider{
		{Id: "kde-store", Name: "store.kde.org", BaseURL: "https://store.kde.org"},
		{Id: "pling", Name: "pling.com", BaseURL: "https://www.pling.com"},
	}
}

var (
	provOnce  sync.Once
	provCache []Provider
	catCache  sync.Map // string -> []Category
)

type contentHit struct {
	c   Content
	exp time.Time
}

var (
	ccMu  sync.RWMutex
	ccMap = map[string]contentHit{}
)

func Providers() []Provider {
	provOnce.Do(func() {
		provCache = builtin()
		seen := map[string]bool{}
		for _, p := range provCache {
			seen[p.Id] = true
		}
		for _, h := range static.LoadHubs() {
			if !seen[h.Id] {
				seen[h.Id] = true
				name := h.Name
				if name == "" {
					name = h.Id
				}
				provCache = append(provCache, Provider{Id: h.Id, Name: name, BaseURL: h.Index, Static: true})
			}
		}
	})
	cp := make([]Provider, len(provCache))
	copy(cp, provCache)
	return cp
}

func FindProvider(id string) (Provider, bool) {
	for _, p := range Providers() {
		if p.Id == id {
			return p, true
		}
	}
	return Provider{}, false
}

func CategoriesCached(providerID string) ([]Category, bool) {
	if v, ok := catCache.Load(providerID); ok {
		return v.([]Category), true
	}
	return nil, false
}

func ocsBase(p Provider) string {
	b := strings.TrimSuffix(p.BaseURL, "/")
	if strings.HasSuffix(b, "/ocs/v1") || strings.HasSuffix(b, "/ocs") {
		return b
	}
	if strings.Contains(b, "api.kde-look.org") {
		return b + "/ocs/v1"
	}
	return b + "/ocs/v1"
}

func fetchOne(u string) ([]byte, error) {
	req, _ := http.NewRequest("GET", u, nil)
	req.Header.Set("User-Agent", UserAgent)
	resp, err := httpClient.Do(req)
	if err != nil {
		return nil, fmt.Errorf("ocs_unreachable: %w", err)
	}
	defer resp.Body.Close()
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 8<<20))
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("ocs_unreachable: status %d", resp.StatusCode)
	}
	if !bytes.Contains(body, []byte("<ocs")) {
		// ponytail: dead mirrors answer HTTP 200 with JSON 410; reject by body
		return nil, fmt.Errorf("ocs_unreachable: unexpected response")
	}
	return body, nil
}

func get(path, query, providerID string) ([]byte, error) {
	prov, ok := FindProvider(providerID)
	if !ok {
		return nil, fmt.Errorf("unknown provider %s", providerID)
	}
	urls := []string{ocsBase(prov) + path + query}
	if ocsBase(prov) != fallbackOCS {
		urls = append(urls, fallbackOCS+path+query)
	}
	err := fmt.Errorf("ocs_unreachable")
	for _, u := range urls {
		body, ferr := fetchOne(u)
		if ferr == nil {
			return body, nil
		}
		err = ferr
	}
	return nil, err
}

func Categories(providerID string) ([]Category, error) {
	if v, ok := catCache.Load(providerID); ok {
		return v.([]Category), nil
	}
	if prov, ok := FindProvider(providerID); ok && prov.Static {
		plugins, err := static.FetchIndex(prov.BaseURL)
		if err != nil {
			return nil, err
		}
		seen := map[string]bool{}
		var out []Category
		for _, p := range plugins {
			if p.Group == "" || seen[p.Group] {
				continue
			}
			seen[p.Group] = true
			out = append(out, Category{Id: p.Group, Name: static.Title(p.Group)})
		}
		if out == nil {
			out = []Category{}
		}
		sort.Slice(out, func(i, j int) bool { return out[i].Id < out[j].Id })
		catCache.Store(providerID, out)
		return out, nil
	}
	body, err := get("/content/categories", "", providerID)
	if err != nil {
		return nil, err
	}
	var env struct {
		XMLName xml.Name `xml:"ocs"`
		Meta    struct {
			Status     string `xml:"status"`
			StatusCode string `xml:"statuscode"`
			Message    string `xml:"message"`
		} `xml:"meta"`
		Data struct {
			Items []struct {
				Id       string `xml:"id"`
				Name     string `xml:"name"`
				ParentId string `xml:"parent_id"`
				XdgType  string `xml:"xdg_type"`
			} `xml:"category"`
		} `xml:"data"`
	}
	if xml.Unmarshal(body, &env) != nil {
		return nil, fmt.Errorf("ocs_unreachable: bad xml")
	}
	if env.Meta.Status != "ok" && env.Meta.StatusCode != "100" && env.Meta.Status != "" {
		return nil, fmt.Errorf("ocs error %s %s", env.Meta.Status, env.Meta.Message)
	}
	out := make([]Category, 0, len(env.Data.Items))
	for _, c := range env.Data.Items {
		out = append(out, Category{Id: c.Id, Name: c.Name, ParentId: c.ParentId, XdgType: c.XdgType})
	}
	catCache.Store(providerID, out)
	return out, nil
}

func numSuffix(s string) (int, string) {
	i := len(s)
	for i > 0 && s[i-1] >= '0' && s[i-1] <= '9' {
		i--
	}
	if i == len(s) {
		return 1 << 30, s
	}
	n, _ := strconv.Atoi(s[i:])
	return n, s[:i]
}

func decodeContents(body []byte) (total, perPage int, raws []map[string]string, err error) {
	dec := xml.NewDecoder(bytes.NewReader(body))
	var status, code string
	for {
		tok, e := dec.Token()
		if e != nil {
			break
		}
		se, isStart := tok.(xml.StartElement)
		if !isStart {
			continue
		}
		switch se.Name.Local {
		case "meta":
			var m struct {
				Status       string `xml:"status"`
				StatusCode   string `xml:"statuscode"`
				Message      string `xml:"message"`
				TotalItems   int    `xml:"totalitems"`
				ItemsPerPage int    `xml:"itemsperpage"`
			}
			if e := dec.DecodeElement(&m, &se); e != nil {
				return 0, 0, nil, e
			}
			status, code, total, perPage = m.Status, m.StatusCode, m.TotalItems, m.ItemsPerPage
			if status != "ok" && status != "" && code != "100" {
				return 0, 0, nil, fmt.Errorf("ocs error %s", m.Message)
			}
		case "content":
			m := map[string]string{}
			depth := 1
			for depth > 0 {
				t, e := dec.Token()
				if e != nil {
					return 0, 0, nil, e
				}
				switch x := t.(type) {
				case xml.StartElement:
					depth++
					if depth == 2 {
						var s string
						if e := dec.DecodeElement(&s, &x); e != nil {
							return 0, 0, nil, e
						}
						depth--
						m[x.Name.Local] = s
					}
				case xml.EndElement:
					depth--
				}
			}
			raws = append(raws, m)
		}
	}
	return total, perPage, raws, nil
}

// ponytail: grid wants the smallest preview, dialog the main one.
// Upgrade path: read real dimensions via image.DecodeConfig on probe bytes.
func PickPreview(pvs []string, size string) string {
	if len(pvs) == 0 {
		return ""
	}
	if size != "small" && size != "thumb" {
		return pvs[0]
	}
	best, bestScore := pvs[0], 100
	for _, u := range pvs {
		l := strings.ToLower(u)
		s := 50
		switch {
		case strings.Contains(l, "thumbnail"), strings.Contains(l, "small"):
			s = 0
		case strings.Contains(l, "770x540"), strings.Contains(l, "560x"), strings.Contains(l, "512x"):
			s = 1
		case strings.Contains(l, "preview"):
			s = 2
		}
		if s < bestScore {
			best, bestScore = u, s
		}
	}
	return best
}

func PreviewDest(contentId, size, u string) string {
	ext := ".jpg"
	if strings.Contains(u, ".png") {
		ext = ".png"
	} else if strings.Contains(u, ".gif") {
		ext = ".gif"
	}
	name := contentId
	if size == "small" || size == "thumb" {
		name += "_small"
	}
	return filepath.Join(cacheDir(), "previews", name+ext)
}

func cacheDir() string {
	if d := os.Getenv("XDG_CACHE_HOME"); d != "" {
		return filepath.Join(d, "store-service")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".cache", "store-service")
}

func fold(m map[string]string) Content {
	var picKeys, pvKeys []string
	for k := range m {
		lk := strings.ToLower(k)
		if strings.HasPrefix(lk, "previewpic") {
			picKeys = append(picKeys, k)
		} else if strings.HasPrefix(lk, "preview") {
			pvKeys = append(pvKeys, k)
		}
	}
	sortByNum := func(ks []string) {
		sort.Slice(ks, func(i, j int) bool {
			ni, _ := numSuffix(strings.ToLower(ks[i]))
			nj, _ := numSuffix(strings.ToLower(ks[j]))
			return ni < nj
		})
	}
	sortByNum(picKeys)
	sortByNum(pvKeys)
	var previews []string
	for _, k := range picKeys {
		if m[k] != "" {
			previews = append(previews, m[k])
		}
	}
	if len(previews) == 0 {
		for _, k := range pvKeys {
			if m[k] != "" {
				previews = append(previews, m[k])
			}
		}
	}
	if previews == nil {
		previews = []string{}
	}
	// downloads grouped by numeric suffix
	idxSet := map[int]bool{}
	for k := range m {
		if strings.HasPrefix(strings.ToLower(k), "downloadlink") {
			n, _ := numSuffix(strings.ToLower(k))
			if m[k] != "" {
				idxSet[n] = true
			}
		}
	}
	var idxs []int
	for n := range idxSet {
		idxs = append(idxs, n)
	}
	sort.Ints(idxs)
	var dls []Download
	for _, n := range idxs {
		s := strconv.Itoa(n)
		link := m["downloadlink"+s]
		if link == "" {
			continue
		}
		var sz int64
		if m["downloadsize"+s] != "" {
			sz, _ = strconv.ParseInt(m["downloadsize"+s], 10, 64)
		}
		dls = append(dls, Download{Link: link, Name: m["downloadname"+s], Type: m["downloadtype"+s], Size: sz})
	}
	if dls == nil {
		dls = []Download{}
	}
	n, _ := strconv.Atoi(m["downloads"])
	return Content{
		Id: m["id"], Name: m["name"], TypeId: m["typeid"], TypeName: m["typename"],
		Desc: m["description"], Summary: m["summary"], Score: m["score"],
		Downloads: n, PersonId: m["personid"], XdgType: m["xdg_type"],
		Previews: previews, Files: dls, DetailPage: m["detailpage"], Changed: m["changed"],
	}
}

func BaseName(p string) string {
	n := filepath.Base(p)
	if q := strings.Index(n, "?"); q >= 0 {
		n = n[:q]
	}
	if n == "" {
		n = "download"
	}
	return n
}

func staticToContent(indexURL string, p static.Plugin) Content {
	name := p.Name
	if name == "" {
		name = p.Id
	}
	id := p.Id
	if id == "" {
		id = name
	}
	dlName := p.Id + ".zip"
	if p.Download != "" {
		if b := BaseName(p.Download); b != "" && b != "download" {
			dlName = b
		}
	}
	installed := install.IsPluginInstalled(p.Group, name)
	return Content{
		Id: id, Name: name, Icon: p.Icon, Installed: installed, TypeId: p.Group, TypeName: static.Title(p.Group),
		Desc: p.Description, Summary: p.Description,
		Downloads: 0, PersonId: p.Maintainer, XdgType: "noon-plugin",
		Previews:   p.AllPreviews(),
		Files:      []Download{{Link: p.Download, Name: dlName, Type: "zip"}},
		DetailPage: indexURL, Changed: p.Version,
	}
}

func staticSearch(prov Provider, cats []string, q string, page, pageSize int) ([]Content, bool, error) {
	plugins, err := static.FetchIndex(prov.BaseURL)
	if err != nil {
		return nil, false, err
	}
	inCats := map[string]bool{}
	for _, c := range cats {
		inCats[c] = true
	}
	ql := strings.ToLower(q)
	var items []Content
	for _, p := range plugins {
		if p.Id == "" || p.Download == "" {
			continue
		}
		if len(inCats) > 0 && !inCats[p.Group] {
			continue
		}
		if ql != "" && !strings.Contains(strings.ToLower(p.Id+" "+p.Name+" "+p.Description), ql) {
			continue
		}
		items = append(items, staticToContent(prov.BaseURL, p))
	}
	if items == nil {
		items = []Content{}
	}
	start := page * pageSize
	if start >= len(items) {
		return []Content{}, false, nil
	}
	end := start + pageSize
	if end > len(items) {
		end = len(items)
	}
	return items[start:end], end < len(items), nil
}

func Search(providerID string, cats []string, xdg, q, sortMode string, page, pageSize int) ([]Content, bool, error) {
	prov, ok := FindProvider(providerID)
	if !ok {
		return nil, false, fmt.Errorf("unknown provider %s", providerID)
	}
	if pageSize <= 0 {
		pageSize = 30
	}
	if prov.Static {
		return staticSearch(prov, cats, q, page, pageSize)
	}
	if xdg != "" && len(cats) == 0 {
		// ponytail: server ignores xdg_types; resolve to category ids instead
		all, err := Categories(providerID)
		if err != nil {
			return nil, false, err
		}
		for _, c := range all {
			if c.XdgType == xdg {
				cats = append(cats, c.Id)
			}
		}
	}
	v := url.Values{}
	if len(cats) > 0 {
		v.Set("categories", strings.Join(cats, "x"))
	}
	if xdg != "" {
		v.Set("xdg_types", xdg)
	}
	if q != "" {
		v.Set("search", q)
	}
	if sortMode != "" {
		v.Set("sortmode", sortMode)
	}
	v.Set("page", strconv.Itoa(page))
	v.Set("pagesize", strconv.Itoa(pageSize))
	qs := "?" + v.Encode()
	if os.Getenv("STORE_DEBUG") != "" || os.Getenv("OCS_DEBUG") != "" {
		fmt.Fprintf(os.Stderr, "DEBUG provider=%s xdg=%s cats=%v qs=%s\n", providerID, xdg, cats, qs)
	}
	body, err := get("/content/data", qs, providerID)
	if err != nil {
		return nil, false, err
	}
	total, perPage, raws, err := decodeContents(body)
	if err != nil {
		return nil, false, err
	}
	items := make([]Content, 0, len(raws))
	for _, r := range raws {
		items = append(items, fold(r))
	}
	more := len(items) == pageSize
	if total > 0 {
		more = (page+1)*pageSize < total
	}
	if perPage > 0 && len(items) < perPage {
		more = false
	}
	return items, more, nil
}

func GetContent(providerID, contentId string) (Content, error) {
	if prov, ok := FindProvider(providerID); ok && prov.Static {
		plugins, err := static.FetchIndex(prov.BaseURL)
		if err != nil {
			return Content{}, err
		}
		for _, p := range plugins {
			if p.Id == contentId || p.Name == contentId {
				if p.Download == "" {
					return Content{}, fmt.Errorf("not_found")
				}
				return staticToContent(prov.BaseURL, p), nil
			}
		}
		return Content{}, fmt.Errorf("not_found")
	}
	key := providerID + "\x00" + contentId
	ccMu.RLock()
	if h, ok := ccMap[key]; ok && time.Now().Before(h.exp) {
		ccMu.RUnlock()
		return h.c, nil
	}
	ccMu.RUnlock()
	body, err := get("/content/data/"+url.PathEscape(contentId), "", providerID)
	if err != nil {
		return Content{}, err
	}
	_, _, raws, err := decodeContents(body)
	if err != nil {
		return Content{}, err
	}
	if len(raws) == 0 {
		return Content{}, fmt.Errorf("not_found")
	}
	c := fold(raws[0])
	ccMu.Lock()
	if len(ccMap) > 500 {
		ccMap = map[string]contentHit{}
	}
	ccMap[key] = contentHit{c: c, exp: time.Now().Add(5 * time.Minute)}
	ccMu.Unlock()
	return c, nil
}
