package install

import (
	"archive/tar"
	"archive/zip"
	"compress/gzip"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"sort"
	"strings"
)

const MaxBytes = 500 * 1024 * 1024
const MaxEntries = 50000

var Kinds = []string{"icon-theme", "cursor-theme", "noon-plugin"}

func ValidKind(kind string) bool {
	for _, k := range Kinds {
		if k == kind {
			return true
		}
	}
	return false
}

func xdgTarget(kind, name string) (string, error) {
	home, _ := os.UserHomeDir()
	base := os.Getenv("XDG_DATA_HOME")
	if base == "" {
		base = filepath.Join(home, ".local", "share")
	}
	switch kind {
	case "icon-theme", "cursor-theme":
		return filepath.Join(base, "icons", name), nil
	}
	return "", fmt.Errorf("unknown kind %s", kind)
}

func within(root, p string) bool {
	rel, err := filepath.Rel(root, p)
	return err == nil && rel != ".." && !strings.HasPrefix(rel, ".."+string(os.PathSeparator))
}

func extractZip(archive, dest string) error {
	r, err := zip.OpenReader(archive)
	if err != nil {
		return err
	}
	defer r.Close()
	var total int64
	for i, f := range r.File {
		if i >= MaxEntries {
			return fmt.Errorf("too many entries")
		}
		fp := filepath.Join(dest, f.Name)
		if !within(dest, fp) || f.FileInfo().Mode()&os.ModeSymlink != 0 {
			if !within(dest, fp) {
				return fmt.Errorf("zip-slip %s", f.Name)
			}
			continue
		}
		if f.FileInfo().IsDir() {
			os.MkdirAll(fp, 0755)
			continue
		}
		os.MkdirAll(filepath.Dir(fp), 0755)
		rc, err := f.Open()
		if err != nil {
			return err
		}
		out, err := os.OpenFile(fp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, f.Mode())
		if err != nil {
			rc.Close()
			return err
		}
		n, err := io.CopyN(out, rc, MaxBytes-total)
		rc.Close()
		out.Close()
		if err != nil && err != io.EOF {
			return err
		}
		if total += n; total > MaxBytes {
			return fmt.Errorf("extract too large")
		}
	}
	return nil
}

func extractTar(r io.Reader, dest string) error {
	tr := tar.NewReader(r)
	var total int64
	for i := 0; ; i++ {
		if i >= MaxEntries {
			return fmt.Errorf("too many entries")
		}
		hdr, err := tr.Next()
		if err == io.EOF {
			return nil
		}
		if err != nil {
			return err
		}
		fp := filepath.Join(dest, hdr.Name)
		if !within(dest, fp) {
			return fmt.Errorf("zip-slip %s", hdr.Name)
		}
		if hdr.FileInfo().Mode()&os.ModeSymlink != 0 {
			continue
		}
		switch hdr.Typeflag {
		case tar.TypeDir:
			os.MkdirAll(fp, 0755)
		case tar.TypeReg, tar.TypeRegA:
			os.MkdirAll(filepath.Dir(fp), 0755)
			out, err := os.OpenFile(fp, os.O_WRONLY|os.O_CREATE|os.O_TRUNC, os.FileMode(hdr.Mode))
			if err != nil {
				return err
			}
			n, err := io.CopyN(out, tr, MaxBytes-total)
			out.Close()
			if err != nil && err != io.EOF {
				return err
			}
			if total += n; total > MaxBytes {
				return fmt.Errorf("extract too large")
			}
		}
	}
}

func extractTarGzFallback(archive, dest string) error {
	f, err := os.Open(archive)
	if err != nil {
		return err
	}
	defer f.Close()
	gz, err := gzip.NewReader(f)
	if err != nil {
		f.Seek(0, 0)
		return extractTar(f, dest)
	}
	defer gz.Close()
	return extractTar(gz, dest)
}

