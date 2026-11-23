#!/usr/bin/python3
# save the current Kitty session for startup_session

import json
import os
import subprocess
import sys
import datetime

SESSION_FILE = os.path.expanduser("~/.config/kitty/last_session.conf")
LOG_FILE = "/tmp/kitty_session_save.log"


def log(msg):
    ts = datetime.datetime.now().strftime("%H:%M:%S")
    with open(LOG_FILE, "a") as f:
        f.write(f"[{ts}] {msg}\n")


def find_kitty_socket():
    if "KITTY_LISTEN_ON" in os.environ:
        return os.environ["KITTY_LISTEN_ON"]

    pids = subprocess.run(
        ["pgrep", "-x", "kitty"], capture_output=True, text=True
    ).stdout.strip().splitlines()

    for pid in pids:
        for check_pid in [pid]:
            try:
                with open(f"/proc/{check_pid}/environ", "rb") as f:
                    env_data = f.read().decode("utf-8", errors="replace")
                for item in env_data.split("\x00"):
                    if item.startswith("KITTY_LISTEN_ON="):
                        return item.split("=", 1)[1]
            except (PermissionError, FileNotFoundError):
                pass

        children = subprocess.run(
            ["pgrep", "-P", pid], capture_output=True, text=True
        ).stdout.strip().splitlines()
        for cpid in children:
            try:
                with open(f"/proc/{cpid}/environ", "rb") as f:
                    env_data = f.read().decode("utf-8", errors="replace")
                for item in env_data.split("\x00"):
                    if item.startswith("KITTY_LISTEN_ON="):
                        return item.split("=", 1)[1]
            except (PermissionError, FileNotFoundError):
                pass

    try:
        with open("/proc/net/unix") as f:
            for line in f:
                parts = line.strip().split()
                if parts:
                    name = parts[-1]
                    if name.startswith("@kitty-") and name[7:].isdigit():
                        return f"unix:{name}"
    except (PermissionError, FileNotFoundError):
        pass

    return None


def main():
    socket = find_kitty_socket()
    if not socket:
        log("No running kitty instance found.")
        sys.exit(0)

    cmd = ["kitty", "@", f"--to={socket}", "ls"]
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, timeout=5)
    except Exception as e:
        log(f"ERROR running kitty @ ls: {e}")
        sys.exit(1)

    if result.returncode != 0:
        log(f"kitty @ ls failed (rc={result.returncode}): {result.stderr.strip()}")
        sys.exit(1)

    try:
        data = json.loads(result.stdout)
    except json.JSONDecodeError as e:
        log(f"JSON parse error: {e}")
        sys.exit(1)

    if not data:
        log("No OS windows found.")
        sys.exit(0)

    focused_win = next((w for w in data if w.get("is_focused")), data[0])
    tabs = focused_win.get("tabs", [])

    if not tabs:
        log("No tabs in focused window.")
        sys.exit(0)

    lines = []

    for i, tab in enumerate(tabs):
        title = (tab.get("title") or "shell").strip()
        is_active = tab.get("is_active", False)
        layout = tab.get("layout", "stack")
        layout_name = layout.split(":")[0] if ":" in layout else layout

        windows = tab.get("windows", [])

        lines.append(f"new_tab {title}")
        lines.append(f"layout {layout_name}")

        if not windows:
            lines.append(f"cd {os.path.expanduser('~')}")
            lines.append("launch")
        else:
            for win in windows:
                cwd = win.get("cwd", "")
                if not cwd or not os.path.isdir(cwd):
                    cwd = os.path.expanduser("~")
                lines.append(f"cd {cwd}")
                lines.append("launch")

        if is_active:
            lines.append(f"focus_tab {i}")

    content = "\n".join(lines) + "\n"

    tmp = SESSION_FILE + ".tmp"
    with open(tmp, "w") as f:
        f.write(content)
    os.rename(tmp, SESSION_FILE)

    tab_count = sum(1 for l in lines if l.startswith("new_tab"))
    log(f"Saved {tab_count} tabs → {SESSION_FILE}")
    print(f"Session saved: {tab_count} tabs")


if __name__ == "__main__":
    main()
