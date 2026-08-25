import argparse
import json
import os
import signal
import subprocess
import sys
import time

from .config import load_conf, conf_require, _write

LOG_FILE = os.path.expanduser("~/.cache/noon/beats/daemon.log")

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
    "queue-add": ("queueAdd", "add_path"),
    "queue-remove": ("queueRemove", "index"),
    "queue-move": ("queueMove", "index"),
    "queue-clear": ("queueClear", None),
    "build-playlist": ("buildPlaylist", "list_titles"),
    "refresh-config": ("refreshConfig", None),
    "preview": ("preview", "url"),
}
LOCAL_COMMANDS = ["serve", "init", "kill", "fetch", "embed-lyrics"]
HITS_COMMANDS = {"search": "query", "recommend": None, "discover": None}
LIBRARY_FIELDS = {
    "list-artists": "artist",
    "list-albums": "album",
    "list-genres": "genre",
}


def _music_dir() -> str:
    return os.path.expanduser(conf_require("directory")["directory"])


def _read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, json.JSONDecodeError) as e:
        print(f"beats: cannot read {path}: {e}", file=sys.stderr)
        sys.exit(1)


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
        if "serve" in args and any(a.endswith("beats_service.py") for a in args):
            pids.append(int(entry))
    return pids


def _daemon_script() -> str:
    return os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "beats_service.py")


def init():
    if _serve_pids():
        print("beats daemon already running.", file=sys.stderr)
        return
    os.makedirs(os.path.dirname(LOG_FILE), exist_ok=True)
    print("Starting beats daemon...", file=sys.stderr, flush=True)
    with open(LOG_FILE, "a") as log:
        subprocess.Popen(
            [sys.executable, _daemon_script(), "serve"],
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
    for _ in range(10):
        time.sleep(0.5)
        if _serve_pids():
            print("  daemon ready.", file=sys.stderr)
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
    if not _serve_pids():
        print("beats daemon is not running (start it with 'serve' or 'init').", file=sys.stderr)
        sys.exit(1)
    msg = {"command": cmd}
    if a is not None:
        msg["a"] = a
    if b is not None:
        msg["b"] = b
    path = os.path.join(_music_dir(), ".beats", "cmd.json")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w") as f:
        json.dump(msg, f)
    os.replace(tmp, path)


def _forward_hits(cmd: str, a, limit: int):
    script = os.path.join(os.path.dirname(_daemon_script()), "beats", "hits.py")
    cmd_args = [sys.executable, script, cmd]
    if cmd == "search":
        cmd_args += ["--query", a or ""]
    elif cmd == "recommend":
        cmd_args += ["--music-dir", _music_dir()]
    cmd_args += ["--limit", str(limit)]
    raise SystemExit(subprocess.run(cmd_args).returncode)


def main():
    parser = argparse.ArgumentParser(description="beats - mpv player controller")
    parser.add_argument("-d", "--directory", type=str, default=None, help="override music directory")
    parser.add_argument(
        "command",
        choices=[*DAEMON_COMMANDS, *LOCAL_COMMANDS, *LIBRARY_FIELDS, *HITS_COMMANDS, "library", "status", "queue"],
    )
    parser.add_argument("--index", type=int, default=0)
    parser.add_argument("--new-index", type=int, default=0)
    parser.add_argument("--seconds", type=float, default=5.0)
    parser.add_argument("--volume", type=int, default=50)
    parser.add_argument("--file", type=str, default="")
    parser.add_argument("--url", type=str, default="")
    parser.add_argument("--name", type=str, default="")
    parser.add_argument("--query", type=str, default="")
    parser.add_argument("--limit", type=int, default=18)
    parser.add_argument("--list", type=str, default="", dest="list_titles")
    args = parser.parse_args()

    if args.directory:
        conf = load_conf()
        conf["directory"] = os.path.expanduser(args.directory)
        _write(conf)

    if args.command == "serve":
        import asyncio
        from .daemon import BeatsDaemon

        asyncio.run(BeatsDaemon().run())
    elif args.command == "init":
        init()
    elif args.command == "kill":
        kill()
    elif args.command == "embed-lyrics":
        from . import lyrics as _lyrics

        n = _lyrics.embed_library(_music_dir())
        print(f"Embedded lyrics into {n} tracks.", file=sys.stderr)
    elif args.command == "fetch":
        from .library import LibraryManager

        lib = LibraryManager()
        lib.build_covers()
        lib.get_library()
        print("Fetch complete.", file=sys.stderr)
    elif args.command == "status":
        state = _read_json(os.path.join(_music_dir(), ".beats", "queue.json"))
        print(json.dumps(state, ensure_ascii=False, indent=2))
    elif args.command == "queue":
        state = _read_json(os.path.join(_music_dir(), ".beats", "queue.json"))
        print(json.dumps(state.get("queue", []), ensure_ascii=False))
    elif args.command == "library":
        tracks = _read_json(os.path.join(_music_dir(), ".beats", "library.json"))
        print(json.dumps(tracks, ensure_ascii=False))
    elif args.command in LIBRARY_FIELDS:
        tracks = _read_json(os.path.join(_music_dir(), ".beats", "library.json"))
        field = LIBRARY_FIELDS[args.command]
        values = sorted({t[field] for t in tracks if t.get(field)})
        print(json.dumps(values, ensure_ascii=False))
    elif args.command in HITS_COMMANDS:
        _forward_hits(args.command, args.query, args.limit)
    else:
        daemon_cmd, arg_field = DAEMON_COMMANDS[args.command]
        a = getattr(args, arg_field) if arg_field else None
        if arg_field == "add_path":
            a = args.url or args.file
        b = args.new_index if args.command == "queue-move" else None
        _forward(daemon_cmd, a, b)


if __name__ == "__main__":
    main()
