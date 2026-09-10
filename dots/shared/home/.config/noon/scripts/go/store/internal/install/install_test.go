package install

import (
	"archive/zip"
	"os"
	"path/filepath"
	"testing"
)

// ponytail: the one check that fails if install logic breaks.

func mkzip(t *testing.T, zp string, files map[string]string) {
	t.Helper()
	zf, err := os.Create(zp)
	if err != nil {
		t.Fatal(err)
	}
	w := zip.NewWriter(zf)
	for n, body := range files {
		f, err := w.Create(n)
		if err != nil {
			t.Fatal(err)
		}
		f.Write([]byte(body))
	}
	w.Close()
	zf.Close()
}

func isolateHome(t *testing.T) string {
	t.Helper()
	tmp := t.TempDir()
	for _, kv := range [][2]string{{"HOME", tmp}, {"XDG_DATA_HOME", filepath.Join(tmp, "data")}} {
		old, had := os.LookupEnv(kv[0])
		os.Setenv(kv[0], kv[1])
		k, v, h := kv[0], old, had
		t.Cleanup(func() {
			if h {
				os.Setenv(k, v)
			} else {
				os.Unsetenv(k)
			}
		})
	}
	return tmp
}

func TestInstallIconTheme(t *testing.T) {
	tmp := isolateHome(t)
	zp := filepath.Join(tmp, "theme.zip")
	mkzip(t, zp, map[string]string{"MyTheme/index.theme": "[Icon Theme]\nName=MyTheme\n"})
	target, err := Install("icon-theme", zp, "MyTheme-store-test")
	if err != nil {
		t.Fatalf("install: %v", err)
	}
	if _, err := os.Stat(filepath.Join(target, "index.theme")); err != nil {
		t.Fatalf("missing index.theme in %s", target)
	}
	os.RemoveAll(target)
}

func TestInstallBuriedTheme(t *testing.T) {
	tmp := isolateHome(t)
	zp := filepath.Join(tmp, "theme.zip")
	mkzip(t, zp, map[string]string{
		"README.md": "x", "__MACOSX/._x": "x",
		"CoolTheme/index.theme": "x", "CoolTheme/16x16/a.png": "x",
	})
	target, err := Install("icon-theme", zp, "CoolTheme-store-test")
	if err != nil {
		t.Fatalf("install: %v", err)
	}
	if _, err := os.Stat(filepath.Join(target, "index.theme")); err != nil {
		t.Fatalf("missing index.theme in %s", target)
	}
	if _, err := os.Stat(filepath.Join(target, "16x16", "a.png")); err != nil {
		t.Fatalf("theme files not rooted at %s", target)
	}
	os.RemoveAll(target)
}

func TestInstallPlugin(t *testing.T) {
	tmp := isolateHome(t)
	zp := filepath.Join(tmp, "coolclock.zip")
	mkzip(t, zp, map[string]string{
		"coolclock/manifest.json": `{"name":"coolclock","pluginGroup":"sidebar"}`,
		"coolclock/main.qml":      "import QtQuick\nItem {}",
	})
	target, err := Install("noon-plugin", zp, "sidebar/coolclock")
	if err != nil {
		t.Fatalf("install plugin: %v", err)
	}
	want := filepath.Join(tmp, ".noon_plugins", "sidebar", "coolclock", "manifest.json")
	if _, err := os.Stat(want); err != nil {
		t.Fatalf("missing %s (got %s)", want, target)
	}
	if _, err := Install("noon-plugin", zp, "bogus"); err == nil {
		t.Fatalf("bad group accepted")
	}
	os.RemoveAll(target)
}
