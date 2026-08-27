import os
import random
import sys
import threading
from collections import deque
import mpv
from .config import conf_require


class MpvPlayer:

    def __init__(self):
        self.music_dir = os.path.expanduser(conf_require('directory')['directory'])
        self.seek_hook = None
        self.queue_version = 0
        self.random = False
        self._order = None
        self._order_cur = 0
        self._history = deque(maxlen=256)
        self._order_lock = threading.Lock()
        self.player = mpv.MPV(ytdl=True, vo='null', input_default_bindings=False, input_vo_keyboard=False, keep_open='always')
        # property cache fed by observers (event thread) so the polling loops in
        # snapshot() never block on libmpv -- the synchronous reads were the CPU
        # spike (every _get_property marshals a node while the A/V threads fight
        # over libmpv's core lock)
        self._state = {
            'playlist': [], 'playlist_pos': -1, 'idle_active': True,
            'pause': False, 'metadata': {}, 'time_pos': 0.0, 'volume': 0,
            'speed': 1.0, 'loop_playlist': False, 'loop_file': False, 'duration': 0.0,
        }
        for prop in ('playlist', 'playlist-pos', 'idle-active', 'pause', 'metadata',
                     'time-pos', 'volume', 'speed', 'loop-playlist', 'loop-file', 'duration'):
            key = prop.replace('-', '_')
            self.player.observe_property(prop, lambda _n, val, k=key: self._state.__setitem__(k, val))

        @self.player.property_observer('eof-reached')
        def _on_eof(name, reached):
            if reached and (not self.player.loop_file):
                self.next()

    def refresh_config(self):
        self.music_dir = os.path.expanduser(conf_require('directory')['directory'])

    def _rel(self, abs_path: str) -> str:
        if not abs_path:
            return ''
        if abs_path.startswith(('http://', 'https://', 'ytdl://')):
            return abs_path
        try:
            return os.path.relpath(abs_path, self.music_dir)
        except ValueError:
            return abs_path

    def _resolve(self, path: str) -> str:
        if not path:
            return path
        if path.startswith(('http://', 'https://', 'ytdl://')):
            return path
        if os.path.isabs(path):
            return path
        return os.path.join(self.music_dir, path)

    def snapshot(self) -> dict:
        st = self._state
        playlist = st.get('playlist') or []
        pl_pos = st.get('playlist_pos')
        idle = bool(st.get('idle_active'))
        if idle or pl_pos is None or pl_pos < 0 or pl_pos >= len(playlist):
            file_abs = ''
            state = 'stop'
        else:
            file_abs = playlist[pl_pos].get('filename', '')
            state = 'pause' if st.get('pause') else 'play'
        meta = st.get('metadata') or {}
        file_rel = self._rel(file_abs)
        return {'state': state, 'title': meta.get('title') or (os.path.basename(file_abs) if file_abs else ''), 'artist': meta.get('artist', ''), 'album': meta.get('album', ''), 'file': file_rel, 'position': float(st.get('time_pos') or 0), 'duration': self._effective_duration(), 'volume': int(round(st.get('volume') or 0)), 'rate': float(st.get('speed') or 1.0), 'repeat': bool(st.get('loop_playlist')), 'loop_track': bool(st.get('loop_file')), 'random': self.random, 'playlist_pos': pl_pos}

    def play_pause(self):
        snap = self.snapshot()
        if snap['state'] == 'stop':
            return
        self.player.pause = snap['state'] != 'pause'

    def play(self):
        snap = self.snapshot()
        if snap['state'] != 'stop':
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
        name_lower = name.lower()
        for pos, entry in enumerate(self.player.playlist or []):
            if name_lower in self._rel(entry.get('filename', '')).lower():
                self.player.playlist_play_index(pos)
                return
        index = track_index(self.music_dir)
        if name in index:
            matches = [name]
        else:
            matches = [f for f in index if name_lower in f.lower()]
            if not matches:
                matches = [f for f, t in index.items() if name_lower in t['title'].lower()]
        if not matches:
            print(f'Track not found: {name}', file=sys.stderr)
            return
        target = self._resolve(matches[0])
        rest = [self._resolve(f) for f in index if self._resolve(f) != target]
        self._replace_and_play([target] + rest)

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
            title_map[track['title'].lower()] = f
        resolved = []
        for title in (t.strip() for t in titles.split(',') if t.strip()):
            f = title_map.get(title.lower())
            if f:
                resolved.append(self._resolve(f))
            else:
                print(f'Track not found in library: {title}', file=sys.stderr)
        if not resolved:
            print('No tracks resolved, aborting.', file=sys.stderr)
            return
        self._replace_and_play(resolved)

    def _replace_and_play(self, paths: list):
        p = self.player
        p.playlist_clear()
        for path in paths:
            p.playlist_append(path)
        self._order = None
        self.queue_version += 1
        if paths:
            p.playlist_play_index(0)

    def next(self):
        p = self.player
        playlist = p.playlist or []
        if not playlist:
            return
        if not self.random:
            pos = p.playlist_pos
            if pos >= len(playlist) - 1 and (not p.loop_playlist):
                self.stop()
            else:
                p.playlist_next()
            return
        with self._order_lock:
            self._ensure_order()
            at_end = self._order_cur >= len(self._order) - 1
            if at_end and (not p.loop_playlist):
                self.stop()
                return
            cur_id = self._current_entry_id(playlist)
            if cur_id is not None:
                self._history.append(cur_id)
            if at_end:
                self._order = None
                self._ensure_order()
                self._order_cur = 0
            self._order_cur += 1
            if self._order_cur >= len(self._order):
                self._order_cur = 0
            self._play_order_entry()

    def prev(self):
        p = self.player
        if not self.random:
            p.playlist_prev()
            return
        if not (p.playlist or []):
            return
        with self._order_lock:
            self._ensure_order()
            while self._history:
                pid = self._history.pop()
                idx = next((i for i, e in enumerate(p.playlist or []) if e.get('id') == pid), -1)
                if idx < 0:
                    continue
                if pid in self._order:
                    self._order_cur = self._order.index(pid)
                p.playlist_play_index(idx)
                return
            self._order_cur = max(0, self._order_cur - 1)
            self._play_order_entry()

    def _current_entry_id(self, playlist=None):
        # read from the observer cache, never block on libmpv (this runs on
        # every queue render / random-order step)
        if playlist is None:
            playlist = self._state.get('playlist') or []
        pos = self._state.get('playlist_pos')
        if pos is None:
            return None
        if 0 <= pos < len(playlist):
            return playlist[pos].get('id')
        return None

    def _play_order_entry(self):
        pid = self._order[self._order_cur]
        idx = next((i for i, e in enumerate(self.player.playlist or []) if e.get('id') == pid), -1)
        if idx >= 0:
            self.player.playlist_play_index(idx)

    def _ensure_order(self):
        p = self.player
        live_ids = [e.get('id') for e in p.playlist or []]
        cur_id = self._current_entry_id()
        if self._order is None:
            rest = [i for i in live_ids if i != cur_id]
            random.shuffle(rest)
            self._order = ([cur_id] if cur_id is not None else []) + rest
            self._order_cur = 0 if cur_id is not None else -1
            return
        kept = [i for i in self._order if i in set(live_ids)]
        added = [i for i in live_ids if i not in set(kept)]
        random.shuffle(added)
        splice_at = kept.index(cur_id) + 1 if cur_id in kept else len(kept)
        kept[splice_at:splice_at] = added
        self._order = kept
        self._order_cur = kept.index(cur_id) if cur_id in kept else -1 if not kept else 0

    def stop(self):
        self.player.stop(keep_playlist=True)

    def seek(self, seconds: float, relative: bool=True):
        p = self.player
        target = seconds if not relative else float(p.time_pos or 0) + seconds
        max_dur = self._effective_duration()
        if max_dur > 0:
            target = min(target, max(max_dur - 1.0, 0.0))
        p.seek(max(0.0, target), reference='absolute')
        if self.seek_hook:
            self.seek_hook()

    def _effective_duration(self) -> float:
        return float(self._state.get('duration') or 0)

    def set_volume(self, volume: int):
        self.player.volume = max(0, min(100, volume))

    def set_rate(self, rate: float):
        self.player.speed = max(0.01, min(100.0, rate))

    def set_repeat(self, enabled: bool):
        self.player.loop_playlist = bool(enabled)

    def set_loop_track(self, enabled: bool):
        self.player.loop_file = bool(enabled)

    def play_index(self, index: int):
        self._order = None
        self.player.playlist_play_index(index)

    def set_random(self, enabled: bool):
        self.random = bool(enabled)
        self._order = None

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
        if index < 0 or index >= n or new_index < 0 or (new_index >= n):
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
        self._order = None
        self.queue_version += 1

    def get_queue(self) -> list:
        from .library import track_index
        index = track_index(self.music_dir)
        playlist = self._state.get('playlist') or []
        current_pos = self._state.get('playlist_pos')
        if current_pos is None:
            current_pos = -1
        cur_id = self._current_entry_id(playlist)
        if self.random and playlist:
            with self._order_lock:
                self._ensure_order()
            pos_by_id = {e.get('id'): pos for pos, e in enumerate(playlist)}
            if self._order_cur >= 0:
                ids = self._order[self._order_cur:] + self._order[:self._order_cur]
            else:
                ids = list(self._order)
            rows = [(pos_by_id[i], i == cur_id) for i in ids if i in pos_by_id]
        else:
            rows = [(pos, pos == current_pos) for pos in range(len(playlist))]
        queue = []
        for pos, current in rows:
            entry = playlist[pos]
            rel = self._rel(entry.get('filename', ''))
            track = index.get(rel, {})
            queue.append({'index': pos, 'file': rel, 'title': track.get('title') or (os.path.basename(rel) if rel else ''), 'artist': track.get('artist', ''), 'album': track.get('album', ''), 'duration': track.get('duration', 0), 'cover': track.get('cover', ''), 'current': current})
        if not self.random and 0 <= current_pos < len(queue):
            return queue[current_pos:] + queue[:current_pos]
        return queue

    def terminate(self):
        try:
            self.player.terminate()
        except Exception:
            pass
