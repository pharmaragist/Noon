import asyncio
import json
import mimetypes
import os
import urllib.parse

from websockets import Request, Response
from websockets.datastructures import Headers

from .controller import Controller
from .player import MpvPlayer

HERE = os.path.dirname(os.path.abspath(__file__))
STATIC_DIR = os.path.join(HERE, "page")

COVER_CACHE_DAYS = 30
_STATIC_CACHE = f"public, max-age={COVER_CACHE_DAYS * 86400}"
PUSH_INTERVAL = 0.5


def _coerce(v):
    if v is None:
        return None
    try:
        return json.loads(v)
    except (json.JSONDecodeError, TypeError):
        return v


def _library():
    from .library import LibraryManager
    return LibraryManager()


def _load_cover(path: str) -> tuple[bytes, str]:
    mime, _ = mimetypes.guess_type(path)
    with open(path, "rb") as f:
        return f.read(), mime or "image/jpeg"


def _resp(code: int, body: str | bytes, mime: str = "text/plain",
          cache: str = "") -> Response:
    if isinstance(body, str):
        body = body.encode()
    h = Headers({"Content-Type": mime})
    if cache:
        h["Cache-Control"] = cache
    reason = {200: "OK", 400: "Bad Request", 403: "Forbidden", 404: "Not Found"}.get(
        code, "Error"
    )
    return Response(code, reason, h, body)


