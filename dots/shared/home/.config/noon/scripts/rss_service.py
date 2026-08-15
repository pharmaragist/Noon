#!/usr/bin/env python3
import argparse
import fcntl
import hashlib
import json
import mimetypes
import os
import re
import sys
import urllib.request
from datetime import datetime, timezone
from html.parser import HTMLParser
from urllib.parse import urlparse
import feedparser
LOCK_PATH = "/tmp/rss_service.lock"
DEFAULT_UA = "rss_service/1.0 (+https://example.com/rsscache)"
DEFAULT_IMAGE_DIR = os.path.expanduser("~/.noon/rss_images")
IMAGE_MAX_BYTES = 5 * 1024 * 1024
MAX_CACHED_POSTS_PER_FEED = 200
SAMPLE_RSS = (
    '<?xml version="1.0"?><rss version="2.0"><channel><title>T</title>'
    '<item><title>One</title><link>https://a/1</link>'
    '<pubDate>Mon, 01 Jan 2024 00:00:00 GMT</pubDate></item>'
    '<item><title>Two</title><link>https://a/2</link></item></channel></rss>'
)
SAMPLE_ATOM = (
    '<?xml version="1.0"?><feed xmlns="http://www.w3.org/2005/Atom"><title>A</title>'
    '<entry><title>Hello</title><link href="https://a/1"/>'
    '<updated>2024-01-01T00:00:00Z</updated></entry></feed>'
)
SAMPLE_IMG = (
    '<?xml version="1.0"?><rss version="2.0" '
    'xmlns:media="http://search.yahoo.com/mrss/"><channel><title>T</title>'
    '<item><title>P</title><link>https://a/p</link>'
    '<description>hello <b>world</b> <img src="https://big.example/full.jpg?width=640"/></description>'
    '<media:thumbnail url="https://x/i.png" width="108" height="108"/>'
    '<media:content url="https://preview.example/i.jpg?width=108" width="108" height="108"/></item>'
    '</channel></rss>'
)
REDDIT_SUB_RE = re.compile(r"reddit\.com/r/([A-Za-z0-9_]+)", re.I)
HTML_COMMENT_RE = re.compile(r"<!--.*?-->", re.S)
REDDIT_FOOTER_RE = re.compile(
    r"(&#32;)?\s*submitted by\s*(&#32;)?.*$", re.S | re.I
)
WS_RE = re.compile(r"\s+")
class _TextExtractor(HTMLParser):
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.parts = []
    def handle_data(self, data):
        self.parts.append(data)
    def get_text(self):
        return "".join(self.parts)
def post_content(e):
    c = e.get("content")
    if c and c[0].get("value"):
        return c[0]["value"]
    return e.get("summary") or ""
def clean_content(html):
    text = HTML_COMMENT_RE.sub("", html)
    text = REDDIT_FOOTER_RE.sub("", text)
    extractor = _TextExtractor()
    extractor.feed(text)
    extractor.close()
    text = extractor.get_text()
    text = WS_RE.sub(" ", text).strip()
    return text
def _img_width(url, attrs):
    try:
        w = int(attrs.get("width") or 0)
        if w:
            return w
    except (TypeError, ValueError):
        pass
    m = re.search(r"[?&]width=(\d+)", url)
    return int(m.group(1)) if m else 0
def _upscale(url):
    if "width=" not in url or "s=" in url:
        return url
    return re.sub(r"width=\d+", "width=640", url)
def post_image(e):
    cands = []
    for key in ("media_content", "media_thumbnail"):
        for m in e.get(key) or []:
            u = m.get("url")
            if u:
                cands.append((u, _img_width(u, m)))
    for enc in e.get("enclosures") or []:
        if str(enc.get("type", "")).startswith("image") and enc.get("href"):
            cands.append((enc["href"], _img_width(enc["href"], enc)))
    for m in re.finditer(r"<img[^>]+src=[\"']([^\"']+)[\"']", post_content(e), re.I):
        cands.append((m.group(1), _img_width(m.group(1), {})))
    if not cands:
        return ""
    url, w = max(cands, key=lambda c: c[1])
    return _upscale(url) if w < 640 else url
def post_author(e):
    a = e.get("author")
    if a:
        return a.replace("/u/", "").strip()
    m = re.search(r"/u/([A-Za-z0-9_\-]+)", post_content(e))
    return m.group(1) if m else ""
def image_name(url):
    return hashlib.sha256(url.encode()).hexdigest()[:16]
