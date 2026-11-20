# Script rules

- `bin/` — compiled binaries only (Go, Rust, …). Builds output here, never into `go/` or `rust/`.
- `python/` — Python files plus one `requirements.txt` with every third-party import.
- `bash/` — shell scripts. `go/`, `rust/`, `terminal/` hold sources/data, not entry points.
- Filenames have no `_service` suffix.
- QML never builds script paths by hand — use `Paths.scripts.<key>`; add the key in `Paths.qml`.
- Delete a script → delete its key and every call site. No dead paths.
- Calendar/Todo stay local (`Mem.todo`); no OAuth or sync.
