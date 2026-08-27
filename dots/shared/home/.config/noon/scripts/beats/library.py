import base64
import hashlib
import json
import math
import os
import shutil
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed

from mutagen import File

from .config import conf_require

WORKERS = os.cpu_count() or 4
AUDIO_EXTS = {".mp3", ".flac", ".ogg", ".opus", ".m4a", ".aac", ".wav", ".wma", ".mp4"}


def _atomic_json(path: str, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(tmp, path)


def _process_chunk(args: tuple) -> list:
    chunk, music_dir, covers_dir = args

    from mutagen.flac import Picture
    from mutagen.id3 import APIC, ID3
    from mutagen.mp4 import MP4Cover

    local_dedup = {}
    results = []

    for rel_path in chunk:
        abs_path = os.path.join(music_dir, rel_path)
        if not os.path.exists(abs_path):
            continue

        ext = os.path.splitext(abs_path)[1].lower()
        file_key = hashlib.md5(rel_path.encode()).hexdigest()[:12]
        data, img_ext = None, "jpg"

        try:
            audio = File(abs_path, easy=False)
            if audio is None:
                continue

            if ext == ".mp3":
                tags = ID3(abs_path)
                for tag in tags.values():
                    if isinstance(tag, APIC):
                        data = tag.data
                        img_ext = "png" if tag.mime == "image/png" else "jpg"
                        break
            elif ext == ".m4a":
                if audio.tags:
                    covers = audio.tags.get("covr", [])
                    if covers:
                        data = bytes(covers[0])
                        img_ext = "png" if covers[0].imageformat == MP4Cover.FORMAT_PNG else "jpg"
            elif ext == ".flac":
                if audio.pictures:
                    pic = audio.pictures[0]
                    data = pic.data
                    img_ext = "png" if pic.mime == "image/png" else "jpg"
            elif ext in (".ogg", ".opus"):
                if audio.get("metadata_block_picture"):
                    raw = base64.b64decode(audio["metadata_block_picture"][0])
                    pic = Picture(raw)
                    data = pic.data
                    img_ext = "png" if pic.mime == "image/png" else "jpg"
        except Exception as e:
            print(f"  [COVER ERR] {rel_path}: {e}", file=sys.stderr, flush=True)
            continue

        if not data:
            continue

        out_name = f"{file_key}.{img_ext}"
        out_path = os.path.join(covers_dir, out_name)

        if not os.path.exists(out_path):
            img_hash = hashlib.md5(data).hexdigest()[:16]
            if img_hash in local_dedup:
                try:
                    os.link(local_dedup[img_hash], out_path)
                except OSError:
                    shutil.copy2(local_dedup[img_hash], out_path)
            else:
                with open(out_path, "wb") as f:
                    f.write(data)
                local_dedup[img_hash] = out_path

        rel_cover = os.path.relpath(out_path, music_dir)
        results.append((rel_path, rel_cover))

    return results


def _make_chunks(items: list, n: int) -> list:
    size = math.ceil(len(items) / n) if items else 1
    return [items[i:i + size] for i in range(0, len(items), size)]


def _iso_mtime(st_mtime: float) -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(st_mtime))


def _scan_mtimes(music_dir: str) -> dict:
    mtimes = {}
    for root, dirs, files in os.walk(music_dir):
        dirs[:] = [d for d in dirs if d != ".beats"]
        for f in files:
            if os.path.splitext(f)[1].lower() not in AUDIO_EXTS:
                continue
            abs_path = os.path.join(root, f)
            rel = os.path.relpath(abs_path, music_dir)
            try:
                mtimes[rel] = _iso_mtime(os.stat(abs_path).st_mtime)
            except OSError:
                continue
    return mtimes


def _read_tags(music_dir: str, rel: str) -> dict | None:
    abs_path = os.path.join(music_dir, rel)
    audio = None
    for easy in (True, False):
        try:
            audio = File(abs_path, easy=easy) or None
        except Exception:
            audio = None
        if audio is not None:
            break
    if audio is None:
        return None

    def first(*keys):
        for key in keys:
            try:
                v = audio.get(key)
            except Exception:
                continue
            if isinstance(v, (list, tuple)):
                v = v[0] if v else None
            if v is not None and str(v).strip():
                return str(v).strip()
        return ""

    track = first("tracknumber", "track")
    if "/" in track:
        track = track.split("/")[0]
    try:
        duration = float(audio.info.length)
    except Exception:
        duration = 0.0
    return {
        "file": rel,
        "title": first("title") or os.path.splitext(os.path.basename(rel))[0],
        "artist": first("artist"),
        "album": first("album"),
        "genre": first("genre"),
        "date": first("date", "year", "originaldate", "origyear"),
        "track": track,
        "duration": duration,
    }


