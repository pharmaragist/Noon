#!/usr/bin/env python3
"""Noon plugin store backend.

One source only: the Noon-Plugins GitHub index. Newline-delimited JSON on
stdin/stdout, one request per line. No OCS, no providers, no database.

    {"id": 1, "method": "list", "params": {"force": false}}
    {"id": 2, "method": "install", "params": {"id": "tldr"}}
"""

import json
import os
import subprocess
import sys
import time
import urllib.request

INDEX_URL = "https://raw.githubusercontent.com/pharmaragist/Noon-Plugins/dist/plugins.json"
USER_AGENT = "noon-store/2.0"
MAX_BYTES = 64 * 1024 * 1024
CACHE_TTL = 300

_plugins = None
_plugins_at = 0.0


def home():
    return os.path.expanduser("~")


def plugins_dir():
    return os.path.join(home(), ".noon_plugins")


def cache_dir():
    base = os.environ.get("XDG_CACHE_HOME") or os.path.join(home(), ".cache")
    return os.path.join(base, "noon-store")


def fetch(url, dest=None):
    req = urllib.request.Request(url, headers={"User-Agent": USER_AGENT})
    with urllib.request.urlopen(req, timeout=30) as resp:
        if dest is None:
            return resp.read(MAX_BYTES)
        os.makedirs(os.path.dirname(dest), exist_ok=True)
        tmp = dest + ".part"
        total = 0
        with open(tmp, "wb") as out:
            while True:
                chunk = resp.read(64 * 1024)
                if not chunk:
                    break
                total += len(chunk)
                if total > MAX_BYTES:
                    raise ValueError("file too large")
                out.write(chunk)
        os.replace(tmp, dest)
        return dest


def load_plugins(force=False):
    global _plugins, _plugins_at
    now = time.time()
    if not force and _plugins is not None and now - _plugins_at < CACHE_TTL:
        return _plugins

    raw = json.loads(fetch(INDEX_URL))
    plugins = []
    for p in raw.get("plugins", []):
        if not p.get("id") or not p.get("download"):
            continue
        previews = p.get("previews") or []
        plugins.append(
            {
                "id": p["id"],
                "name": p.get("name") or p["id"],
                "group": p.get("group") or "widgets",
                "description": p.get("description") or "",
                "version": p.get("version") or "",
                "maintainer": p.get("maintainer") or "",
                "icon": p.get("icon") or "",
                "preview": p.get("preview") or (previews[0] if previews else ""),
                "download": p["download"],
            }
        )

    _plugins = plugins
    _plugins_at = now
    return plugins


def installed_names(group):
    names = set()
    root = os.path.join(plugins_dir(), group)
    try:
        entries = os.listdir(root)
    except FileNotFoundError:
        return names

    for entry in entries:
        path = os.path.join(root, entry)
        if not os.path.isdir(path):
            continue
        names.add(entry.lower())
        manifest = os.path.join(path, "manifest.json")
        try:
            with open(manifest, encoding="utf-8") as f:
                name = json.load(f).get("name")
            if name:
                names.add(str(name).lower())
        except (FileNotFoundError, ValueError, OSError):
            pass
    return names


def list_plugins(force=False):
    plugins = load_plugins(force)
    installed = {}
    for group in {p["group"] for p in plugins}:
        installed[group] = installed_names(group)

    result = []
    for p in plugins:
        names = installed[p["group"]]
        result.append(
            {
                "id": p["id"],
                "name": p["name"],
                "group": p["group"],
                "description": p["description"],
                "version": p["version"],
                "maintainer": p["maintainer"],
                "icon": p["icon"],
                "preview": p["preview"],
                "installed": p["id"].lower() in names or p["name"].lower() in names,
            }
        )
    return {"plugins": result}


def install(params):
    plugin_id = params.get("id")
    plugin = next((p for p in load_plugins() if p["id"] == plugin_id), None)
    if plugin is None:
        raise ValueError("unknown plugin")

    safe = "".join(c if c.isalnum() or c in "-_." else "_" for c in plugin_id)
    archive = os.path.join(cache_dir(), safe + ".zip")
    fetch(plugin["download"], archive)

    helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "bash", "plugins_helper.sh")
    proc = subprocess.run(
        ["bash", helper, "install", archive],
        capture_output=True,
        text=True,
        timeout=180,
    )
    if proc.returncode != 0:
        message = (proc.stderr or proc.stdout or "install failed").strip()
        raise RuntimeError(message)

    return {"id": plugin_id, "installed": True}


def reply(rid, result=None, error=None):
    message = {"id": rid}
    if error is not None:
        message["error"] = {"code": "store_error", "message": str(error)}
    else:
        message["result"] = result
    print(json.dumps(message), flush=True)


def main():
    for line in sys.stdin:
        line = line.strip()
        if not line:
            continue

        rid = None
        try:
            request = json.loads(line)
            rid = request.get("id")
            method = request.get("method")
            params = request.get("params") or {}

            if method == "list":
                reply(rid, list_plugins(bool(params.get("force"))))
            elif method == "install":
                reply(rid, install(params))
            else:
                reply(rid, error="unknown method " + str(method))
        except Exception as e:  # keep serving after bad requests
            reply(rid, error=e)


if __name__ == "__main__":
    try:
        main()
    except BrokenPipeError:
        pass
