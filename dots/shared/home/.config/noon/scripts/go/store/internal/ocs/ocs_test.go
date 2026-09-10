package ocs

import (
	"os"
	"path/filepath"
	"testing"

	"store-service/internal/install"
)

// ponytail: the one check that fails if ocs/static logic breaks.

func TestFoldAndDecode(t *testing.T) {
	body := []byte(`<ocs><meta><status>ok</status><statuscode>100</statuscode>` +
		`<totalitems>1</totalitems><itemsperpage>10</itemsperpage></meta><data><content>` +
		`<id>1</id><name>T</name><previewpic2>http://x/b.png</previewpic2>` +
		`<previewpic1>http://x/a.png</previewpic1>` +
		`<downloadlink2>http://x/2.zip</downloadlink2><downloadname2>b.zip</downloadname2>` +
		`<downloadlink1>http://x/1.zip</downloadlink1><downloadname1>a.zip</downloadname1>` +
		`</content></data></ocs>`)
	_, _, raws, err := decodeContents(body)
	if err != nil || len(raws) != 1 {
		t.Fatalf("decode: %v %d", err, len(raws))
	}
	c := fold(raws[0])
	if len(c.Previews) != 2 || c.Previews[0] != "http://x/a.png" {
		t.Fatalf("preview order: %v", c.Previews)
	}
	if len(c.Files) != 2 || c.Files[0].Name != "a.zip" || c.Files[1].Name != "b.zip" {
		t.Fatalf("downloads: %+v", c.Files)
	}
}

func TestPickPreview(t *testing.T) {
	pvs := []string{
		"https://images.pling.com/cache/770x540-4/img/x/logo1.png",
		"https://images.pling.com/img/x/thumbnail1.gif",
		"https://images.pling.com/img/x/preview-1080p1.gif",
	}
	if got := PickPreview(pvs, ""); got != pvs[0] {
		t.Fatalf("default = %s", got)
	}
	if got := PickPreview(pvs, "small"); got != pvs[1] {
		t.Fatalf("small = %s", got)
	}
	if got := PickPreview(nil, "small"); got != "" {
		t.Fatalf("empty = %s", got)
	}
}

func TestStaticHub(t *testing.T) {
	tmp := t.TempDir()
	os.Setenv("HOME", tmp)
	t.Cleanup(func() { os.Unsetenv("HOME") })
	os.WriteFile(filepath.Join(tmp, "index.json"), []byte(`{"id":"demo","name":"Demo Hub","plugins":[{`+
		`"id":"coolclock","name":"Cool Clock","group":"sidebar",`+
		`"description":"A demo clock widget for testing","version":"0.1","maintainer":"test",`+
		`"preview":"http://x/shot.png","download":"http://x/coolclock.zip"}]}`), 0644)
	os.WriteFile(filepath.Join(tmp, "provs.json"), []byte(`{"static":[{"id":"demo-hub",`+
		`"name":"Demo Hub","index":"file://`+tmp+`/index.json"}]}`), 0644)
	old, had := os.LookupEnv("STORE_PROVIDERS_FILE")
	os.Setenv("STORE_PROVIDERS_FILE", filepath.Join(tmp, "provs.json"))
	t.Cleanup(func() {
		if had {
			os.Setenv("STORE_PROVIDERS_FILE", old)
		} else {
			os.Unsetenv("STORE_PROVIDERS_FILE")
		}
	})

	cats, err := Categories("demo-hub")
	if err != nil || len(cats) != 1 || cats[0].Id != "sidebar" {
		t.Fatalf("cats: %+v %v", cats, err)
	}
	items, more, err := Search("demo-hub", nil, "", "clock", "", 0, 30)
	if err != nil || len(items) != 1 || items[0].Name != "Cool Clock" || more {
		t.Fatalf("search: %+v %v %v", items, more, err)
	}
	items, _, _ = Search("demo-hub", []string{"dock"}, "", "", "", 0, 30)
	if len(items) != 0 {
		t.Fatalf("group filter leaked: %+v", items)
	}
	c, err := GetContent("demo-hub", "coolclock")
	if err != nil || c.Name != "Cool Clock" || len(c.Files) != 1 {
		t.Fatalf("get: %+v %v", c, err)
	}
	if !install.ValidKind("noon-plugin") || install.ValidKind("bogus") {
		t.Fatalf("kind validation broken")
	}
}