def cache_image(url, image_dir, ua):
    if not url:
        return ""
    ext = os.path.splitext(urlparse(url).path)[1].lower()
    if not ext or len(ext) > 5:
        ext = ""
    path = os.path.join(image_dir, image_name(url) + (ext or ".jpg"))
    if os.path.exists(path):
        return path
    req = urllib.request.Request(url, headers={"User-Agent": ua})
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            if not ext:
                ctype = mimetypes.guess_extension((r.headers.get("Content-Type") or "").split(";")[0].strip())
                if ctype in (".jpe", ".jpeg"):
                    ctype = ".jpg"
                path = os.path.join(image_dir, image_name(url) + (ctype or ".jpg"))
            data = r.read(IMAGE_MAX_BYTES + 1)
            if len(data) > IMAGE_MAX_BYTES:
                return ""
        if os.path.exists(path):
            return path
        with open(path, "wb") as f:
            f.write(data)
        return path
    except Exception:
        return ""
def now_iso():
    return datetime.now(timezone.utc).astimezone().isoformat()
def parse_ts(s):
    try:
        return datetime.fromisoformat(s).timestamp()
    except (TypeError, ValueError):
        pass
    try:
        from email.utils import parsedate_to_datetime
        return parsedate_to_datetime(s).timestamp()
    except (TypeError, ValueError, IndexError):
        return 0
def feed_label(url, feed_title=""):
    m = REDDIT_SUB_RE.search(url)
    if m:
        return "r/" + m.group(1)
    host = urlparse(url).netloc
    host = re.sub(r"^www\.", "", host)
    return feed_title.strip() or host
def fetch(url, ua, image_dir=""):
    d = feedparser.parse(url, agent=ua)
    status = getattr(d, "status", 200)
    if status and status != 200:
        raise RuntimeError(f"GET {url}: HTTP {status}")
    entries = d.get("entries") or []
    title = d.get("feed", {}).get("title", "")
    if not entries and not title:
        raise RuntimeError(
            f"{url} returned a web page or empty content, not RSS "
            "(reddit: use old.reddit.com/r/<sub>.rss; other sites may need a .rss or /feed/ suffix)"
        )
    posts = [
        {
            "title": e.get("title", ""),
            "link": e.get("link", ""),
            "date": e.get("published") or e.get("updated") or "",
            "author": post_author(e),
            "content": clean_content(post_content(e)),
            "image": cache_image(post_image(e), image_dir, ua) if image_dir else "",
        }
        for e in entries
    ]
    return title, posts
def merge_posts(old_posts, new_posts):
    by_link = {}
    for p in old_posts:
        key = p.get("link") or p.get("title")
        if key:
            by_link[key] = p
    for p in new_posts:
        key = p.get("link") or p.get("title")
        if key:
            by_link[key] = p
    return sorted(by_link.values(), key=lambda p: parse_ts(p.get("date", "")), reverse=True)[:MAX_CACHED_POSTS_PER_FEED]
