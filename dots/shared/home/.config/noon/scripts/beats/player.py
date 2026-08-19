import os
import subprocess
import sys
import threading

import mpv

from .config import conf_require


class MpvPlayer:
    """Embedded libmpv player (one per daemon). MPD-free."""

    def __init__(self):
        self.music_dir = os.path.expanduser(conf_require("directory")["directory"])
        self.seek_hook = None
        self.queue_version = 0
        self._real_dur = {}
        self._probing = set()
        self.player = mpv.MPV(
            ytdl=True,
            vo="null",
            input_default_bindings=False,
            input_vo_keyboard=False,
            keep_open=True,
        )

    def refresh_config(self):
        self.music_dir = os.path.expanduser(conf_require("directory")["directory"])

    def _rel(self, abs_path: str) -> str:
        if not abs_path:
            return ""
        if abs_path.startswith(("http://", "https://", "ytdl://")):
            return abs_path
        try:
            return os.path.relpath(abs_path, self.music_dir)
        except ValueError:
            return abs_path

    def _resolve(self, path: str) -> str:
        if not path:
            return path
        if path.startswith(("http://", "https://", "ytdl://")):
            return path
        if os.path.isabs(path):
            return path
        return os.path.join(self.music_dir, path)

    def snapshot(self) -> dict:
        p = self.player
        try:
            playlist = p.playlist or []
        except Exception:
            playlist = []
        pl_pos = p.playlist_pos
        idle = bool(p.idle_active)

        if idle or pl_pos < 0 or pl_pos >= len(playlist):
            file_abs = ""
            state = "stop"
        else:
            file_abs = playlist[pl_pos].get("filename", "")
            state = "pause" if p.pause else "play"

        meta = p.metadata or {}
        file_rel = self._rel(file_abs)
        self._probe_real_duration(file_abs)
        return {
            "running": True,
            "state": state,
            "title": meta.get("title")
            or (os.path.basename(file_abs) if file_abs else ""),
            "artist": meta.get("artist", ""),
            "album": meta.get("album", ""),
            "file": file_rel,
            "position": float(p.time_pos or 0),
            "duration": self._effective_duration(file_abs),
            "volume": int(round(p.volume or 0)),
            "rate": float(p.speed or 1.0),
            "repeat": bool(p.loop_playlist),
            "loop_track": bool(p.loop_file),
            "random": bool(p.shuffle),
            "queue_length": len(playlist),
            "playlist_pos": pl_pos,
        }

    def play_pause(self):
        snap = self.snapshot()
        if snap["state"] == "stop":
            return
        self.player.pause = snap["state"] != "pause"

    def play(self):
        snap = self.snapshot()
        if snap["state"] != "stop":
            self.player.pause = False
            return
        playlist = self.player.playlist or []
        if not playlist:
            return
        pos = self.player.playlist_pos
        if pos is None or pos < 0 or pos >= len(playlist):
            pos = 0
        self.player.playlist_play_index(pos)

    def pause(self, state: bool):
        self.player.pause = bool(state)

    def play_by_name(self, name: str):
        from .library import track_index

        index = track_index(self.music_dir)
        name_lower = name.lower()

        target = None
        playlist = self.player.playlist or []
        for pos, entry in enumerate(playlist):
            f = entry.get("filename", "")
            rel = self._rel(f)
            if name_lower in rel.lower():
                target = (pos, f)
                break

        if target is None and name in index:
            target = (None, self._resolve(name))

        if target is None:
            for f in index:
                if name_lower in f.lower():
                    target = (None, self._resolve(f))
                    break

        if target is None:
            for f, track in index.items():
                if name_lower in track["title"].lower():
                    target = (None, self._resolve(f))
                    break

        if target is None:
            print(f"Track not found: {name}", file=sys.stderr)
            return

        if target[0] is not None:
            self.player.playlist_play_index(target[0])
            return

        paths = [target[1]]
        for f in index:
            resolved = self._resolve(f)
            if resolved != target[1]:
                paths.append(resolved)
        self._replace_and_play(paths)

    def play_file(self, filepath: str):
        self._replace_and_play([self._resolve(filepath)])

    def play_files(self, paths: list):
        self._replace_and_play([self._resolve(p) for p in paths])

    def play_url(self, url: str):
        self._replace_and_play([url])

    def build_playlist(self, titles: str):
        from .library import track_index

        index = track_index(self.music_dir)
        title_map = {}
        for f, track in index.items():
            title_map[track["title"].lower()] = f

        resolved = []
        for title in (t.strip() for t in titles.split(",") if t.strip()):
            f = title_map.get(title.lower())
            if f:
                resolved.append(self._resolve(f))
            else:
                print(f"Track not found in library: {title}", file=sys.stderr)

        if not resolved:
            print("No tracks resolved, aborting.", file=sys.stderr)
            return
        self._replace_and_play(resolved)

    def _replace_and_play(self, paths: list):
        p = self.player
        p.playlist_clear()
        for path in paths:
            p.playlist_append(path)
        self.queue_version += 1
        if paths:
            p.playlist_play_index(0)

    def next(self):
        p = self.player
        if p.playlist_pos >= len(p.playlist or []) - 1:
            if not p.loop_playlist:
                self.stop()
            return
        p.playlist_next()

    def prev(self):
        self.player.playlist_prev()

    def stop(self):
        self.player.stop(keep_playlist=True)

    def seek(self, seconds: float, relative: bool = True):
        p = self.player
        # ponytail: mpv's relative seek misbehaves after an absolute seek (advances
        # the playlist), so compute the absolute target here and always seek absolute.
        target = seconds if not relative else float(p.time_pos or 0) + seconds
        playlist = p.playlist or []
        pos = p.playlist_pos
        max_dur = self._effective_duration(
            playlist[pos].get("filename", "") if 0 <= pos < len(playlist) else ""
        )
        if max_dur > 0:
            target = min(target, max(max_dur - 1.0, 0.0))
        p.seek(max(0.0, target), reference="absolute")
        if self.seek_hook:
            self.seek_hook()

    def _probe_real_duration(self, path: str):
        # ponytail: mpv's `duration` trusts the mp3 Xing header; corrupt headers
        # over-report (e.g. "3ala Ad El Hob.mp3": 204.5s vs ~42.4s of frames), so
        # seeking past the real EOF makes mpv advance the playlist. Measure the
        # actual last frame once per local file, async. Upgrade path: if many files
        # are affected, bake this into the library scan instead.
        if path in self._real_dur or path in self._probing:
            return
        if not os.path.isfile(path):
            return
        self._probing.add(path)
        threading.Thread(target=self._probe_worker, args=(path,), daemon=True).start()

    def _probe_worker(self, path: str):
        try:
            out = subprocess.run(
                [
                    "ffprobe",
                    "-v",
                    "error",
                    "-select_streams",
                    "a:0",
                    "-show_entries",
                    "frame=pts_time,duration_time",
                    "-of",
                    "csv=p=0",
                    path,
                ],
                capture_output=True,
                text=True,
                timeout=20,
            )
            line = out.stdout.strip().splitlines()[-1]
            pts, dur = (float(x) for x in line.split(",")[:2])
            real = pts + dur
            if real > 0:
                self._real_dur[path] = real
        except Exception:
            pass
        finally:
            self._probing.discard(path)

    def _effective_duration(self, path: str) -> float:
        return self._real_dur.get(path) or float(self.player.duration or 0)

    def set_volume(self, volume: int):
        self.player.volume = max(0, min(100, volume))

    def set_rate(self, rate: float):
        self.player.speed = max(0.01, min(100.0, rate))

    def set_repeat(self, enabled: bool):
        self.player.loop_playlist = bool(enabled)

    def set_loop_track(self, enabled: bool):
        self.player.loop_file = bool(enabled)

    def set_random(self, enabled: bool):
        self.player.shuffle = bool(enabled)

    def play_index(self, index: int):
        self.player.playlist_play_index(index)

    def queue_add(self, url_or_path: str):
        self.player.playlist_append(self._resolve(url_or_path))
        self.queue_version += 1

    def queue_remove(self, index: int):
        if index < 0 or index >= len(self.player.playlist or []):
            return
        self.player.playlist_remove(index)
        self.queue_version += 1

    def queue_move(self, index: int, new_index: int):
        n = len(self.player.playlist or [])
        if index < 0 or index >= n or new_index < 0 or new_index >= n:
            return
        if index == new_index:
            return
        to = new_index if index > new_index else new_index + 1
        self.player.playlist_move(index, min(to, n))
        self.queue_version += 1

    def queue_clear(self):
        p = self.player
        p.playlist_clear()
        if p.playlist:
            p.stop(keep_playlist=True)
        if p.playlist:
            p.playlist_remove(0)
        self.queue_version += 1

    def get_queue(self) -> list:
        from .library import track_index

        index = track_index(self.music_dir)
        playlist = self.player.playlist or []
        current_pos = self.player.playlist_pos
        queue = []
        for pos, entry in enumerate(playlist):
            rel = self._rel(entry.get("filename", ""))
            track = index.get(rel, {})
            queue.append(
                {
                    "index": pos,
                    "file": rel,
                    "title": track.get("title")
                    or (os.path.basename(rel) if rel else ""),
                    "artist": track.get("artist", ""),
                    "album": track.get("album", ""),
                    "duration": track.get("duration", 0),
                    "current": pos == current_pos,
                }
            )
        if current_pos >= 0 and current_pos < len(queue):
            return queue[current_pos:] + queue[:current_pos]
        return queue

    def terminate(self):
        try:
            self.player.terminate()
        except Exception:
            pass
