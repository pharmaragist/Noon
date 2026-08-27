import asyncio
import base64
import hashlib
import json
import os
import struct
from urllib.parse import unquote, urlparse

from . import hits
from .config import load_conf, _write

WS_GUID = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11"
DIST_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "page")
CONTENT_TYPES = {
    ".html": "text/html",
    ".js": "text/javascript",
    ".css": "text/css",
    ".svg": "image/svg+xml",
    ".png": "image/png",
    ".jpg": "image/jpeg",
    ".woff2": "font/woff2",
    ".json": "application/json",
}


class WebServer:
    def __init__(self, music_dir, snapshot_fn, queue_fn, queue_version_fn, dispatch):
        self.music_dir = music_dir
        self._snapshot = snapshot_fn
        self._queue = queue_fn
        self._queue_version = queue_version_fn
        self._dispatch = dispatch

    async def start(self, host="127.0.0.1", port=8237):
        server = await asyncio.start_server(self._client, host, port)
        print(f"  beats → web http://{host}:{port}", flush=True)
        async with server:
            await server.serve_forever()

    async def _client(self, reader, writer):
        try:
            line = await asyncio.wait_for(reader.readline(), 10)
            if not line:
                return
            method, full_path, _ = line.decode("latin-1").split(" ", 2)
            parsed = urlparse(full_path)
            path = unquote(parsed.path)
            query = unquote(parsed.query)
            query_dict = dict(p.split("=", 1) for p in query.split("&") if "=" in p)
            headers = {}
            while True:
                h = await reader.readline()
                if h in (b"\r\n", b"\n", b""):
                    break
                k, _, v = h.decode("latin-1").partition(":")
                headers[k.strip().lower()] = v.strip()

            if headers.get("upgrade", "").lower() == "websocket":
                await self._ws(reader, writer, headers)
                return

            body = b""
            n = int(headers.get("content-length", 0) or 0)
            if n:
                body = (await reader.readexactly(n))[:65536]

            if path == "/api/players":
                await self._json(writer, {"noon": {"name": "noon", "running": True}})
            elif path == "/api/library":
                lib = os.path.join(self.music_dir, ".beats", "library.json")
                await self._send_file(writer, lib, "application/json")
            elif path.startswith("/api/covers/"):
                rel = os.path.normpath(path[len("/api/covers/"):]).lstrip("/")
                base = os.path.normpath(self.music_dir)
                if rel.startswith(".beats/coverarts"):
                    full = os.path.normpath(os.path.join(base, rel))
                else:
                    # track path: resolve its embedded cover from the library
                    full = None
                    try:
                        with open(os.path.join(base, ".beats", "library.json")) as f:
                            for t in json.load(f):
                                if t.get("file") == rel:
                                    if t.get("cover"):
                                        cand = os.path.normpath(os.path.join(base, t["cover"]))
                                        if cand.startswith(base):
                                            full = cand
                                    break
                    except (OSError, json.JSONDecodeError):
                        pass
                if full is not None and not full.startswith(base):
                    await self._json(writer, {"error": "forbidden"}, 403)
                elif full and os.path.isfile(full):
                    await self._send_file(writer, full)
                else:
                    await self._json(writer, {"error": "not found"}, 404)
            elif path == "/api/lyrics":
                await self._send_file(writer, os.path.join(self.music_dir, ".beats", "lyrics.json"), "application/json")
            elif path == "/api/hits/feed":
                def thumb_url(t):
                    if t.get("thumbnail") and not t["thumbnail"].startswith("/api/thumbs/"):
                        t["thumbnail"] = "/api/thumbs/" + os.path.basename(t["thumbnail"])
                    return t
                h = load_conf().get("hits", {})
                await self._json(writer, {
                    "feed": [thumb_url(t) for t in h.get("feed", [])],
                    "searchResults": [thumb_url(t) for t in h.get("searchResults", [])],
                })
            elif path.startswith("/api/hits/"):
                kind = path.rsplit("/", 1)[-1]
                limit = int(query_dict.get("limit", 18) or 18)

                def run_hits():
                    if kind == "search":
                        out = hits.search(query_dict.get("query", ""), limit)
                    elif kind == "recommend":
                        out = hits.recommend(self.music_dir, limit)
                    else:
                        out = hits.discover(limit)
                    for t in out:
                        if t.get("thumbnail"):
                            t["thumbnail"] = "/api/thumbs/" + os.path.basename(t["thumbnail"])
                    conf = load_conf()
                    h = conf.setdefault("hits", {})
                    if kind == "search":
                        h["searchResults"] = out
                    else:
                        seen = {t.get("videoId") or t.get("url") for t in h.get("feed", [])}
                        h["feed"] = h.get("feed", []) + [
                            t for t in out if (t.get("videoId") or t.get("url")) not in seen
                        ]
                    _write(conf)
                    return out

                items = await asyncio.to_thread(run_hits)
                await self._json(writer, items)
            elif path.startswith("/api/thumbs/"):
                name = os.path.basename(path[len("/api/thumbs/"):])
                await self._send_file(writer, os.path.join(hits.CACHE_DIR, name))
            elif path == "/api/cmd" and method == "POST":
                try:
                    msg = json.loads(body)
                    if "cmd" in msg and "command" not in msg:
                        msg["command"] = msg.pop("cmd")
                    self._dispatch(msg)
                    await self._json(writer, {"ok": True})
                except Exception as e:
                    await self._json(writer, {"error": str(e)}, 400)
            elif method == "GET":
                await self._static(writer, path)
            else:
                await self._json(writer, {"error": "not found"}, 404)
        except (asyncio.IncompleteReadError, ConnectionError):
            pass
        finally:
            writer.close()

    async def _static(self, writer, path):
        name = path.lstrip("/") or "index.html"
        full = os.path.normpath(os.path.join(DIST_DIR, name))
        if not full.startswith(os.path.normpath(DIST_DIR)):
            await self._json(writer, {"error": "forbidden"}, 403)
            return
        if not os.path.isfile(full):
            full = os.path.join(DIST_DIR, "index.html")
        await self._send_file(writer, full)

    async def _send_file(self, writer, path, ctype=None):
        try:
            with open(path, "rb") as f:
                data = f.read()
        except OSError:
            await self._json(writer, {"error": "not found"}, 404)
            return
        ext = os.path.splitext(path)[1].lower()
        await self._respond(writer, data, ctype or CONTENT_TYPES.get(ext, "application/octet-stream"))

    async def _respond(self, writer, body, ctype, code=200):
        head = (
            f"HTTP/1.1 {code} OK\r\nContent-Type: {ctype}\r\n"
            f"Content-Length: {len(body)}\r\nConnection: close\r\n\r\n"
        ).encode("latin-1")
        writer.write(head + body)
        await writer.drain()

    async def _json(self, writer, obj, code=200):
        await self._respond(writer, json.dumps(obj).encode(), "application/json", code)

    async def _ws(self, reader, writer, headers):
        key = headers.get("sec-websocket-key", "")
        accept = base64.b64encode(hashlib.sha1((key + WS_GUID).encode()).digest()).decode()
        writer.write(
            b"HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\n"
            b"Connection: Upgrade\r\nSec-WebSocket-Accept: " + accept.encode() + b"\r\n\r\n"
        )
        await writer.drain()

        pusher = asyncio.create_task(self._ws_pusher(writer))
        try:
            while True:
                frame = await self._ws_frame(reader)
                if frame is None:
                    break
                opcode, payload = frame
                if opcode == 8:
                    break
                if opcode == 1:
                    try:
                        msg = json.loads(payload)
                        if "cmd" in msg and "command" not in msg:
                            msg["command"] = msg.pop("cmd")
                        self._dispatch(msg)
                    except Exception:
                        pass
        except (asyncio.IncompleteReadError, ConnectionError):
            pass
        finally:
            pusher.cancel()
            try:
                await pusher
            except (asyncio.CancelledError, ConnectionError):
                pass

    async def _ws_pusher(self, writer):
        last_key = None
        last_qv = None
        while True:
            s = self._snapshot()
            key = (
                s["playlist_pos"], s["state"], s["volume"],
                round(s["position"], 1), s["random"], s["repeat"], s["loop_track"],
            )
            if key != last_key:
                last_key = key
                await self._ws_send(writer, json.dumps({
                    "type": "status", **s,
                    "elapsed": s["position"], "length": s["duration"],
                }))
            qv = self._queue_version()
            if qv != last_qv:
                last_qv = qv
                await self._ws_send(writer, json.dumps({"type": "queue", "queue": self._queue()}))
            await asyncio.sleep(0.25)

    async def _ws_send(self, writer, text):
        payload = text.encode()
        header = bytearray([0x81])
        n = len(payload)
        if n < 126:
            header.append(n)
        elif n < 65536:
            header.append(126)
            header += struct.pack(">H", n)
        else:
            header.append(127)
            header += struct.pack(">Q", n)
        writer.write(bytes(header) + payload)
        await writer.drain()

    async def _ws_frame(self, reader):
        head = await reader.readexactly(2)
        opcode = head[0] & 0x0F
        masked = head[1] & 0x80
        length = head[1] & 0x7F
        if length == 126:
            length = struct.unpack(">H", await reader.readexactly(2))[0]
        elif length == 127:
            length = struct.unpack(">Q", await reader.readexactly(8))[0]
        mask = await reader.readexactly(4) if masked else None
        payload = await reader.readexactly(length) if length else b""
        if mask:
            payload = bytes(b ^ mask[i % 4] for i, b in enumerate(payload))
        return opcode, payload
