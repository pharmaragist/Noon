import argparse
import json
import os
import signal
import subprocess
import sys
import time
import urllib.parse
import urllib.request

from .config import load_conf, conf_require, _write

LOG_FILE = os.path.expanduser("~/.cache/noon/beats/daemon.log")


def _proc_args(pid: int) -> list:
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            return [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
    except OSError:
        return []


def _kill_pid(pid: int):
    try:
        os.kill(pid, signal.SIGKILL)
    except (ProcessLookupError, PermissionError):
        pass


def _serve_pids() -> list:
    pids = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        args = _proc_args(pid)
        if not args or "serve" not in args:
            continue
        if any(a.endswith("beats_service.py") for a in args):
            pids.append(pid)
    return pids


def _daemon_script() -> str:
    return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
                        "beats_service.py")


def init():
    if _serve_pids():
        print("beats daemon already running.", file=sys.stderr)
        return
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    port = conf_require("webClientPort")["webClientPort"]
    print("Starting beats daemon...", file=sys.stderr, flush=True)
    with open(LOG_FILE, "a") as log:
        subprocess.Popen(
            [sys.executable, _daemon_script(), "serve", "--port", str(port)],
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    for _ in range(10):
        time.sleep(0.5)
        if _serve_pids():
            print(f"  daemon ready (port {port}).", file=sys.stderr)
            return
    print("  failed to start daemon.", file=sys.stderr)


def kill():
    for pid in _serve_pids():
        _kill_pid(pid)
    time.sleep(1)
    print("All stopped.", file=sys.stderr)


def _forward(cmd: str, a=None, b=None):
    port = conf_require("webClientPort")["webClientPort"]
    if not _serve_pids():
        print("beats daemon is not running (start it with 'serve' or 'init').",
              file=sys.stderr)
        sys.exit(1)
    params = [("cmd", cmd)]
    if a is not None:
        params.append(("a", a))
    if b is not None:
        params.append(("b", b))
    query = urllib.parse.urlencode(params)
    try:
        with urllib.request.urlopen(
            f"http://127.0.0.1:{port}/api/cmd?{query}", timeout=10
        ) as resp:
            body = resp.read().decode()
            if cmd in ("status", "queue"):
                print(body)
            elif body != '{"ok": true}':
                print(body)
    except Exception as e:
        print(f"daemon error: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="beats - mpv player controller")
    parser.add_argument("-d", "--directory", type=str, default=None,
                        help="override music directory")
    parser.add_argument(
        "command",
        choices=[
            "play-file",
            "play-url",
            "play-by-name",
            "play-pause",
            "next",
            "prev",
            "stop",
            "seek",
            "volume",
            "status",
            "queue",
            "queue-add",
            "queue-remove",
            "queue-move",
            "queue-clear",
            "build-playlist",
            "library",
            "list-artists",
            "list-albums",
            "list-genres",
            "fetch",
            "serve",
            "init",
            "kill",
            "refresh-config",
        ],
    )
    parser.add_argument("--port", type=int, default=8090)
    parser.add_argument("--host", type=str, default="127.0.0.1")
    parser.add_argument("--index", type=int, default=0)
    parser.add_argument("--new-index", type=int, default=0)
    parser.add_argument("--seconds", type=float, default=5.0)
    parser.add_argument("--volume", type=int, default=50)
    parser.add_argument("--file", type=str, default="")
    parser.add_argument("--url", type=str, default="")
    parser.add_argument("--name", type=str, default="")
    parser.add_argument("--list", type=str, default="", dest="list_titles")
    args = parser.parse_args()

    if args.directory:
        conf = load_conf()
        conf["directory"] = os.path.expanduser(args.directory)
        _write(conf)

    if args.command == "init":
        init()
        return

    if args.command == "kill":
        kill()
        return

    if args.command == "serve":
        import asyncio
        from .web_client import BeatsWebServer
        asyncio.run(BeatsWebServer(args.port, args.host).start())
        return

    if args.command == "library":
        from .library import LibraryManager
        print(json.dumps(LibraryManager().get_library()))
        return

    if args.command in ("list-artists", "list-albums", "list-genres"):
        from .library import LibraryManager
        lib = LibraryManager()
        print(json.dumps(getattr(lib, args.command)()))
        return

    if args.command == "fetch":
        from .library import LibraryManager
        lib = LibraryManager()
        lib.build_covers()
        lib.get_library()
        print("Fetch complete.", file=sys.stderr)
        return

    daemon = {
        "play-file": ("playFile", args.file),
        "play-url": ("playUrl", args.url),
        "play-by-name": ("playByName", args.name),
        "play-pause": ("playPause", None),
        "next": ("next", None),
        "prev": ("prev", None),
        "stop": ("stop", None),
        "seek": ("seekBy", str(args.seconds)),
        "volume": ("setVolume", str(args.volume)),
        "status": ("status", None),
        "queue": ("queue", None),
        "queue-add": ("queueAdd", args.url or args.file),
        "queue-remove": ("queueRemove", str(args.index)),
        "queue-move": ("queueMove", str(args.index), str(args.new_index)),
        "queue-clear": ("queueClear", None),
        "build-playlist": ("buildPlaylist", args.list_titles),
        "refresh-config": ("refreshConfig", None),
    }
    cmd, a, *b = daemon[args.command]
    _forward(cmd, a, b[0] if b else None)
