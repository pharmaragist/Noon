import hashlib
import json
import os
import random
import urllib.request
from concurrent.futures import ThreadPoolExecutor

CACHE_DIR = os.path.expanduser("~/.cache/noon/user/generated/beats/hitsCovers")
CPU_COUNT = os.cpu_count() or 8

_yt = None


def _client():
    global _yt
    if _yt is None:
        from ytmusicapi import YTMusic

        _yt = YTMusic()
    return _yt


def thumb_cache_path(url: str) -> str:
    return os.path.join(CACHE_DIR, hashlib.md5(url.encode()).hexdigest() + ".jpg")


def fetch_thumbnail(key: str, thumb_url: str):
    if not key or not thumb_url:
        return
    path = thumb_cache_path(key)
    if os.path.exists(path):
        return
    os.makedirs(CACHE_DIR, exist_ok=True)
    try:
        req = urllib.request.Request(thumb_url, headers={"User-Agent": "Mozilla/5.0"})
        with urllib.request.urlopen(req, timeout=10) as resp, open(path, "wb") as f:
            f.write(resp.read())
    except Exception:
        pass


def fetch_thumbnails_async(items):
    with ThreadPoolExecutor(max_workers=CPU_COUNT) as pool:
        for item in items:
            t_url = item.pop("_thumb_url", "")
            pool.submit(fetch_thumbnail, item.get("url") or item.get("videoId", ""), t_url)


def extract_thumb(item):
    vid = item.get("videoId")
    if vid:
        return f"https://i.ytimg.com/vi/{vid}/mqdefault.jpg"
    ts = item.get("thumbnails")
    if isinstance(ts, list) and ts:
        return ts[0].get("url", "")
    return ""


def build_track(item, via):
    vid = item.get("videoId")
    url = f"https://music.youtube.com/watch?v={vid}" if vid else ""
    arts = item.get("artists") or []
    return {
        "title": item.get("title", "Unknown"),
        "artist": arts[0].get("name", "Unknown") if arts else "Unknown",
        "videoId": vid,
        "url": url,
        "thumbnail": thumb_cache_path(url) if url else "",
        "isPlaylist": False,
        "tracks": [],
        "via": via,
        "views": item.get("views"),
        "duration": item.get("duration"),
        "year": item.get("year"),
        "isExplicit": item.get("isExplicit"),
        "album": item.get("album", {}).get("name") if item.get("album") else None,
        "_thumb_url": extract_thumb(item),
    }


def build_playlist(item, via):
    pid = item.get("playlistId") or item.get("browseId", "")
    url = f"https://music.youtube.com/playlist?list={pid}" if pid else ""
    return {
        "title": item.get("title", "Unknown"),
        "artist": "Various",
        "url": url,
        "thumbnail": thumb_cache_path(url) if url else "",
        "isPlaylist": True,
        "tracks": [],
        "via": via,
        "_thumb_url": extract_thumb(item),
    }


def search(query: str, limit: int) -> list:
    yt = _client()
    res = yt.search(query, filter="songs", limit=limit) or []
    tracks = [build_track(i, "search") for i in res[:limit]]
    fetch_thumbnails_async(tracks)
    return tracks


def _usable(path: str) -> list:
    try:
        with open(path) as f:
            data = json.load(f)
    except (OSError, json.JSONDecodeError):
        return []
    items = data.get("queue", []) if isinstance(data, dict) else data
    return [s for s in items if isinstance(s, dict) and (s.get("artist") or s.get("title"))]


def recommend(music_dir: str, limit: int) -> list:
    pool = {}
    for name in (".beats/library.json", ".beats/queue.json"):
        for s in _usable(os.path.join(music_dir, name)):
            key = ((s.get("artist") or "").lower(), (s.get("title") or "").lower())
            pool.setdefault(key, s)
    usable = list(pool.values())
    if not usable:
        return []
    yt = _client()
    raw = random.sample(usable, min(len(usable), 5))
    seen = set()
    recs = []
    for s in raw:
        res = yt.search(f"{s.get('artist', '')} {s.get('title', '')}", filter="songs")
        if res:
            try:
                seed_vid = res[0]["videoId"]
                seen.add(seed_vid)
                wp = yt.get_watch_playlist(videoId=seed_vid, limit=limit)
                for t in wp["tracks"]:
                    vid = t.get("videoId")
                    if vid and vid not in seen:
                        seen.add(vid)
                        recs.append(build_track(t, "recommend"))
            except Exception:
                continue
    random.shuffle(recs)
    final = recs[:limit]
    fetch_thumbnails_async(final)
    return final


def discover(limit: int) -> list:
    yt = _client()
    home = yt.get_home(limit=10)
    items = []
    for shelf in home:
        for i in shelf.get("contents", []):
            if "videoId" in i:
                items.append(build_track(i, shelf.get("title")))
            elif "playlistId" in i:
                items.append(build_playlist(i, shelf.get("title")))
    random.shuffle(items)
    final = items[:limit]
    fetch_thumbnails_async(final)
    return final


if __name__ == "__main__":
    import argparse

    p = argparse.ArgumentParser(description="YT Music hits fetcher")
    sub = p.add_subparsers(dest="command", required=True)

    s = sub.add_parser("search")
    s.add_argument("--query", required=True)
    s.add_argument("--limit", type=int, default=18)

    r = sub.add_parser("recommend")
    r.add_argument("--music-dir", required=True)
    r.add_argument("--limit", type=int, default=18)

    d = sub.add_parser("discover")
    d.add_argument("--limit", type=int, default=18)

    a = p.parse_args()
    if a.command == "search":
        out = search(a.query, a.limit)
    elif a.command == "recommend":
        out = recommend(a.music_dir, a.limit)
    else:
        out = discover(a.limit)
    print(json.dumps(out, ensure_ascii=False))