func extract(archive, dest string) error {
	l := strings.ToLower(archive)
	switch {
	case strings.HasSuffix(l, ".zip"):
		return extractZip(archive, dest)
	case strings.HasSuffix(l, ".tar.gz"), strings.HasSuffix(l, ".tgz"):
		f, err := os.Open(archive)
		if err != nil {
			return err
		}
		defer f.Close()
		if gz, err := gzip.NewReader(f); err == nil {
			defer gz.Close()
			return extractTar(gz, dest)
		}
		f.Seek(0, 0)
		return extractTar(f, dest)
	case strings.HasSuffix(l, ".tar.xz"), strings.HasSuffix(l, ".tar.bz2"), strings.HasSuffix(l, ".tar"):
		f, err := os.Open(archive)
		if err != nil {
			return err
		}
		defer f.Close()
		return extractTar(f, dest)
	}
	if f, err := os.Open(archive); err == nil {
		hdr := make([]byte, 4)
		n, _ := f.Read(hdr)
		f.Close()
		if n >= 2 && ((hdr[0] == 0x50 && hdr[1] == 0x4B) || (hdr[0] == 0x1F && hdr[1] == 0x8B)) {
			if extractZip(archive, dest) == nil {
				return nil
			}
			return extractTarGzFallback(archive, dest)
		}
	}
	in, err := os.Open(archive)
	if err != nil {
		return err
	}
	defer in.Close()
	os.MkdirAll(dest, 0755)
	out, err := os.Create(filepath.Join(dest, filepath.Base(archive)))
	if err != nil {
		return err
	}
	defer out.Close()
	_, err = io.Copy(out, io.LimitReader(in, MaxBytes))
	return err
}
func skipDir(name string) bool {
	return strings.HasPrefix(name, ".") || name == "__MACOSX"
}

// ponytail: real archives bury the theme next to README/LICENSE (__MACOSX).
// Hunt the marker 2 levels deep; prefer name match with the archive hint.
func findRoot(kind, tmp, hint string) string {
	if checkMarker(kind, tmp) == nil {
		return tmp
	}
	es, err := os.ReadDir(tmp)
	if err != nil {
		return tmp
	}
	var dirs, matches []string
	for _, e := range es {
		if !e.IsDir() || skipDir(e.Name()) {
			continue
		}
		d := filepath.Join(tmp, e.Name())
		dirs = append(dirs, d)
		if checkMarker(kind, d) == nil {
			matches = append(matches, d)
		}
	}
	if len(matches) == 0 && len(dirs) <= 50 {
		for _, d := range dirs {
			sub, err := os.ReadDir(d)
			if err != nil || len(sub) > 50 {
				continue
			}
			for _, e := range sub {
				if !e.IsDir() || skipDir(e.Name()) {
					continue
				}
				sd := filepath.Join(d, e.Name())
				if checkMarker(kind, sd) == nil {
					matches = append(matches, sd)
				}
			}
		}
	}
	if len(matches) == 1 {
		return matches[0]
	}
	if len(matches) > 1 {
		hn := strings.ToLower(hint)
		for _, m := range matches {
			bn := strings.ToLower(filepath.Base(m))
			if hn != "" && (strings.Contains(bn, hn) || strings.Contains(hn, bn)) {
				return m
			}
		}
		sort.Strings(matches)
		return matches[0]
	}
	return tmp
}

func checkMarker(kind, root string) error {
	switch kind {
	case "icon-theme":
		if _, err := os.Stat(filepath.Join(root, "index.theme")); err != nil {
			return fmt.Errorf("icon theme missing index.theme")
		}
	case "cursor-theme":
		if _, err := os.Stat(filepath.Join(root, "cursors")); err != nil {
			if _, err2 := os.Stat(filepath.Join(root, "cursor.theme")); err2 != nil {
				return fmt.Errorf("cursor theme missing cursors dir")
			}
		}
	case "noon-plugin":
		if _, err := os.Stat(filepath.Join(root, "manifest.json")); err != nil {
			return fmt.Errorf("No manifest.json in archive")
		}
	}
	return nil
}

func PluginsDir() string {
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".noon_plugins")
}

var pluginGroups = map[string]bool{
	"sidebar": true, "dock": true, "beam": true, "palettes": true, "widgets": true,
}

// ponytail: matches manifest name or dir name, case-insensitive (stopwatch vs Stopwatch)
func IsPluginInstalled(group, name string) bool {
	if group == "" || name == "" {
		return false
	}
	dir := filepath.Join(PluginsDir(), group)
	if st, err := os.Stat(filepath.Join(dir, name)); err == nil && st.IsDir() {
		return true
	}
	es, err := os.ReadDir(dir)
	if err != nil {
		return false
	}
	ln := strings.ToLower(name)
	for _, e := range es {
		if e.IsDir() && strings.ToLower(e.Name()) == ln {
			return true
		}
	}
	return false
}

