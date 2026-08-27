import json
import os
import time
from concurrent.futures import ThreadPoolExecutor, as_completed

from beats import lyrics


def main(music_dir: str, limit: int = 0, workers: int = 5):
    lib_path = os.path.join(music_dir, ".beats", "library.json")
    with open(lib_path, encoding="utf-8") as f:
        tracks = json.load(f)

    todo = []
    for t in tracks:
        if not t.get("title"):
            continue
        rel = t.get("file", "")
        lrc_path = os.path.join(music_dir, ".beats", "lyrics", os.path.splitext(rel)[0] + ".lrc")
        if not os.path.isfile(lrc_path):
            todo.append(t)

    if limit:
        todo = todo[:limit]

    total = len(todo)
    print(f"{len(tracks)} tracks | {total} without lyrics | {workers} workers")
    if not total:
        return

    found = 0
    start = time.time()

    def work(t):
        return t, lyrics.get_lyrics(t["title"], t.get("artist", ""), music_dir, t["file"], False, float(t.get("duration") or 0))

    with ThreadPoolExecutor(max_workers=workers) as pool:
        futures = {pool.submit(work, t): t for t in todo}
        for i, fut in enumerate(as_completed(futures), 1):
            t, text = fut.result()
            found += 1 if text else 0
            mark = "+" if text else "-"
            eta = (time.time() - start) / i * (total - i)
            print(f"[{i}/{total}] {mark} {t['title'][:40]}  (eta {int(eta)}s)", flush=True)

    print(f"fetched {found}/{total}. done.")
