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

# cli command -> (daemon cmd, arg field or None); None args mean no parameter
DAEMON_COMMANDS = {
    "play-file": ("playFile", "file"),
    "play-url": ("playUrl", "url"),
    "play-by-name": ("playByName", "name"),
    "play-pause": ("playPause", None),
    "next": ("next", None),
    "prev": ("prev", None),
    "stop": ("stop", None),
    "seek": ("seekBy", "seconds"),
    "volume": ("setVolume", "volume"),
    "status": ("status", None),
    "queue": ("queue", None),
    "queue-add": ("queueAdd", "add_path"),
    "queue-remove": ("queueRemove", "index"),
    "queue-move": ("queueMove", "index"),  # + new-index
    "queue-clear": ("queueClear", None),
    "build-playlist": ("buildPlaylist", "list_titles"),
    "refresh-config": ("refreshConfig", None),
}
LOCAL_COMMANDS = ["serve", "init", "kill", "fetch"]
LIBRARY_COMMANDS = ["library", "list-artists", "list-albums", "list-genres"]


def _proc_args(pid: int) -> list:
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            return [a.decode(errors="replace") for a in f.read().split(b"\0") if a]
    except OSError:
        return []


def _serve_pids() -> list:
    pids = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        args = _proc_args(int(entry))
        if "serve" in args and any(
            a.endswith("beats_service.py") for a in args
        ):
            pids.append(int(entry))
    return pids


def _daemon_script() -> str:
    return os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "beats_service.py",
    )


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
        try:
            os.kill(pid, signal.SIGKILL)
        except (ProcessLookupError, PermissionError):
            pass
    time.sleep(1)
    print("All stopped.", file=sys.stderr)


def _forward(cmd: str, a=None, b=None):
    port = conf_require("webClientPort")["webClientPort"]
    if not _serve_pids():
        print(
            "beats daemon is not running (start it with 'serve' or 'init').",
            file=sys.stderr,
        )
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
            if body != '{"ok": true}':
                print(body)
    except Exception as e:
        print(f"daemon error: {e}", file=sys.stderr)
        sys.exit(1)


def main():
    parser = argparse.ArgumentParser(description="beats - mpv player controller")
    parser.add_argument("-d", "--directory", type=str, default=None,
                        help="override music directory")
    parser.add_argument("command",
                        choices=[*DAEMON_COMMANDS, *LOCAL_COMMANDS, *LIBRARY_COMMANDS])
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

    if args.command == "serve":
        import asyncio
        from .web_client import BeatsWebServer
        asyncio.run(BeatsWebServer(args.port, args.host).start())
    elif args.command == "init":
        init()
    elif args.command == "kill":
        kill()
    elif args.command == "fetch":
        from .library import LibraryManager
        lib = LibraryManager()
        lib.build_covers()
        lib.get_library()
        print("Fetch complete.", file=sys.stderr)
    elif args.command in LIBRARY_COMMANDS:
        from .library import LibraryManager
        attr = args.command.replace("-", "_")
        print(json.dumps(getattr(LibraryManager(), attr)()))
    else:
        daemon_cmd, arg_field = DAEMON_COMMANDS[args.command]
        a = getattr(args, arg_field) if arg_field else None
        if arg_field == "add_path":
            a = args.url or args.file
        b = str(args.new_index) if args.command == "queue-move" else None
        _forward(daemon_cmd,
                 str(a) if isinstance(a, int) else a,
                 b)
