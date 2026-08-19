import base64
import hashlib
import json
import math
import os
import sys
import time
from concurrent.futures import ProcessPoolExecutor, as_completed

from mutagen import File

from .config import conf_require

WORKERS = os.cpu_count() or 4
TEMP_FILE = os.path.expanduser("~/.local/state/noon/user/generated/beats_library.json")
AUDIO_EXTS = {".mp3", ".flac", ".ogg", ".opus", ".m4a", ".aac", ".wav", ".wma", ".mp4"}


def _process_chunk(args: tuple) -> list:
    """
    Runs in a worker process.
    Returns list of (rel_path, rel_cover_path).
    Writes cover files directly to disk.
    """
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
                        img_ext = (
                            "png"
                            if covers[0].imageformat == MP4Cover.FORMAT_PNG
                            else "jpg"
                        )
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
                import shutil

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
    return [items[i : i + size] for i in range(0, len(items), size)]


def _iso_mtime(st_mtime: float) -> str:
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime(st_mtime))


def _scan_mtimes(music_dir: str) -> dict:
    """Rel path -> ISO mtime for every audio file under music_dir (fast walk)."""
    mtimes = {}
    for root, dirs, files in os.walk(music_dir):
        dirs[:] = [d for d in dirs if d != ".coverarts"]
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
    try:
        audio = File(abs_path, easy=True)
    except Exception:
        pass
    if audio is None:
        try:
            audio = File(abs_path)
        except Exception:
            return None
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
        self.covers_dir = os.path.join(self.music_dir, ".coverarts")

    def _cover_map_path(self) -> str:
        return os.path.join(self.music_dir, ".covermap.json")

    def _load_cover_map(self) -> dict:
        path = self._cover_map_path()
        if os.path.exists(path):
            try:
                with open(path) as f:
                    return json.load(f)
            except Exception:
                pass
        return {}

    def _save_cover_map(self, cover_map: dict):
        with open(self._cover_map_path(), "w") as f:
            json.dump(cover_map, f, indent=2, ensure_ascii=False)

    def build_covers(self):
        os.makedirs(self.covers_dir, exist_ok=True)
        cover_map = self._load_cover_map()
        stale = [
            rel for rel in cover_map
            if not os.path.exists(os.path.join(self.music_dir, rel))
        ]
        for rel in stale:
            del cover_map[rel]
        if stale:
            self._save_cover_map(cover_map)
            print(f"  Pruned {len(stale)} stale cover entries.")

        tracks = sorted(_scan_mtimes(self.music_dir))
        pending = [rel for rel in tracks if rel not in cover_map]

        total = len(tracks)
        cached = total - len(pending)
        print(f"  Total:   {total}")
        print(f"  Cached:  {cached}")
        print(f"  Pending: {len(pending)}")
        print(f"  Workers: {WORKERS}\n")

        if not pending:
            print("  Nothing to do.")
            return cover_map

        chunks = _make_chunks(pending, WORKERS)
        chunk_args = [(chunk, self.music_dir, self.covers_dir) for chunk in chunks]

        done = 0
        with ProcessPoolExecutor(max_workers=WORKERS) as pool:
            futures = {
                pool.submit(_process_chunk, arg): i for i, arg in enumerate(chunk_args)
            }
            for future in as_completed(futures):
                try:
                    for rel_path, rel_cover in future.result():
                        cover_map[rel_path] = rel_cover
                        done += 1
                        print(f"  [{done}/{len(pending)}] {rel_path}", flush=True)
                except Exception as e:
                    print(f"  [CHUNK ERR] {e}", file=sys.stderr)

        self._save_cover_map(cover_map)
        print(f"\nDone. {done} new covers extracted.")
        return cover_map

    def _cache_valid(self, mtimes: dict) -> list | None:
        """Return cached library if it matches the current filesystem, else None."""
        if not os.path.exists(TEMP_FILE):
            return None
        try:
            with open(TEMP_FILE) as f:
                tracks = json.load(f)
        except (json.JSONDecodeError, IOError):
            return None
        if len(tracks) != len(mtimes):
            return None
        for t in tracks:
            if mtimes.get(t.get("file")) != t.get("last_modified"):
                return None
        return tracks

    def get_library(self) -> list:
        mtimes = _scan_mtimes(self.music_dir)
        tracks = self._cache_valid(mtimes)
        if tracks is None:
            tracks = []
            for rel in sorted(mtimes):
                track = _read_tags(self.music_dir, rel)
                if track is None:
                    continue
                track["last_modified"] = mtimes[rel]
                tracks.append(track)
            cover_map = self._load_cover_map()
            for t in tracks:
                t["cover"] = cover_map.get(t["file"], "")
            with open(TEMP_FILE, "w", encoding="utf-8") as f:
                json.dump(tracks, f, ensure_ascii=False, indent=2)
        else:
            cover_map = self._load_cover_map()
            for t in tracks:
                t["cover"] = cover_map.get(t["file"], "")
        tracks.sort(key=lambda t: t["last_modified"], reverse=True)
        return tracks

    def track_index(self) -> dict:
        return {t["file"]: t for t in self.get_library()}

    def list_artists(self) -> list:
        return sorted({t["artist"] for t in self.get_library() if t["artist"]})

    def list_albums(self) -> list:
        return sorted({t["album"] for t in self.get_library() if t["album"]})

    def list_genres(self) -> list:
        return sorted({t["genre"] for t in self.get_library() if t["genre"]})


def track_index(music_dir: str) -> dict:
    return LibraryManager(music_dir=music_dir).track_index()
