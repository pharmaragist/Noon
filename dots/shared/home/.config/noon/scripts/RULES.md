# Script rules

- `bin/` — compiled binaries only. Rust: `cargo ship` in `rust/` and `rust/harness/`.
- Shared Rust helpers live in `rust/utils/`; binaries import them with `mod utils;`.
- Rust does the work in-process: use crates for archives, images, video, INI, HTTP. Shell out only to external tools with no crate equivalent (`matugen`, pickers, `plasmapkg2`).
- `python/` — Python files plus one `requirements.txt` with every third-party import.
- `bash/` — shell scripts. `go/`, `rust/`, `terminal/` hold sources/data, not entry points.
- Filenames have no `_service` suffix.
- QML never builds script paths by hand — use `Paths.scripts.<key>`; add the key in `Paths.qml`.
- Delete a script → delete its key and every call site. No dead paths.
- Calendar/Todo stay local (`Mem.todo`); no OAuth or sync.
