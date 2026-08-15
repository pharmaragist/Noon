#!/usr/bin/env python3
"""Backend for PackagesService.qml.

Reads package groups from ~/.noon/user/packages.json (override with
NOON_PACKAGES_JSON) and installs or checks a group's dependencies.

Usage:
    packages_service.py --install <group>
    packages_service.py --check <group>
    packages_service.py --groups
    packages_service.py --status
"""
import argparse
import json
import os
import re
import subprocess
import sys
import tarfile
from importlib import metadata

JSON_PATH = os.environ.get("NOON_PACKAGES_JSON") or os.path.expanduser("~/.noon/user/packages.json")


def load_groups():
    with open(JSON_PATH) as f:
        return json.load(f)["list"]


def find_group(name):
    wanted = name.lower().strip()
    return next((g for g in load_groups() if g["name"].lower().strip() == wanted), None)


def run(cmd):
    return subprocess.run(cmd, stdout=subprocess.DEVNULL).returncode


def emit(event):
    print(json.dumps(event), flush=True)


def missing_deps(group):
    missing = []
    if group.get("type") == "fetch":
        for dest in group.get("mirrors", {}).values():
            if not os.path.exists(os.path.expanduser(dest)):
                missing.append(dest)
        return missing
    for dep in group.get("dependencies", []):
        try:
            metadata.version(dep)
        except metadata.PackageNotFoundError:
            missing.append(dep)
    return missing


def curl_frac(line):
    m = re.search(rb"(\d+(?:\.\d+)?)%", line)
    if not m:
        return 0.0
    return min(float(m.group(1)), 100.0) / 100.0


def read_meter(stream, cb):
    buf = b""
    while True:
        chunk = stream.read(4096)
        if not chunk:
            break
        buf += chunk
        while b"\r" in buf:
            line, _, buf = buf.partition(b"\r")
            cb(curl_frac(line))
    if buf:
        cb(curl_frac(buf))


def extract_lib(archive, parent):
    
    
    
    with tarfile.open(archive) as t:
        for m in t.getmembers():
            if m.name.startswith("lib/") and m.isfile():
                src = t.extractfile(m)
                target = os.path.join(parent, os.path.basename(m.name))
                with open(target, "wb") as out:
                    out.write(src.read())
                os.chmod(target, 0o755)


def fetch_step(url, dest):
    dest = os.path.expanduser(dest)
    parent = os.path.dirname(dest)
    if parent:
        os.makedirs(parent, exist_ok=True)
    label = "fetch " + os.path.basename(dest)
    part = dest + ".part"

    def fn(cb):
        proc = subprocess.Popen(
            ["curl", "-s", "-#", "-L", "--fail", "-C", "-", "--retry", "5", "--retry-all-errors", "-o", part, url],
            stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        read_meter(proc.stderr, cb)
        if proc.wait() != 0:
            return proc.returncode
        if url.endswith((".tar.gz", ".tgz")):
            extract_lib(part, parent)
            os.unlink(part)
        else:
            os.replace(part, dest)
        return 0

    return (label, fn)


def cmd_check(name):
    group = find_group(name)
    if not group:
        print(f"error: no package group named '{name}'", file=sys.stderr)
        return 1

    missing = missing_deps(group)
    for dep in missing:
        print(dep)
    return 1 if missing else 0


def cmd_status():
    result = {}
    for group in load_groups():
        missing = missing_deps(group)
        result[group["name"]] = {"installed": not missing, "missing": missing}
    print(json.dumps(result, indent=2))
    return 0


def cmd_install(name):
    group = find_group(name)
    if not group:
        print(f"error: no package group named '{name}'", file=sys.stderr)
        return 1

    steps = []
    if group.get("type") == "fetch":
        for url, dest in group.get("mirrors", {}).items():
            steps.append(fetch_step(url, dest))
    for cmd in group.get("commands", []):
        steps.append(("running " + " ".join(cmd), lambda cb, c=cmd: run(c)))
    if group.get("type") == "python":
        for dep in group.get("dependencies", []):
            steps.append(("pip install " + dep, lambda cb, d=dep: run(["pip", "install", d])))
    for cmd in group.get("postInstallCommands", []):
        steps.append(("running " + " ".join(cmd), lambda cb, c=cmd: run(c)))

    total = len(steps)
    for i, (label, fn) in enumerate(steps):
        span_start = i / total
        span_width = 1 / total
        emit({"event": "progress", "group": name, "percent": round(span_start * 100), "message": label})
        ok = fn(lambda f: emit({"event": "progress", "group": name, "percent": round((span_start + f * span_width) * 100), "message": label}))
        if ok != 0:
            emit({"event": "error", "group": name, "message": label})
            return 1
    emit({"event": "progress", "group": name, "percent": 100, "message": "done"})
    return 0


def cmd_selftest():
    assert curl_frac(b"## 45.6% 123.4KB/s") == 0.456
    assert curl_frac(b"[##################] 100.0%") == 1.0
    assert curl_frac(b"") == 0.0
    from io import BytesIO
    calls = []
    read_meter(BytesIO(b"[#] 10.0%\r[##] 50.0%\r[###] 100.0%"), calls.append)
    assert calls == [0.1, 0.5, 1.0]
    import tarfile as _tar, tempfile as _tmp
    buf = BytesIO()
    with _tar.open(fileobj=buf, mode="w:gz") as t:
        data = b"OR-RUNTIME"
        info = _tar.TarInfo("lib/libonnxruntime.so.9.9")
        info.size = len(data)
        t.addfile(info, BytesIO(data))
    with _tmp.NamedTemporaryFile(suffix=".tgz", delete=False) as _f:
        _f.write(buf.getvalue())
        archive_path = _f.name
    try:
        with _tmp.TemporaryDirectory() as d:
            extract_lib(archive_path, d)
            assert open(os.path.join(d, "libonnxruntime.so.9.9"), "rb").read() == data
    finally:
        os.unlink(archive_path)
    g = {"type": "fetch", "mirrors": {"https://example.invalid/file": "~/.noon/.definitely_missing"}}
    assert missing_deps(g) == ["~/.noon/.definitely_missing"]
    g2 = {"type": "fetch", "mirrors": {"https://example.invalid/file": __file__}}
    assert missing_deps(g2) == []
    print("selftest ok")
    return 0


def main():
    parser = argparse.ArgumentParser(prog="packages_service")
    parser.add_argument("--install", dest="install")
    parser.add_argument("--check", dest="check")
    parser.add_argument("--groups", action="store_true")
    parser.add_argument("--status", action="store_true")
    parser.add_argument("--selftest", action="store_true")
    args = parser.parse_args()

    if args.selftest:
        return cmd_selftest()
    if args.groups:
        for g in load_groups():
            print(g["name"])
        return 0
    if args.status:
        return cmd_status()
    if args.install:
        return cmd_install(args.install)
    if args.check:
        return cmd_check(args.check)
    parser.print_help()
    return 2


if __name__ == "__main__":
    sys.exit(main())