class LibraryManager:
    def __init__(self, music_dir: str | None = None):
        if music_dir is None:
            music_dir = conf_require("directory")["directory"]
        self.music_dir = os.path.expanduser(music_dir)
        self.covers_dir = os.path.join(self.music_dir, ".beats", "coverarts")
        self.library_path = os.path.join(self.music_dir, ".beats", "library.json")

    def _read_library(self) -> list | None:
        try:
            with open(self.library_path) as f:
                return json.load(f)
        except (OSError, json.JSONDecodeError):
            return None

    def _cover_ok(self, rel_cover: str) -> bool:
        if not rel_cover:
            return False
        full = os.path.join(self.music_dir, rel_cover)
        # require a non-empty file — a 0-byte or corrupt cover from a crashed
        # run would otherwise be treated as cached forever (flaky covers)
        return os.path.isfile(full) and os.path.getsize(full) > 0

    def build_covers(self):
        tracks = self.get_library()
        pending = [t["file"] for t in tracks if not self._cover_ok(t.get("cover"))]
        print(f"  Total:   {len(tracks)}")
        print(f"  Cached:  {len(tracks) - len(pending)}")
        print(f"  Pending: {len(pending)}")
        print(f"  Workers: {WORKERS}\n")

        if not pending:
            print("  Nothing to do.")
            return

        os.makedirs(self.covers_dir, exist_ok=True)
        by_file = {t["file"]: t for t in tracks}
        chunks = _make_chunks(pending, WORKERS)
        chunk_args = [(chunk, self.music_dir, self.covers_dir) for chunk in chunks]

        done = 0
        with ProcessPoolExecutor(max_workers=WORKERS) as pool:
            futures = {pool.submit(_process_chunk, arg): i for i, arg in enumerate(chunk_args)}
            for future in as_completed(futures):
                try:
                    for rel_path, rel_cover in future.result():
                        by_file[rel_path]["cover"] = rel_cover
                        done += 1
                        print(f"  [{done}/{len(pending)}] {rel_path}", flush=True)
                except Exception as e:
                    print(f"  [CHUNK ERR] {e}", file=sys.stderr)

        if done:
            _atomic_json(self.library_path, tracks)
        print(f"\nDone. {done} new covers extracted.")

    def _cache_valid(self, mtimes: dict) -> list | None:
        tracks = self._read_library()
        if tracks is None:
            return None
        if len(tracks) != len(mtimes):
            return None
        for t in tracks:
            if mtimes.get(t.get("file")) != t.get("last_modified"):
                return None
        return tracks

    def get_library(self) -> list:
        mtimes = _scan_mtimes(self.music_dir)
        rebuilt = False
        tracks = self._cache_valid(mtimes)
        if tracks is None:
            rebuilt = True
            tracks = []
            for rel in sorted(mtimes):
                track = _read_tags(self.music_dir, rel)
                if track is None:
                    continue
                track["last_modified"] = mtimes[rel]
                track["cover"] = ""
                tracks.append(track)
        tracks.sort(key=lambda t: t["last_modified"], reverse=True)
        if rebuilt:
            _atomic_json(self.library_path, tracks)
        return tracks


_index_cache: dict[str, tuple] = {}


def track_index(music_dir: str) -> dict:
    # cache the index keyed on library.json's mtime: reading it is a single
    # stat, whereas LibraryManager.get_library() rescans the whole tree and
    # may rebuild every tag (a 250MB/1000-file library reads for ~3s). That
    # rebuild belongs in the explicit scan commands, never in the hot path
    # (track_index runs on every queue render and every MPRIS artUrl emit).
    lib_file = os.path.join(music_dir, ".beats", "library.json")
    try:
        mtime = os.path.getmtime(lib_file)
    except OSError:
        mtime = None
    entry = _index_cache.get(music_dir)
    if entry and entry[0] == mtime:
        return entry[1]
    try:
        with open(lib_file, encoding="utf-8") as f:
            tracks = json.load(f)
        idx = {t["file"]: t for t in tracks}
    except (OSError, json.JSONDecodeError, KeyError):
        # fall back to a full scan only if library.json is unreadable
        idx = {t["file"]: t for t in LibraryManager(music_dir=music_dir).get_library()}
    _index_cache[music_dir] = (mtime, idx)
    return idx