class BeatsWebServer:
    def __init__(self, port: int = 8090, host: str = "127.0.0.1"):
        self.port = port
        self.host = host
        self.mpv = MpvPlayer()
        self.controller = Controller(self.mpv)
        self.clients = {}

    def _static(self, path: str) -> Response | None:
        path = path.split("?", 1)[0]
        if path == "/":
            path = "/index.html"
        filepath = os.path.normpath(os.path.join(STATIC_DIR, path.lstrip("/")))
        if not filepath.startswith(STATIC_DIR):
            return _resp(403, "Forbidden")
        if not os.path.isfile(filepath):
            return None
        mime, _ = mimetypes.guess_type(filepath)
        cache = "" if mime == "text/html" else _STATIC_CACHE
        with open(filepath, "rb") as f:
            return _resp(200, f.read(), mime or "application/octet-stream", cache)

    def _api(self, path: str, qs: dict) -> Response | None:
        json_endpoints = {
            "/api/library": lambda: _library().get_library(),
            "/api/status": lambda: self.controller.handle("status"),
            "/api/queue": lambda: self.controller.handle("queue"),
        }
        if path in json_endpoints:
            return _resp(200, json.dumps(json_endpoints[path]()), "application/json")

        if path == "/api/refresh-config":
            self.mpv.refresh_config()
            return _resp(200, "OK", "application/json")

        if path.startswith("/api/cmd"):
            cmd = qs.get("cmd", [""])[0]
            a = qs.get("a", [None])[0]
            b = qs.get("b", [None])[0]
            if not cmd:
                return _resp(400, "Bad Request")
            try:
                result = self.controller.handle(cmd, _coerce(a), _coerce(b))
            except Exception as e:
                return _resp(400, json.dumps({"error": str(e)}), "application/json")
            return _resp(200, json.dumps(result), "application/json")

        if path.startswith("/api/lyrics"):
            title = qs.get("title", [""])[0]
            artist = qs.get("artist", [""])[0]
            if not title:
                return _resp(400, '{"error": "missing title"}', "application/json")

            async def fetch_lyrics():
                script = os.path.join(HERE, "..", "lyrics_service.py")
                try:
                    proc = await asyncio.create_subprocess_exec(
                        "python3", script, "--title", title, "--artist", artist,
                        stdout=asyncio.subprocess.PIPE, stderr=asyncio.subprocess.PIPE,
                    )
                    out, _ = await asyncio.wait_for(proc.communicate(), timeout=15)
                    data = json.loads(out.decode())
                    if "error" in data:
                        return _resp(404, json.dumps(data), "application/json")
                    return _resp(200, json.dumps(data), "application/json")
                except Exception as e:
                    return _resp(500, json.dumps({"error": str(e)}), "application/json")

            return fetch_lyrics()

        if path.startswith("/api/covers/"):
            rel = urllib.parse.unquote(path.removeprefix("/api/covers/"))
            if not rel:
                return _resp(400, "Bad Request")
            lib = _library()
            music_dir = lib.music_dir
            cover_rel = lib._load_cover_map().get(rel)
            if not cover_rel:
                dir_path = os.path.dirname(os.path.join(music_dir, rel))
                for name in ("cover.jpg", "cover.png", "folder.jpg", "folder.png",
                             "AlbumArt.jpg", "AlbumArt.png", "front.jpg", "front.png"):
                    if os.path.isfile(os.path.join(dir_path, name)):
                        cover_rel = os.path.relpath(
                            os.path.join(dir_path, name), music_dir
                        )
                        break

            if not cover_rel:
                full_candidate = os.path.normpath(os.path.join(music_dir, rel))
                if full_candidate.startswith(os.path.normpath(music_dir)) and os.path.isfile(full_candidate):
                    cover_rel = rel

            if not cover_rel:
                return _resp(404, "Not Found")
            full = os.path.normpath(os.path.join(music_dir, cover_rel))
            if not full.startswith(os.path.normpath(music_dir)):
                return _resp(403, "Forbidden")
            if not os.path.isfile(full):
                return _resp(404, "Not Found")
            data, mime = _load_cover(full)
            return _resp(200, data, mime, _STATIC_CACHE)

        return None

    def _on_http(self, conn, req: Request) -> Response | None:
        path = req.path
        if req.headers.get("Upgrade", "").lower() == "websocket":
            return None
        if path.startswith("/api/"):
            parsed = urllib.parse.urlparse(path)
            qs = urllib.parse.parse_qs(parsed.query)
            resp = self._api(path, qs)
            return resp if resp else _resp(404, "Not Found")
        resp = self._static(path)
        if resp is not None:
            return resp
        return _resp(404, "Not Found")

    def _status_fields(self) -> dict:
        s = self.mpv.snapshot()
        return {
            "type": "status",
            "state": s["state"],
            "volume": s["volume"],
            "elapsed": s["position"],
            "duration": s["duration"],
            "repeat": s["repeat"],
            "title": s["title"],
            "artist": s["artist"],
            "album": s["album"],
            "file": s["file"],
        }

    async def _broadcast(self, payload: dict):
        text = json.dumps(payload)
        for ws, lock in list(self.clients.items()):
            try:
                async with lock:
                    await ws.send(text)
            except Exception:
                self.clients.pop(ws, None)

    async def _push_loop(self):
        last_status = None
        last_qkey = None
        while True:
            try:
                fields = self._status_fields()
                if fields["state"] == "play" or fields != last_status:
                    last_status = fields
                    await self._broadcast(fields)
                qkey = (self.mpv.queue_version,
                        self.mpv.snapshot()["queue_length"],
                        self.mpv.snapshot()["playlist_pos"])
                if qkey != last_qkey:
                    last_qkey = qkey
                    await self._broadcast({"type": "queue",
                                           "queue": self.controller.handle("queue")})
            except Exception:
                pass
            await asyncio.sleep(PUSH_INTERVAL)

    async def _on_ws(self, websocket):
        lock = asyncio.Lock()
        self.clients[websocket] = lock
        try:
            async with lock:
                await websocket.send(json.dumps(self._status_fields()))
                await websocket.send(json.dumps({"type": "queue",
                                                 "queue": self.controller.handle("queue")}))
            async for raw in websocket:
                try:
                    msg = json.loads(raw)
                except (json.JSONDecodeError, TypeError):
                    continue
                cmd = msg.get("cmd", "")
                a = msg.get("a")
                b = msg.get("b")
                if not cmd:
                    continue
                try:
                    result = self.controller.handle(cmd, a, b)
                except Exception as e:
                    async with lock:
                        await websocket.send(json.dumps({"ok": False, "error": str(e)}))
                    continue
                async with lock:
                    await websocket.send(json.dumps({"ok": True, "data": result}))
        finally:
            self.clients.pop(websocket, None)

    async def start(self):
        from .mpris import MprisService
        lib = _library()

        def cover_url(rel: str) -> str:
            if not rel:
                return ""
            cover_map = lib._load_cover_map()
            cover_rel = cover_map.get(rel, "")
            if not cover_rel:
                return ""
            full = os.path.normpath(os.path.join(lib.music_dir, cover_rel))
            if os.path.isfile(full):
                return f"file://{full}"
            return ""

        mpris = MprisService(self.mpv, cover_url=cover_url)
        await mpris.start()

        asyncio.get_running_loop().create_task(self._push_loop())
        print(f"  beats → http://{self.host}:{self.port}")
        from websockets.asyncio.server import serve
        async with serve(self._on_ws, self.host, self.port,
                         process_request=self._on_http) as srv:
            await srv.serve_forever()
