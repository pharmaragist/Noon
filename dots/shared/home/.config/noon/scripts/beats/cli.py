import argparse
import fcntl
import json
import os
import signal
import subprocess
import sys
import time

import mpd

from .config import load_conf
from .library import LibraryManager
from .player import Player

MPD_SOCK_DIR = os.path.expanduser("~/.cache/noon/beats/mpd")


def _mpd_ping(sock: str, timeout: float = 3) -> bool:
    try:
        c = mpd.MPDClient()
        c.timeout = timeout
        c.connect(sock, 0)
        c.ping()
        c.disconnect()
        return True
    except Exception:
        return False


def _wait_for_mpd(sock: str, max_sec: int = 15) -> bool:
    for _ in range(max_sec * 2):
        if _mpd_ping(sock):
            return True
        time.sleep(0.5)
    return False


def _mpd_conf(name: str, host: str, music_dir: str) -> str:
    sock_dir = os.path.dirname(host)
    os.makedirs(sock_dir, exist_ok=True)
    return (
        f'music_directory "{music_dir}"\n'
        f'db_file "{os.path.join(sock_dir, name)}.db"\n'
        f'pid_file "{os.path.join(sock_dir, name)}.pid"\n'
        f'log_file "{os.path.join(sock_dir, name)}.log"\n'
        f'bind_to_address "{host}"\n'
        'restore_paused "yes"\n'
        'auto_update "yes"\n'
        'audio_output {\n'
        '  type "pipewire"\n'
        f'  name "{name}"\n'
        '}\n'
    )


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


def _mpd_pids(name: str | None = None) -> list:
    """PIDs of mpd daemons we manage (conf file lives under MPD_SOCK_DIR)."""
    pids = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        args = _proc_args(pid)
        if not args or os.path.basename(args[0]) != "mpd":
            continue
        confs = [a for a in args if a.startswith(MPD_SOCK_DIR) and a.endswith(".conf")]
        if not confs:
            continue
        if name is None or any(os.path.basename(c) == f"{name}.conf" for c in confs):
            pids.append(pid)
    return pids


def _bridge_pids(host: str | None = None) -> list:
    """PIDs of mpd-mpris bridges talking to our sockets (optionally one host)."""
    pids = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        args = _proc_args(pid)
        if not args or "mpd-mpris" not in args[0]:
            continue
        if host is not None:
            if host not in args:
                continue
        elif not any(a.startswith(MPD_SOCK_DIR) for a in args):
            continue
        pids.append(pid)
    return pids


def _serve_pids() -> list:
    """PIDs of running beats web servers (beats_daemon.py serve)."""
    pids = []
    for entry in os.listdir("/proc"):
        if not entry.isdigit():
            continue
        pid = int(entry)
        args = _proc_args(pid)
        if not args or "serve" not in args:
            continue
        if any(a.endswith("beats_daemon.py") for a in args):
            pids.append(pid)
    return pids


