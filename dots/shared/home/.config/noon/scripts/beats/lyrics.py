import argparse
import json
import os
import re
import sys
from urllib.parse import quote
from urllib.request import Request, urlopen

LRCLIB = "https://lrclib.net/api/search"
UA = "beats-lyrics/1.0"

SEP = r"\s*(?:[–—－−_|/•·]|\s+-+\s+)\s*"


def clean_title(s, artist=""):
    s = re.sub(r"\s*[\(\[].*?[\)\]]\s*", " ", s)
    s = re.sub(
        r"\s*-\s*(Official|Lyric|Audio|Video|Music\s*Video|Visualizer|Remaster(?:ed)?)\s*$",
        "",
        s,
        flags=re.I,
    )
    s = re.sub(r"\s+", " ", s).strip().lower()

    if artist:
        a = re.escape(artist)
        s = re.sub(SEP + a + "$", "", s, flags=re.I)
        s = re.sub("^" + a + SEP, "", s, flags=re.I)
        s = s.strip()

    return s


def clean_artist(s):
    s = re.sub(r"\s+(?:feat\.|featuring|ft\.|with|x|&)\s+.*", "", s, flags=re.I)
    s = re.sub(r"\s*[\(\[].*?[\)\]]\s*", " ", s)
    return re.sub(r"\s+", " ", s).strip().lower()


def _lrc_path(music_dir: str, rel: str) -> str:
    stem = os.path.splitext(rel)[0]
    return os.path.join(music_dir, ".beats", "lyrics", stem + ".lrc")


def get_lyrics(title: str, artist: str = "", music_dir: str = "", rel: str = "", cached_only: bool = False, duration: float = 0.0) -> str:
    title, artist = title.strip(), artist.strip()
    if not title or not rel:
        return ""

    lrc_path = _lrc_path(music_dir, rel)

    if os.path.isfile(lrc_path):
        try:
            with open(lrc_path, encoding="utf-8") as f:
                return f.read()
        except OSError:
            pass

    if cached_only:
        return ""

    try:
        # LRCLib's structured search fails on non-latin scripts; use plain q= there
        segs = []
        for s in re.split(r"[|｜/]| - ", title):
            s = s.strip()
            if len(s) >= 4 and s not in segs:
                segs.append(s)
        if len(segs) > 1:
            attempts = [f"{LRCLIB}?q={quote(s)}" for s in segs[:4]]
        elif all(ord(ch) < 0x600 for ch in title):
            attempts = [
                f"{LRCLIB}?track_name={quote(clean_title(title, clean_artist(artist)))}&artist_name={quote(clean_artist(artist))}",
                f"{LRCLIB}?q={quote(title + ' ' + artist)}",
            ]
        else:
            attempts = [f"{LRCLIB}?q={quote(title + ' ' + artist)}"]

        def duration_ok(d):
            try:
                return not duration or not d.get("duration") or abs(float(d["duration"]) - duration) <= 3
            except (TypeError, ValueError):
                return True

        # a result must share at least one significant word with the query,
        # otherwise segment queries like a bare artist name match random songs
        tokens = [
            w.lower() for w in re.findall(r"[\w\u0600-\u06FF]+", title + " " + artist)
            if len(w) >= (3 if any(ord(c) >= 0x600 for c in w) else 4)
        ]

        def name_ok(d):
            if not tokens:
                return True
            hay = ((d.get("trackName") or "") + " " + (d.get("artistName") or "")).lower()
            return any(t in hay for t in tokens)

        synced = plain = ""
        for url in attempts:
            with urlopen(Request(url, headers={"User-Agent": UA}), timeout=10) as r:
                data = json.loads(r.read().decode())
            if not isinstance(data, list):
                continue
            for d in data:
                if not duration_ok(d) or not name_ok(d):
                    continue
                if not synced and d.get("syncedLyrics"):
                    synced = d["syncedLyrics"]
                if not plain and d.get("plainLyrics"):
                    plain = d["plainLyrics"]
            if synced:
                break
        if synced:
            os.makedirs(os.path.dirname(lrc_path), exist_ok=True)
            with open(lrc_path, "w", encoding="utf-8") as f:
                f.write(synced)
        return synced or plain
    except Exception:
        return ""


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--title", required=True)
    p.add_argument("--artist", default="")
    p.add_argument("--music-dir", required=True)
    p.add_argument("--file", default="")
    p.add_argument("--cached-only", action="store_true")
    a = p.parse_args()
    print(json.dumps({"text": get_lyrics(a.title, a.artist, a.music_dir, a.file, a.cached_only)}))


def strip_timestamps(text: str) -> str:
    return re.sub(r"\[\d+:\d+(?:\.\d+)?\]\s*", "", text).strip()


def embed_track(music_dir: str, rel: str, text: str) -> bool:
    from mutagen import File as MutagenFile
    from mutagen.id3 import ID3, USLT
    from mutagen.mp4 import MP4

    abs_path = os.path.join(music_dir, rel)
    ext = os.path.splitext(abs_path)[1].lower()
    try:
        if ext == ".mp3":
            try:
                tags = ID3(abs_path)
            except Exception:
                tags = ID3()
            existing = tags.getall("USLT")
            if existing and getattr(existing[0], "text", "") == text:
                return False
            tags.setall("USLT", [USLT(encoding=3, lang="eng", desc="", text=text)])
            tags.save(abs_path)
        elif ext == ".m4a":
            from mutagen.mp4 import MP4

            audio = MP4(abs_path)
            if audio.tags and audio.tags.get("\xa9lyr") == [text]:
                return False
            audio["\xa9lyr"] = [text]
            audio.save()
        elif ext in (".flac", ".ogg", ".opus"):
            audio = MutagenFile(abs_path)
            if audio is None:
                return False
            if audio.get("LYRICS") == [text]:
                return False
            audio["LYRICS"] = text
            audio.save()
        else:
            return False
        return True
    except Exception as e:
        print(f"  [EMBED ERR] {rel}: {e}", file=sys.stderr, flush=True)
        return False


def embed_library(music_dir: str) -> int:
    lib_path = os.path.join(music_dir, ".beats", "library.json")
    with open(lib_path, encoding="utf-8") as f:
        tracks = json.load(f)

    done = skipped = 0
    for t in tracks:
        rel = t.get("file", "")
        lrc_path = os.path.join(music_dir, ".beats", "lyrics", os.path.splitext(rel)[0] + ".lrc")
        if not os.path.isfile(lrc_path):
            skipped += 1
            continue
        with open(lrc_path, encoding="utf-8") as f:
            text = strip_timestamps(f.read())
        if not text:
            skipped += 1
            continue
        if embed_track(music_dir, rel, text):
            done += 1
            print(f"  [{done}] {rel}", flush=True)
        else:
            skipped += 1
    return done
