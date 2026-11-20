# Rust harness migration — TODO

Plan: `/home/pharmaracist/.opencode/plan`
Crate: `dots/shared/home/.config/noon/scripts/rust/ai/`
Go reference (dormant later): `dots/shared/home/.config/noon/scripts/go/ai/`

## Locked decisions

- [x] All six commands in Rust, one cutover
- [x] smol / async-io only — no tokio, no compat glue
- [x] ACP: evaluated official SDK v5, rejected for wire divergence (UUID string ids, Drop-cancels
      pendings, auto-error Responders, `serde_json/preserve_order` changes key order). Raw JSON-RPC
      2.0 over `futures::io` lines instead; SDK dep removed. Revision to the original decision.
- [x] Custom `smol::process::Command` spawn + SDK-style `futures::io` line transport
- [x] Binary at `scripts/rust/ai/harness`
- [x] Go harness stays in `scripts/go/ai/` — **revised by user**: no move, no deletion.
      Only `Harness.qml:25` changes; Go remains as an on-disk reference.
- [x] Wire parity + UTF-8-safe truncation
- [x] `tracing` gated by `NOON_HARNESS_LOG`
- [x] Goldens + diff script kept in repo permanently
- [x] `rusqlite` linked to system SQLite 3.51.2
- [x] Commit built binary in dots; no installer changes
- [x] ACP verification: mock transcript diff + one real smoke test

## Phase 1 — Golden capture (Go binary)

- [x] `sessions` output
- [x] `chat` normal + edge args (limit clamp, offset, invalid id)
- [x] `skills` output
- [x] `gen-tools <shellDir>` output
- [x] `sync-config` before/after on a temp copy (never real config)
- [x] Read-only ACP transcript (`ready` → `list` → `sessions`), no prompts
- [x] `diff.sh` comparing Go vs Rust outputs with volatile fields normalized

## Phase 2 — Scaffold + pure functions

- [x] `Cargo.toml` + release profile (lto, strip, codegen-units=1, panic=abort)
- [x] `src/main.rs` clap dispatch + tracing init
- [x] `src/events.rs` wire enums + stdout emitter
- [x] `src/db.rs` sessions/chat, message parsing, truncation, skill collapse
- [x] `src/config.rs` skills, gen-tools TS emitter, JSONC cleaner, sync-config

## Phase 3 — CLI + DB parity

- [x] `cargo build --release` → `scripts/rust/ai/harness` (3.1 MB stripped)
- [x] Diff all stateless commands against goldens — **8/8 OK**
- [x] Fix divergences (negative offset clap, tool `input` raw passthrough, JSON key order)
- [x] `sync-config` byte-for-byte parity on temp copies (global + scoped)

## Phase 4 — ACP bridge

- [x] `src/acp.rs`: smol driver, child spawn, raw JSON-RPC, typed command dispatch
- [x] Raw handling of OpenCode extension notifications (`usage_update`, `plan`, etc.)
- [x] Permission flow, per-session locks, timeouts, child-exit handling
- [x] Golden ACP transcript replay against live `opencode` — **MATCH** (no prompts, no writes)

## Phase 5 — Verification & cutover

- [x] Supervisor review of all changed files — 8 findings, all fixed (see below)
- [x] One real smoke test against `opencode` v2.3.2 (ready/list/session only) — replay MATCH
- [x] `Harness.qml:25` → `Paths.scriptsDir + "/rust/ai/harness"` — **cutover done**
- [ ] Reload shell; smoke-test sidebar (sessions, chat, send, permission, model/effort/mode)
- [x] Final verification: `diff.sh --all` → 8/8 OK + ACP REPLAY MATCH on shipped binary

## Fixes made during integration (for the record)

- `diff.sh` `normalize()` used `python3 - <<'PY'` → Python ate the heredoc as its program,
  exited, closed the pipe; all comparisons were empty. Changed to `python3 -c '...'`.
- `events.rs`: `Reply.req_id` had no rename (QML sends `reqId`); `New.session_id` alias added.
- `events.rs`: missing `rename_all = "lowercase"` meant every ACP command was rejected.
- `main.rs`: clap rejected negative `offset` (`-5`); added `allow_hyphen_values`.
- Removed unused `thiserror` and SDK deps; SDK's `preserve_order` broke JSON key parity.
- `db.rs`: tool `input` now `Box<RawValue>` matching Go's `json.RawMessage`.

## Interfaces (shared contract)

```rust
db::cmd_sessions() -> anyhow::Result<()>
db::cmd_chat(session_id: &str, limit: i64, offset: i64) -> anyhow::Result<()>
config::cmd_skills() -> anyhow::Result<()>
config::cmd_gen_tools(shell_root: &str) -> anyhow::Result<()>
config::cmd_sync_config(global_cfg: &str, side_dir: &str) -> anyhow::Result<()>
acp::cmd_acp() -> anyhow::Result<()>          // smol::block_on in main.rs
events::emit(&impl serde::Serialize) -> anyhow::Result<()>
events::HarnessCommand                        // #[serde(tag = "cmd", rename_all = "lowercase")]
```

## Supervisor findings fixed

- `config.rs`: invalid UTF-8 could overwrite the real config with `{}` → `fs::read` + lossy decode.
- `config.rs`: failed `qs` exit was ignored → fall back to built-in tools on non-zero status.
- `acp.rs`: `content: null` in `tool_call_update` emitted `"null"` → now empty string.
- `acp.rs`: post-exit commands hung → `exited: AtomicBool` fails `send_raw` fast, including clean exit.
- `acp.rs`: `usage: null` emitted a zeroed event → skipped unless an object.
- `acp.rs`: stale module doc about the removed SDK → corrected.
- `diff.sh`: `--all` never tested ACP → runs `tests/acp_replay.py` against the Go golden.

## Remaining

- Reload the Quickshell session to pick up the QML change, then smoke-test the sidebar:
  session list, chat history, send, permission approve, model/effort/mode change.
- `scripts/go/ai/` — do not touch (user decision: leave in place).
- Do not commit until you ask; the whole `scripts/rust/ai/` tree is currently untracked.
