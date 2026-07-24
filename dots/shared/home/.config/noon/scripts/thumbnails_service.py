#!/usr/bin/env python3

import fcntl
import hashlib
import json
import os
import subprocess
import sys
import tempfile
from multiprocessing import Pool
from pathlib import Path

import click
from loguru import logger
from PIL import Image
from PIL.PngImagePlugin import PngInfo
from tqdm import tqdm

VIDEO_EXTENSIONS = {".mp4", ".webm", ".mkv", ".mov", ".avi", ".m4v"}

THUMBNAIL_CACHE = Path.home() / ".cache" / "thumbnails"
SIZE = 512
SIZE_DIR = "x-large"

logger.remove()
logger.add(sys.stdout, level="INFO")
logger.add("/tmp/thumbnails_service.log", level="DEBUG", rotation="100 MB")

LOCK_FILE = "/tmp/thumbnails_service.lock"
_lock_fh = None


def acquire_lock() -> None:
    global _lock_fh
    _lock_fh = open(LOCK_FILE, "w")
    try:
        fcntl.flock(_lock_fh, fcntl.LOCK_EX | fcntl.LOCK_NB)
    except BlockingIOError:
        logger.error("Another instance is already running. Exiting.")
        sys.exit(1)


def release_lock() -> None:
    if _lock_fh:
        fcntl.flock(_lock_fh, fcntl.LOCK_UN)
        _lock_fh.close()


def get_thumbnail_path(uri: str) -> Path:
    md5 = hashlib.md5(uri.encode()).hexdigest()
    return THUMBNAIL_CACHE / SIZE_DIR / f"{md5}.png"


def ensure_cache_dir() -> None:
    (THUMBNAIL_CACHE / SIZE_DIR).mkdir(parents=True, exist_ok=True)


def make_video_thumbnail(fpath: str) -> bool:
    mtime = os.path.getmtime(fpath)
    uri = Path(fpath).resolve().as_uri()

    fd, tmppath = tempfile.mkstemp(suffix=".png")
    os.close(fd)
    try:
        subprocess.run(
            ["ffmpeg", "-y", "-i", fpath, "-vframes", "1", "-an", tmppath],
            capture_output=True,
            timeout=30,
            check=True,
        )
        img = Image.open(tmppath)
        img.thumbnail((SIZE, SIZE), Image.LANCZOS)

        metadata = PngInfo()
        metadata.add_text("Thumb::URI", uri)
        metadata.add_text("Thumb::MTime", str(int(mtime)))
        metadata.add_text("Software", "Noon Thumbnails")

        save_path = get_thumbnail_path(uri)
        save_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(save_path), format="PNG", pnginfo=metadata)

        logger.debug("OK          {}", uri)
        return True
    except Exception:
        logger.debug("ERROR       {}", uri)
        return False
    finally:
        if os.path.exists(tmppath):
            os.unlink(tmppath)


def make_image_thumbnail(fpath: str) -> bool:
    mtime = os.path.getmtime(fpath)
    uri = Path(fpath).resolve().as_uri()

    try:
        img = Image.open(fpath)
        img.thumbnail((SIZE, SIZE), Image.LANCZOS)

        metadata = PngInfo()
        metadata.add_text("Thumb::URI", uri)
        metadata.add_text("Thumb::MTime", str(int(mtime)))
        metadata.add_text("Software", "Noon Thumbnails")

        save_path = get_thumbnail_path(uri)
        save_path.parent.mkdir(parents=True, exist_ok=True)
        img.save(str(save_path), format="PNG", pnginfo=metadata)

        logger.debug("OK          {}", uri)
        return True
    except Exception:
        logger.debug("ERROR       {}", uri)
        return False


def make_thumbnail(fpath: str) -> bool:
    if Path(fpath).suffix.lower() in VIDEO_EXTENSIONS:
        return make_video_thumbnail(fpath)
    return make_image_thumbnail(fpath)


@logger.catch()
def thumbnail_folder(
    *,
    dir_path: Path,
    workers: int,
    only_images: bool,
    recursive: bool,
    machine_progress: bool = False,
) -> None:
    _clean_dir_orphans(dir_path)
    all_files = get_all_files(dir_path=dir_path, recursive=recursive)
    if only_images:
        all_files = get_all_images(all_files=all_files)

    sidecar = _load_dir_sidecar(dir_path)
    existing = sidecar.get("files", {})

    pending = []
    for fpath in all_files:
        rel = str(fpath.resolve().relative_to(dir_path.resolve()))
        entry = existing.get(rel)
        # ponytail: stat is cheaper than PNG metadata read; sidecar mtime is authoritative
        if entry and int(entry.get("mtime", 0)) == int(fpath.stat().st_mtime):
            if (THUMBNAIL_CACHE / SIZE_DIR / f"{entry['hash']}.png").exists():
                logger.debug("FRESH       {}", fpath.as_uri())
                continue
        pending.append(fpath)

    if not pending:
        logger.info("All thumbnails are up to date.")
        return

    all_files = [str(fpath) for fpath in pending]
    if machine_progress:
        completed = 0
        total = len(all_files)
        with Pool(processes=workers) as p:
            for _ in p.imap(make_thumbnail, all_files):
                completed += 1
                print(f"PROGRESS {completed}/{total} FILE {all_files[completed - 1]}")
                sys.stdout.flush()
    else:
        with Pool(processes=workers) as p:
            list(tqdm(p.imap(make_thumbnail, all_files), total=len(all_files)))
    _rebuild_dir_sidecar(dir_path, [Path(f) for f in all_files])


