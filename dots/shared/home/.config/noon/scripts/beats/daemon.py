import asyncio
import json
import os
import sys

from . import lyrics
from .library import LibraryManager
from .player import MpvPlayer


def _atomic_json(path: str, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump(data, f, ensure_ascii=False)
    os.replace(tmp, path)


class BeatsDaemon:
    POLL = 0.1
    STATE_TICK = 0.25

    def __init__(self):
        self.mpv = MpvPlayer()
        self.lib = LibraryManager()
        self._preview_task = None
        self._lyrics_last = None
        self._pending_embed = []

    async def _flush_embeds(self):
        pending, self._pending_embed = self._pending_embed, []
        if not pending:
            return

        def work():
            done = 0
            for rel, text in pending:
                try:
                    if lyrics.embed_track(self.lib.music_dir, rel, text):
                        done += 1
                except Exception:
                    pass
            return done

        n = await asyncio.to_thread(work)
        if n:
            print(f"  beats: embedded {n} lyric tags", flush=True)

    @property
    def _cmd_path(self) -> str:
        return os.path.join(self.lib.music_dir, ".beats", "cmd.json")

    @property
    def _queue_path(self) -> str:
        return os.path.join(self.lib.music_dir, ".beats", "queue.json")

    @property
    def _lyrics_path(self) -> str:
        return os.path.join(self.lib.music_dir, ".beats", "lyrics.json")

    def _commands(self) -> dict:
        p = self.mpv
        return {
            "playByName": lambda a, b: p.play_by_name(a or ""),
            "playFile": lambda a, b: p.play_file(a or ""),
            "playFiles": lambda a, b: p.play_files(a if isinstance(a, list) else [a]),
            "playUrl": lambda a, b: p.play_url(a or ""),
            "buildPlaylist": lambda a, b: p.build_playlist(a or ""),
            "playPause": lambda a, b: p.play_pause(),
            "pause": lambda a, b: p.pause(True),
            "resume": lambda a, b: p.pause(False),
            "next": lambda a, b: p.next(),
            "prev": lambda a, b: p.prev(),
            "stop": lambda a, b: p.stop(),
            "seekBy": lambda a, b: p.seek(float(a or 0), relative=True),
            "seekTo": lambda a, b: p.seek(float(a or 0), relative=False),
            "setVolume": lambda a, b: p.set_volume(int(a or 0)),
            "setRepeat": lambda a, b: p.set_repeat(bool(a)),
            "playIndex": lambda a, b: p.play_index(int(a or 0)),
            "queueAdd": lambda a, b: p.queue_add(a or ""),
            "queueRemove": lambda a, b: p.queue_remove(int(a or 0)),
            "queueMove": lambda a, b: p.queue_move(int(a or 0), int(b or 0)),
            "queueClear": lambda a, b: p.queue_clear(),
            "refreshConfig": lambda a, b: p.refresh_config(),
            "lyricsRefetch": lambda a, b: setattr(self, "_lyrics_last", None),
        }

    def _execute(self, msg: dict):
        fn = self._commands().get(msg.get("command", ""))
        if fn is None:
            print(f"beats: unknown command {msg.get('command')!r}", flush=True)
            return
        try:
            fn(msg.get("a"), msg.get("b"))
        except Exception as e:
            print(f"beats: {msg.get('command')} failed: {e}", file=sys.stderr)

    def _request_preview(self, url: str):
        if not url:
            return
        if self._preview_task and not self._preview_task.done():
            self._preview_task.cancel()
            self._preview_task = None
        self._lyrics_last = None
        self._pending_embed = []

    async def _flush_embeds(self):
        pending, self._pending_embed = self._pending_embed, []
        if not pending:
            return

        def work():
            done = 0
            for rel, text in pending:
                try:
                    if lyrics.embed_track(self.lib.music_dir, rel, text):
                        done += 1
                except Exception:
                    pass
            return done

        n = await asyncio.to_thread(work)
        if n:
            print(f"  beats: embedded {n} lyric tags", flush=True)
        self._preview_task = asyncio.get_running_loop().create_task(self._preview(url))

    async def _preview(self, url: str):
        proc = await asyncio.create_subprocess_exec(
            "mpv",
            "--really-quiet",
            "--no-video",
            url,
            stdout=asyncio.subprocess.DEVNULL,
            stderr=asyncio.subprocess.DEVNULL,
            start_new_session=True,
        )
        try:
            await proc.wait()
        except asyncio.CancelledError:
            try:
                proc.kill()
                await proc.wait()
            except ProcessLookupError:
                pass
            raise

    async def _startup_embed(self):
        async def work():
            try:
                return await asyncio.to_thread(lyrics.embed_library, self.lib.music_dir)
            except Exception as e:
                print(f"beats: startup embed: {e}", file=sys.stderr)
                return 0

        n = await work()
        if n:
            print(f"  beats: embedded {n} lyric tags from cache", flush=True)

    async def _lyrics_loop(self):
        while True:
            try:
                s = self.mpv.snapshot()
                key = (s["file"], s["title"])
                if s["state"] == "stop":
                    await self._flush_embeds()
                elif s["file"] and key != self._lyrics_last:
                    self._lyrics_last = key
                    _atomic_json(self._lyrics_path, {
                        "title": s["title"],
                        "artist": s["artist"],
                        "text": "",
                    })
                    text = await asyncio.to_thread(
                        lyrics.get_lyrics, s["title"], s["artist"], self.lib.music_dir, s["file"])
                    if text:
                        _atomic_json(self._lyrics_path, {
                            "title": s["title"],
                            "artist": s["artist"],
                            "text": text,
                        })
                        if s["file"] not in self._pending_embed:
                            self._pending_embed.append((s["file"], text))
                        if len(self._pending_embed) >= 20:
                            await self._flush_embeds()
            except Exception as e:
                print(f"beats: lyrics: {e}", file=sys.stderr)
            await asyncio.sleep(0.5)

    async def _cmd_loop(self):
        while True:
            try:
                with open(self._cmd_path) as f:
                    msg = json.load(f)
                os.unlink(self._cmd_path)
                msg = msg if isinstance(msg, dict) else {}
                if msg.get("command") == "preview":
                    self._request_preview(msg.get("a") or "")
                else:
                    self._execute(msg)
            except FileNotFoundError:
                pass
            except (json.JSONDecodeError, OSError) as e:
                print(f"beats: bad cmd file: {e}", file=sys.stderr)
                try:
                    os.unlink(self._cmd_path)
                except OSError:
                    pass
            await asyncio.sleep(self.POLL)

    def _write_queue_state(self):
        s = self.mpv.snapshot()
        _atomic_json(
            self._queue_path,
            {
                "pos": s["playlist_pos"],
                "state": s["state"],
                "volume": s["volume"],
                "title": s["title"],
                "artist": s["artist"],
                "album": s["album"],
                "position": s["position"],
                "duration": s["duration"],
                "random": s["random"],
                "repeat": s["repeat"],
                "loopTrack": s["loop_track"],
                "queue": self.mpv.get_queue(),
            },
        )

    async def _queue_loop(self):
        last = None
        while True:
            try:
                s = self.mpv.snapshot()
                key = (self.mpv.queue_version, s["playlist_pos"], s["state"], s["volume"])
                if key != last:
                    self._write_queue_state()
                    last = key
            except Exception:
                pass
            await asyncio.sleep(self.STATE_TICK)

    async def run(self):
        from .mpris import MprisService
        from .web import WebServer

        def cover_url(rel: str) -> str:
            if not rel:
                return ""
            for t in self.lib.get_library():
                if t["file"] == rel and t.get("cover"):
                    full = os.path.normpath(os.path.join(self.lib.music_dir, t["cover"]))
                    if full.startswith(os.path.normpath(self.lib.music_dir)) and os.path.isfile(full):
                        return f"file://{full}"
            return ""

        mpris = MprisService(self.mpv, cover_url=cover_url)
        await mpris.start()
        print("  beats → mpris", flush=True)

        loop = asyncio.get_running_loop()
        loop.create_task(self._startup_embed())
        loop.create_task(self._cmd_loop())
        loop.create_task(self._queue_loop())
        loop.create_task(self._lyrics_loop())

        web = WebServer(
            self.lib.music_dir,
            self.mpv.snapshot,
            self.mpv.get_queue,
            lambda: self.mpv.queue_version,
            self._execute,
        )
        loop.create_task(web.start())

        await asyncio.Event().wait()