def lock():
    fh = open(LOCK_PATH, "a+")
    try:
        fcntl.flock(fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except OSError:
        fh.seek(0)
        pid = fh.read().strip()
        if pid.isdigit():
            try:
                os.kill(int(pid), 9)
            except OSError:
                pass
        fcntl.flock(fh, fcntl.LOCK_EX)
    fh.seek(0)
    fh.truncate()
    fh.write(str(os.getpid()))
    fh.flush()
    return fh
def load_doc(path):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {}
    except json.JSONDecodeError as e:
        raise RuntimeError(f"corrupt cache {path}: {e}")
def save_doc(doc, targets, path):
    doc["targets"] = targets
    with open(path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, ensure_ascii=False)
        f.write("\n")
def selftest():
    try:
        r = feedparser.parse(SAMPLE_RSS)
        assert len(r.entries) == 2, "parse rss"
        assert r.entries[0].get("link") == "https://a/1", "rss link"
        a = feedparser.parse(SAMPLE_ATOM)
        assert len(a.entries) == 1, "parse atom"
        assert a.entries[0].get("link") == "https://a/1", "atom link"
        i = feedparser.parse(SAMPLE_IMG)
        assert post_image(i.entries[0]) == "https://big.example/full.jpg?width=640", "largest image"
        assert _upscale("https://p.example/i.jpg?width=108") == "https://p.example/i.jpg?width=640", "upscale"
        assert _upscale("https://p.example/i.jpg?width=108&s=abc") == "https://p.example/i.jpg?width=108&s=abc", "no upscale signed"
        assert _img_width("https://p.example/i.jpg?width=640", {"width": 108}) == 108, "img width attr"
        assert post_content(i.entries[0]) == 'hello <b>world</b> <img src="https://big.example/full.jpg?width=640" />', "content"
        h = feedparser.parse("<html><body>x</body></html>")
        assert not h.entries and not h.get("feed", {}).get("title"), "html detect"
        assert post_image(h) == "", "html no image"
        assert parse_ts(now_iso()) > 0, "ts parse"
        assert cache_image("", "/tmp", DEFAULT_UA) == "", "empty image"
        assert cache_image("http://127.0.0.1:1/x", "/tmp", DEFAULT_UA) == "", "unreachable image"
        assert feed_label("https://old.reddit.com/r/hyprland.rss") == "r/hyprland", "reddit label"
        assert feed_label("https://www.reddit.com/r/unixporn.rss") == "r/unixporn", "reddit label www"
        assert feed_label("https://example.com/feed", "Example Blog") == "Example Blog", "title label"
        assert feed_label("https://example.com/feed") == "example.com", "domain label"
        dirty = (
            '<!-- SC_OFF --><div class="md"><p>Hello <b>world</b>!</p></div><!-- SC_ON -->'
            ' &#32; submitted by &#32; <a href="https://x/user/Foo"> /u/Foo </a> <br />'
            ' <span><a href="https://x">[link]</a></span> &#32;'
            ' <span><a href="https://x">[comments]</a></span>'
        )
        assert clean_content(dirty) == "Hello world!", "clean content strips footer/tags/entities"
        assert parse_ts("Mon, 01 Jan 2024 00:00:00 GMT") > 0, "rfc822 date parse"
        old = [{"link": "a", "date": "Mon, 01 Jan 2024 00:00:00 GMT", "title": "old"}]
        new = [
            {"link": "b", "date": "Wed, 03 Jan 2024 00:00:00 GMT", "title": "new"},
            {"link": "a", "date": "Mon, 01 Jan 2024 00:00:00 GMT", "title": "old-refetched"},
        ]
        merged = merge_posts(old, new)
        assert [p["link"] for p in merged] == ["b", "a"], "merge sorts newest first"
        assert merged[1]["title"] == "old-refetched", "merge dedups by link, new wins"
        many_old = [{"link": str(i), "date": "Mon, 01 Jan 2024 00:00:00 GMT", "title": str(i)} for i in range(MAX_CACHED_POSTS_PER_FEED)]
        capped = merge_posts(many_old, [{"link": "newest", "date": "Wed, 03 Jan 2024 00:00:00 GMT", "title": "newest"}])
        assert len(capped) == MAX_CACHED_POSTS_PER_FEED, "merge caps to MAX_CACHED_POSTS_PER_FEED"
        assert capped[0]["link"] == "newest", "merge keeps newest when capping"
        print("selftest OK")
        return 0
    except AssertionError as e:
        print("selftest FAIL:", e)
        return 1
def main():
    p = argparse.ArgumentParser(description="RSS service: fetch and cache feeds into a JSON file")
    p.add_argument("--urls", default=os.environ.get("RSSCACHE_URLS", ""))
    p.add_argument("--ttl", type=int, default=900)
    p.add_argument("--refresh-all", action="store_true")
    p.add_argument("--load-more", action="store_true")
    p.add_argument("--file", default=os.environ.get("RSSCACHE_FILE", "rss-cache.json"))
    p.add_argument("--image-cache-path", default=os.environ.get("RSSCACHE_IMAGES", DEFAULT_IMAGE_DIR))
    p.add_argument("--ua", default=DEFAULT_UA)
    p.add_argument("--selftest", action="store_true")
    args = p.parse_args()
    if args.selftest:
        return selftest()
    urls = [u.strip() for u in args.urls.split(",") if u.strip()]
    if not urls:
        print(json.dumps({"error": "Usage: rss_service --urls u1,u2 [--ttl 900] [--refresh-all] [--file path] [--image-cache-path dir]"}))
        return 1
    image_dir = args.image_cache_path
    if urls:
        os.makedirs(image_dir, exist_ok=True)
    fh = lock()
    try:
        doc = load_doc(args.file)
        by_from = {t["from"]: t for t in doc.get("targets", []) if t.get("from")}
        out = []
        for u in urls:
            t = by_from.get(u)
            fresh = (
                t
                and not args.refresh_all
                and not args.load_more
                and time_now() - parse_ts(t.get("fetched_at")) < args.ttl
            )
            if fresh:
                t.setdefault("label", feed_label(u))
                out.append(t)
                continue
            try:
                title, posts = fetch(u, args.ua, image_dir)
                if args.load_more and t:
                    posts = merge_posts(t.get("feed", []), posts)
                t = {
                    "from": u,
                    "fetched_at": now_iso(),
                    "feed": posts,
                    "label": feed_label(u, title),
                }
                by_from[u] = t
            except RuntimeError as e:
                if t:
                    t.setdefault("label", feed_label(u))
                    out.append(t)
                else:
                    out.append({
                        "from": u,
                        "error": str(e),
                        "label": feed_label(u),
                    })
                continue
            out.append(t)
        save_doc(doc, list(by_from.values()), args.file)
        print(json.dumps({"targets": out}, ensure_ascii=False))
        return 0
    finally:
        fh.close()
def time_now():
    return datetime.now(timezone.utc).timestamp()
if __name__ == "__main__":
    try:
        sys.exit(main())
    except SystemExit:
        raise
    except Exception as e:
        print(json.dumps({"error": str(e)}))