def get_all_images(*, all_files):
    img_suffixes = [".jpg", ".jpeg", ".png", ".gif"]
    all_images = [fpath for fpath in all_files if fpath.suffix in img_suffixes]
    print("Found {} images".format(len(all_images)))
    return all_images


def get_all_files(*, dir_path: Path, recursive: bool):
    if not (dir_path.exists() and dir_path.is_dir()):
        raise ValueError(
            "{} doesn't exist or isn't a valid directory!".format(dir_path.resolve())
        )
    if recursive:
        all_files = dir_path.rglob("*")
    else:
        all_files = dir_path.glob("*")
    all_files = [fpath for fpath in all_files if fpath.is_file()]
    print(
        "Found {} files in the directory: {}".format(len(all_files), dir_path.resolve())
    )
    return all_files


SIDECAR_FILENAME = ".thumbnails.json"


def _load_dir_sidecar(dir_path: Path) -> dict:
    path = dir_path / SIDECAR_FILENAME
    try:
        return json.loads(path.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {"version": 1, "files": {}}


def _save_dir_sidecar(dir_path: Path, data: dict) -> None:
    (dir_path / SIDECAR_FILENAME).write_text(json.dumps(data, indent=2))


def _clean_dir_orphans(dir_path: Path) -> None:
    sidecar = _load_dir_sidecar(dir_path)
    files = sidecar.get("files", {})
    if not files:
        return

    stale = []
    for rel, info in files.items():
        fpath = (dir_path / rel).resolve()
        mtime = int(info.get("mtime", 0))
        if not fpath.exists() or str(int(fpath.stat().st_mtime)) != str(mtime):
            stale.append(rel)
            md5 = info.get("hash") or hashlib.md5(info.get("uri", "").encode()).hexdigest()
            (THUMBNAIL_CACHE / SIZE_DIR / f"{md5}.png").unlink(missing_ok=True)

    for rel in stale:
        del files[rel]

    if stale:
        _save_dir_sidecar(dir_path, sidecar)


def _rebuild_dir_sidecar(dir_path: Path, all_files) -> None:
    sidecar = _load_dir_sidecar(dir_path)
    files = sidecar.setdefault("files", {})
    for fpath in all_files:
        if isinstance(fpath, str):
            fpath = Path(fpath)
        rel = str(fpath.resolve().relative_to(dir_path.resolve()))
        uri = fpath.resolve().as_uri()
        hash_val = hashlib.md5(uri.encode()).hexdigest()
        thumb_path = get_thumbnail_path(uri)
        files[rel] = {
            "hash": hash_val,
            "mtime": int(fpath.stat().st_mtime),
            "fileName": fpath.name,
            "uri": uri,
            "thumbnailPath": str(thumb_path),
            "thumbnailUri": thumb_path.as_uri(),
        }
    _save_dir_sidecar(dir_path, sidecar)


@click.command()
@click.option(
    "-d",
    "--img_dirs",
    required=True,
    help='directories to generate thumbnails, space-separated: "dir1 dir2"',
)
@click.option(
    "-w",
    "--workers",
    default=None,
    type=int,
    help="number of CPU workers (default: all cores)",
)
@click.option(
    "-i",
    "--only_images",
    is_flag=True,
    default=False,
    help="only thumbnail images, skip videos",
)
@click.option(
    "-r",
    "--recursive",
    is_flag=True,
    default=False,
    help="recurse into subdirectories",
)
@click.option(
    "--machine_progress",
    is_flag=True,
    default=False,
    help="print machine-readable progress lines",
)
def main(
    img_dirs: str,
    workers: int,
    only_images: bool,
    recursive: bool,
    machine_progress: bool,
) -> None:
    acquire_lock()
    ensure_cache_dir()
    try:
        for img_dir in [Path(d) for d in img_dirs.split()]:
            thumbnail_folder(
                dir_path=img_dir,
                workers=workers,
                only_images=only_images,
                recursive=recursive,
                machine_progress=machine_progress,
            )
        print("Thumbnail Generation Completed!")
    finally:
        release_lock()


if __name__ == "__main__":
    main()