// ponytail: mirrors plugins_helper.sh (manifest hunt, maxdepth 2)
func findManifestRoot(tmp string) string {
	if _, err := os.Stat(filepath.Join(tmp, "manifest.json")); err == nil {
		return tmp
	}
	es, err := os.ReadDir(tmp)
	if err != nil {
		return ""
	}
	for _, e := range es {
		if !e.IsDir() || skipDir(e.Name()) {
			continue
		}
		d := filepath.Join(tmp, e.Name())
		if _, err := os.Stat(filepath.Join(d, "manifest.json")); err == nil {
			return d
		}
	}
	return ""
}

func readManifest(dir string) (name, group string) {
	body, err := os.ReadFile(filepath.Join(dir, "manifest.json"))
	if err != nil {
		return "", ""
	}
	var m struct {
		Name  string `json:"name"`
		Group string `json:"pluginGroup"`
	}
	if err := json.Unmarshal(body, &m); err != nil {
		return "", ""
	}
	return m.Name, m.Group
}

// ponytail: /tmp and $HOME are different filesystems; rename falls back to copy
func moveDir(src, target string) error {
	if err := os.Rename(src, target); err == nil {
		return nil
	}
	return filepath.Walk(src, func(p string, info os.FileInfo, e error) error {
		if e != nil {
			return e
		}
		rel, _ := filepath.Rel(src, p)
		dp := filepath.Join(target, rel)
		if info.IsDir() {
			return os.MkdirAll(dp, 0755)
		}
		if err := os.MkdirAll(filepath.Dir(dp), 0755); err != nil {
			return err
		}
		in, err := os.Open(p)
		if err != nil {
			return err
		}
		defer in.Close()
		out, err := os.Create(dp)
		if err != nil {
			return err
		}
		defer out.Close()
		_, err = io.Copy(out, in)
		return err
	})
}

func Install(kind, archive, name string) (string, error) {
	if kind == "noon-plugin" {
		return installPlugin(archive, name)
	}
	if strings.Contains(name, "/") || strings.Contains(name, "..") {
		return "", fmt.Errorf("invalid name")
	}
	target, err := xdgTarget(kind, name)
	if err != nil {
		return "", err
	}
	tmp, err := os.MkdirTemp("", "store-install-*")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(tmp)
	if err := extract(archive, tmp); err != nil {
		return "", err
	}
	src := findRoot(kind, tmp, name)
	if err := checkMarker(kind, src); err != nil {
		return "", err
	}
	os.RemoveAll(target)
	os.MkdirAll(filepath.Dir(target), 0755)
	if err := moveDir(src, target); err != nil {
		return "", err
	}
	if err := checkMarker(kind, target); err != nil {
		return "", err
	}
	return target, nil
}

// name is "group/id"; group/id validated, manifest decides final names
func installPlugin(archive, name string) (string, error) {
	parts := strings.Split(name, "/")
	if len(parts) != 2 || !pluginGroups[parts[0]] || parts[1] == "" || strings.Contains(parts[1], "..") {
		return "", fmt.Errorf("invalid name, want group/id")
	}
	tmp, err := os.MkdirTemp("", "store-install-*")
	if err != nil {
		return "", err
	}
	defer os.RemoveAll(tmp)
	if err := extract(archive, tmp); err != nil {
		return "", err
	}
	src := findManifestRoot(tmp)
	if src == "" {
		return "", fmt.Errorf("No manifest.json in archive")
	}
	mname, mgroup := readManifest(src)
	if mname == "" {
		mname = parts[1]
	}
	group := parts[0]
	if pluginGroups[mgroup] {
		group = mgroup
	}
	target := filepath.Join(PluginsDir(), group, mname)
	os.RemoveAll(target)
	os.MkdirAll(filepath.Dir(target), 0755)
	if err := moveDir(src, target); err != nil {
		return "", err
	}
	if _, err := os.Stat(filepath.Join(target, "manifest.json")); err != nil {
		return "", fmt.Errorf("No manifest.json in archive")
	}
	return target, nil
}
