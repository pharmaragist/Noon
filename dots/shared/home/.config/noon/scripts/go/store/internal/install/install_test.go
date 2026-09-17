package install

import (
	"archive/zip"
	"os"
	"os/exec"
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

// ponytail: the checks that fail if compressed-tar support regresses.
// Fixtures are crafted with system tar (skipped when absent) so the test
// exercises the real unpack path, not a hand-built byte stream.
func TestInstallTarXz(t *testing.T) {
	if _, err := exec.LookPath("tar"); err != nil {
		t.Skip("tar missing")
	}
	if _, err := exec.LookPath("xz"); err != nil {
		t.Skip("xz missing")
	}
	tmp := isolateHome(t)
	root := filepath.Join(tmp, "src", "CoolXz")
	os.MkdirAll(root, 0755)
	os.WriteFile(filepath.Join(root, "index.theme"), []byte("[Icon Theme]\nName=CoolXz\n"), 0644)
	zp := filepath.Join(tmp, "theme.tar.xz")
	if out, err := exec.Command("tar", "-cJf", zp, "-C", filepath.Join(tmp, "src"), "CoolXz").CombinedOutput(); err != nil {
		t.Fatalf("tar: %v %s", err, out)
	}
	target, err := Install("icon-theme", zp, "CoolXz-store-test")
	if err != nil {
		t.Fatalf("install tar.xz: %v", err)
	}
	if _, err := os.Stat(filepath.Join(target, "index.theme")); err != nil {
		t.Fatalf("missing index.theme in %s", target)
	}
	os.RemoveAll(target)
}

func TestInstallTarBz2(t *testing.T) {
	if _, err := exec.LookPath("tar"); err != nil {
		t.Skip("tar missing")
	}
	tmp := isolateHome(t)
	root := filepath.Join(tmp, "src", "CoolBz")
	os.MkdirAll(root, 0755)
	os.WriteFile(filepath.Join(root, "index.theme"), []byte("[Icon Theme]\nName=CoolBz\n"), 0644)
	zp := filepath.Join(tmp, "theme.tar.bz2")
	if out, err := exec.Command("tar", "-cjf", zp, "-C", filepath.Join(tmp, "src"), "CoolBz").CombinedOutput(); err != nil {
		t.Fatalf("tar: %v %s", err, out)
	}
	target, err := Install("icon-theme", zp, "CoolBz-store-test")
	if err != nil {
		t.Fatalf("install tar.bz2: %v", err)
	}
	if _, err := os.Stat(filepath.Join(target, "index.theme")); err != nil {
		t.Fatalf("missing index.theme in %s", target)
	}
	os.RemoveAll(target)
}

// ponytail: pins the Kind truth QML renders from; fails if a group is
// added in one place but not the other.
func TestPluginGroupsContract(t *testing.T) {
	groups := PluginGroups()
	want := map[string]bool{"sidebar": true, "dock": true, "beam": true, "palettes": true, "widgets": true}
	if len(groups) != len(want) {
		t.Fatalf("groups = %v", groups)
	}
	for _, g := range groups {
		if !want[g] {
			t.Fatalf("unexpected group %q", g)
		}
	}
}
