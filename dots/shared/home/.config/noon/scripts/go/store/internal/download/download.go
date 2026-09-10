package download

import (
	"context"
	"fmt"
	"io"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"time"
)

const userAgent = "store-service/1.0"

const MaxBytes = 500 * 1024 * 1024

var client = &http.Client{CheckRedirect: func(req *http.Request, via []*http.Request) error {
	if len(via) >= 10 {
		return fmt.Errorf("too many redirects")
	}
	return nil
}}

type ProgressFunc func(received, total int64, phase string)

func CacheDir() string {
	if d := os.Getenv("XDG_CACHE_HOME"); d != "" {
		return filepath.Join(d, "store-service")
	}
	home, _ := os.UserHomeDir()
	return filepath.Join(home, ".cache", "store-service")
}

func FileType(name, urlStr string) string {
	lower := strings.ToLower(name)
	if lower == "" {
		lower = strings.ToLower(urlStr)
	}
	switch {
	case strings.HasSuffix(lower, ".tar.gz"), strings.HasSuffix(lower, ".tgz"):
		return "tar.gz"
	case strings.HasSuffix(lower, ".tar.xz"), strings.HasSuffix(lower, ".txz"):
		return "tar.xz"
	case strings.HasSuffix(lower, ".tar.bz2"), strings.HasSuffix(lower, ".tbz2"):
		return "tar.bz2"
	case strings.HasSuffix(lower, ".zip"):
		return "zip"
	case strings.HasSuffix(lower, ".7z"):
		return "7z"
	case strings.HasSuffix(lower, ".tar"):
		return "tar"
	case strings.HasSuffix(lower, ".png"), strings.HasSuffix(lower, ".jpg"), strings.HasSuffix(lower, ".jpeg"):
		return "image"
	default:
		return "file"
	}
}

func Download(ctx context.Context, srcURL, destPath string, progress ProgressFunc) (string, string, error) {
	if err := os.MkdirAll(filepath.Dir(destPath), 0755); err != nil {
		return "", "", err
	}
	var resp *http.Response
	var err error
	for attempt := 0; attempt < 4; attempt++ {
		var req *http.Request
		req, err = http.NewRequestWithContext(ctx, "GET", srcURL, nil)
		if err != nil {
			return "", "", err
		}
		req.Header.Set("User-Agent", userAgent)
		resp, err = client.Do(req)
		if err != nil {
			return "", "", fmt.Errorf("ocs_unreachable: %w", err)
		}
		if resp.StatusCode == 429 || resp.StatusCode == 503 {
			delay := time.Duration(1<<attempt) * time.Second
			if ra := resp.Header.Get("Retry-After"); ra != "" {
				if sec, err2 := strconv.Atoi(ra); err2 == nil && sec < 10 {
					delay = time.Duration(sec) * time.Second
				}
			}
			io.Copy(io.Discard, resp.Body)
			resp.Body.Close()
			select {
			case <-ctx.Done():
				return "", "", ctx.Err()
			case <-time.After(delay):
			}
			continue
		}
		break
	}
	if err != nil {
		return "", "", fmt.Errorf("ocs_unreachable: %w", err)
	}
	defer resp.Body.Close()
	if resp.StatusCode < 200 || resp.StatusCode >= 300 {
		return "", "", fmt.Errorf("download failed status %d", resp.StatusCode)
	}
	total := int64(-1)
	if cl := resp.Header.Get("Content-Length"); cl != "" {
		total, _ = strconv.ParseInt(cl, 10, 64)
	}
	if total > MaxBytes {
		return "", "", fmt.Errorf("file too large %d", total)
	}
	tmp := destPath + ".part"
	out, err := os.Create(tmp)
	if err != nil {
		return "", "", err
	}
	defer func() {
		out.Close()
		if err != nil {
			os.Remove(tmp)
		}
	}()
	var received int64
	buf := make([]byte, 32*1024)
	lastEmit := time.Now()
	emit := func(phase string) {
		if progress != nil {
			progress(received, total, phase)
		}
	}
	for {
		select {
		case <-ctx.Done():
			out.Close()
			os.Remove(tmp)
			return "", "", ctx.Err()
		default:
		}
		n, readErr := resp.Body.Read(buf)
		if n > 0 {
			received += int64(n)
			if received > MaxBytes {
				out.Close()
				os.Remove(tmp)
				return "", "", fmt.Errorf("file too large during stream")
			}
			if _, werr := out.Write(buf[:n]); werr != nil {
				err = werr
				return "", "", err
			}
			if time.Since(lastEmit) > 100*time.Millisecond || received == total {
				emit("downloading")
				lastEmit = time.Now()
			}
		}
		if readErr != nil {
			if readErr == io.EOF {
				break
			}
			err = readErr
			return "", "", err
		}
	}
	out.Close()
	if err := os.Rename(tmp, destPath); err != nil {
		os.Remove(tmp)
		return "", "", err
	}
	emit("done")
	ftype := FileType(destPath, srcURL)
	return destPath, ftype, nil
}
