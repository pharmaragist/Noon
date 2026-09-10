#!/usr/bin/env python3

import json
import os
import subprocess
import sys
from configparser import ConfigParser
from pathlib import Path


ICON_BASE_DIRS = [
    Path("/usr/share/icons"),
    Path.home() / ".local/share/icons",
    Path.home() / ".icons",
]


def run_cmd(args):
    try:
        res = subprocess.run(args, capture_output=True, text=True, timeout=2)
        return res.stdout.strip() if res.returncode == 0 else None
    except Exception:
        return None


def get_current_themes():
    qt = run_cmd(["kreadconfig6", "--group", "Icons", "--key", "Theme"]) or run_cmd(
        ["kreadconfig5", "--group", "Icons", "--key", "Theme"]
    )

    gtk = None
    gtk3 = Path.home() / ".config" / "gtk-3.0" / "settings.ini"
    if gtk3.exists():
        try:
            cfg = ConfigParser()
            cfg.read(gtk3)
            gtk = cfg.get("Settings", "gtk-icon-theme-name", fallback=None)
        except Exception:
            pass

    if not gtk:
        val = run_cmd(["gsettings", "get", "org.gnome.desktop.interface", "icon-theme"])
        gtk = val.strip("'\"") if val else None

    return qt, gtk


def find_theme_dir(theme_id):
    for base in ICON_BASE_DIRS:
        candidate = base / theme_id
        if (candidate / "index.theme").exists():
            return candidate
    return None


def find_icon_in_theme(theme_id, icon_name, visited=None):
    if visited is None:
        visited = set()
    if theme_id in visited:
        return None
    visited.add(theme_id)

    theme_dir = find_theme_dir(theme_id)
    if theme_dir is None:
        return None

    cfg = ConfigParser()
    try:
        cfg.read(theme_dir / "index.theme")
    except Exception:
        return None
    if "Icon Theme" not in cfg:
        return None

    directories = [
        d.strip() for d in cfg["Icon Theme"].get("Directories", "").split(",") if d.strip()
    ]

    scalable = []
    other = []
    for d in directories:
        section = cfg[d] if d in cfg else {}
        entry_type = section.get("Type", "Threshold")
        (scalable if entry_type == "Scalable" else other).append(d)

    for d in scalable + other:
        for ext in ("svg", "png", "xpm"):
            candidate = theme_dir / d / f"{icon_name}.{ext}"
            if candidate.exists():
                return str(candidate)

    inherits = [
        t.strip() for t in cfg["Icon Theme"].get("Inherits", "").split(",") if t.strip()
    ]
    for parent in inherits:
        found = find_icon_in_theme(parent, icon_name, visited)
        if found:
            return found

    if theme_id != "hicolor":
        return find_icon_in_theme("hicolor", icon_name, visited)

    return None


def get_icon_themes():
    qt_curr, gtk_curr = get_current_themes()
    unique_themes = {}

    for d in ICON_BASE_DIRS:
        if not d.is_dir():
            continue
        for t_dir in d.iterdir():
            t_id = t_dir.name
            if t_id in unique_themes or not t_dir.is_dir():
                continue

            idx = t_dir / "index.theme"
            if not idx.exists():
                continue

            try:
                cfg = ConfigParser()
                cfg.read(idx)
                if "Icon Theme" in cfg:
                    sect = cfg["Icon Theme"]
                    if (t_dir / "cursors").exists() and not sect.get(
                        "Directories", ""
                    ).strip():
                        continue

                    unique_themes[t_id] = {
                        "id": t_id,
                        "name": sect.get("Name", t_id),
                        "current": t_id in (qt_curr, gtk_curr),
                        "preview": find_icon_in_theme(t_id, "folder"),
                    }
            except Exception:
                continue

    return sorted(unique_themes.values(), key=lambda x: x["name"].lower())


def set_theme(t_id):
    qt = (
        run_cmd(["kwriteconfig6", "--group", "Icons", "--key", "Theme", t_id])
        is not None
        or run_cmd(["kwriteconfig5", "--group", "Icons", "--key", "Theme", t_id])
        is not None
    )

    gtk3 = Path.home() / ".config" / "gtk-3.0" / "settings.ini"
    gtk3.parent.mkdir(parents=True, exist_ok=True)
    try:
        cfg = ConfigParser()
        if gtk3.exists():
            cfg.read(gtk3)
        if "Settings" not in cfg:
            cfg["Settings"] = {}
        cfg["Settings"]["gtk-icon-theme-name"] = t_id
        with open(gtk3, "w") as f:
            cfg.write(f)
        gtk_f = True
    except Exception:
        gtk_f = False

    gtk_g = (
        run_cmd(["gsettings", "set", "org.gnome.desktop.interface", "icon-theme", t_id])
        is not None
    )

    res = {
        "theme": t_id,
        "qt": qt,
        "gtk": gtk_f or gtk_g,
        "success": qt or gtk_f or gtk_g,
    }
    print(json.dumps(res, indent=2))
    return 0 if res["success"] else 1


def main():
    if len(sys.argv) < 2:
        print("Usage: icon-theme-manager.py {list|set <theme-id>}", file=sys.stderr)
        return 1

    cmd = sys.argv[1].lower()
    if cmd == "list":
        print(json.dumps(get_icon_themes(), indent=2))
        return 0
    elif cmd == "set" and len(sys.argv) >= 3:
        return set_theme(sys.argv[2])

    print("Error: Invalid command or missing argument", file=sys.stderr)
    return 1


if __name__ == "__main__":
    sys.exit(main())
