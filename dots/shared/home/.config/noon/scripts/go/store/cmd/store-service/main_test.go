package main

import (
	"sync/atomic"
	"testing"
	"time"

	"store-service/internal/ocs"
)

// ponytail: the one check that fails if Install Queue ordering breaks.
func TestInstallQueueOrder(t *testing.T) {
	q := newInstallQueue()
	if pos := q.acquire(); pos != 1 {
		t.Fatalf("first pos = %d, want 1", pos)
	}
	secondPos := make(chan int64, 1)
	done := make(chan struct{})
	go func() {
		p := q.acquire()
		secondPos <- p
		q.release()
		close(done)
	}()
	deadline := time.Now().Add(2 * time.Second)
	for atomic.LoadInt64(&q.waiting) != 1 {
		if time.Now().After(deadline) {
			q.release()
			t.Fatalf("second acquire never queued")
		}
		time.Sleep(time.Millisecond)
	}
	q.release()
	select {
	case p := <-secondPos:
		if p != 2 {
			t.Fatalf("second pos = %d, want 2", p)
		}
	case <-time.After(2 * time.Second):
		t.Fatalf("second acquire never returned")
	}
	<-done
}

// ponytail: fails if the installer goes back to unpacking the first file
// (often SHA256SUMS.txt) instead of the real archive.
func TestPickFilePrefersArchive(t *testing.T) {
	c := ocs.Content{Files: []ocs.Download{
		{Link: "https://x/SHA256SUMS.txt", Name: "SHA256SUMS.txt"},
		{Link: "https://x/Theme.tar.xz", Name: "Theme.tar.xz"},
	}}
	dl, msg := pickFile(c, nil)
	if msg != "" || dl.Name != "Theme.tar.xz" {
		t.Fatalf("pick = %+v %q", dl, msg)
	}
	zero := 0
	dl, msg = pickFile(c, &zero)
	if msg != "" || dl.Name != "SHA256SUMS.txt" {
		t.Fatalf("explicit pick = %+v %q", dl, msg)
	}
	plain := ocs.Content{Files: []ocs.Download{{Link: "https://x/README", Name: "README"}}}
	dl, msg = pickFile(plain, nil)
	if msg != "" || dl.Name != "README" {
		t.Fatalf("fallback pick = %+v %q", dl, msg)
	}
	if _, msg := pickFile(ocs.Content{}, nil); msg == "" {
		t.Fatalf("empty files accepted")
	}
}