def _ensure_mpd(name: str, host: str, music_dir: str):
    if _mpd_ping(host):
        for pid in _mpd_pids(name)[1:]:
            _kill_pid(pid)
        return

    os.makedirs(MPD_SOCK_DIR, exist_ok=True)
    with open(os.path.join(MPD_SOCK_DIR, f"{name}.lock"), "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        if _mpd_ping(host):
            return

        for pid in _mpd_pids(name):
            _kill_pid(pid)
        if os.path.exists(host):
            os.remove(host)

        print(f"Starting MPD ({name}) on {host}...", file=sys.stderr, flush=True)
        conf = _mpd_conf(name, host, music_dir)
        conf_file = os.path.join(os.path.dirname(host), f"{name}.conf")
        with open(conf_file, "w") as f:
            f.write(conf)
        subprocess.Popen(
            ["mpd", conf_file],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )

    if _wait_for_mpd(host):
        print(f"  {name} ready.", file=sys.stderr, flush=True)
    else:
        print(f"  Failed to start MPD ({name}).", file=sys.stderr, flush=True)
        sys.exit(1)


BRIDGE_BIN = "mpd-mpris"


def _ensure_mpd_mpris(socket_path: str):
    if _bridge_pids(socket_path):
        return

    print("Starting MPRIS bridge...", file=sys.stderr, flush=True)
    subprocess.Popen(
        [BRIDGE_BIN, "-network", "unix", "-host", socket_path, "-no-instance"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
    )
    time.sleep(1)


def init(player: str):
    conf = load_conf()
    players = conf.get("players", {})
    for name, pconf in players.items():
        if "host" not in pconf:
            continue
        music_dir = os.path.expanduser(pconf.get("musicDirectory", "~/Music"))
        host = os.path.expanduser(pconf["host"])
        _ensure_mpd(name, host, music_dir)

    pconf = players.get(player, {})
    host = os.path.expanduser(pconf.get("host", os.path.join(MPD_SOCK_DIR, "main_socket")))
    _ensure_mpd_mpris(host)
    print("Init complete. Run 'beats serve' to start the web UI.", file=sys.stderr, flush=True)


def kill():
    for pid in _mpd_pids() + _bridge_pids() + _serve_pids():
        _kill_pid(pid)
    time.sleep(1)

    for sock in os.listdir(MPD_SOCK_DIR):
        path = os.path.join(MPD_SOCK_DIR, sock)
        if os.path.exists(path) and (sock.endswith("_socket") or sock == "socket"):
            os.remove(path)

    print("All stopped.", file=sys.stderr, flush=True)


def main():
    parser = argparse.ArgumentParser(description="beats - MPD controller")
    parser.add_argument("--player", type=str, default="main")
    parser.add_argument("--port", type=int, default=8090)
    parser.add_argument("--host", type=str, default="127.0.0.1")
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
        ],
    )
    parser.add_argument("--index", type=int, default=0)
    parser.add_argument("--new-index", type=int, default=0)
    parser.add_argument("--seconds", type=float, default=5.0)
    parser.add_argument("--volume", type=int, default=50)
    parser.add_argument("--file", type=str, default="")
    parser.add_argument("--url", type=str, default="")
    parser.add_argument("--name", type=str, default="")
    parser.add_argument("--list", type=str, default="", dest="list_titles")
    args = parser.parse_args()

    if args.command == "init":
        init(args.player)
        return

    if args.command == "kill":
        kill()
        return

    if args.command == "serve":
        conf = load_conf()
        pconf = conf.get("players", {}).get(args.player)
        if pconf and "host" in pconf:
            music_dir = os.path.expanduser(pconf.get("musicDirectory", "~/Music"))
            host = os.path.expanduser(pconf["host"])
            _ensure_mpd(args.player, host, music_dir)
            _ensure_mpd_mpris(host)
        import asyncio
        from .web_client import BeatsWebServer
        asyncio.run(BeatsWebServer(args.player, args.port, args.host).start())
        return

    conf = load_conf()
    pconf = conf.get("players", {}).get(args.player)
    if pconf:
        music_dir = os.path.expanduser(pconf.get("musicDirectory", "~/Music"))
        host = os.path.expanduser(pconf["host"])
        _ensure_mpd(args.player, host, music_dir)
        _ensure_mpd_mpris(host)

    p = Player(args.player)
    lib = LibraryManager(args.player)

    dispatch = {
        "play-file": lambda: p.play_file(args.file),
        "play-url": lambda: p.play_url(args.url),
        "play-by-name": lambda: p.play_by_name(args.name),
        "play-pause": p.play_pause,
        "next": p.next,
        "prev": p.prev,
        "stop": p.stop,
        "seek": lambda: p.seek(args.seconds),
        "volume": lambda: p.set_volume(args.volume),
        "status": lambda: print(json.dumps(p.status())),
        "queue": lambda: print(json.dumps(p.get_queue())),
        "queue-add": lambda: p.queue_add(args.url or args.file),
        "queue-remove": lambda: p.queue_remove(args.index),
        "queue-move": lambda: p.queue_move(args.index, args.new_index),
        "queue-clear": p.queue_clear,
        "build-playlist": lambda: p.build_playlist(args.list_titles),
        "library": lambda: print(json.dumps(lib.get_library())),
        "list-artists": lambda: print(json.dumps(lib.list_artists())),
        "list-albums": lambda: print(json.dumps(lib.list_albums())),
        "list-genres": lambda: print(json.dumps(lib.list_genres())),
        "fetch": lambda: (lib.update_db(), lib.build_covers(), print("Fetch complete.", file=sys.stderr)),
    }
    dispatch[args.command]()


if __name__ == "__main__":
    main()
