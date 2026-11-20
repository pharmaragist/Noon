# ACP feature expansion — TODO

Crate: `dots/shared/home/.config/noon/scripts/rust/ai/`
UI: `dots/shared/home/.config/noon/services/Harness.qml`
Reference: `../go/ai/acp.go`, ACP v1 spec, OpenCode v2.3.2 probe results.

## Governing rule

**When a feature can live in either QML or the Rust harness, it lives in the harness.**
QML only collects raw inputs (paths, ids, text) and renders typed events. No file
reading, base64, MIME detection, capability checks, or protocol logic in QML.
Attachments are **native**: QML passes paths; the harness reads, classifies, encodes
and sends ACP content blocks.

## Weighing: what actually needs to be in the sidechat

| Feature | Sidechat UI? | Backend work | Priority |
|---|---|---|---|
| Permission option choice (allow once/always) | **Yes** — dialog buttons | none (already supported) | P0 |
| `elicitation.create` form (question tool) | **Yes** — render schema as form | declare `elicitation.form`, reply | P0 |
| Native attachments | **Yes** — file picker + drag/drop only | read/encode/attach in Rust | P0 |
| `user_message_chunk` → `message.updated` | no — QML handler already exists | emit event | P0 |
| Steer a running turn (`_session/steering`) | **Yes** — button on running composer | send private request | P1 |
| Compaction updates | small status indicator | declare `session.compaction`, handle updates | P1 |
| Child-session updates | **Yes** — show subagent activity | declare `_meta` cap, handle notification | P1 |
| usage cost (`usage_update.cost`) | optional cost label | extend `context` event | P1 |
| MCP servers (`mcpServers: []` today) | no | read opencode config, pass stdio/http only | P1 |
| Session close / delete / fork | **Yes** — session menu | send methods | P2 |
| `session/load` | no (DB `chat` already covers history) | method support | P2 |
| `$/cancel_request`, generic `-32601` | no | robustness | P2 |
| auth / terminal / fs / terminal-tools | no | OpenCode has no call sites — skip | skip |
| plan / notice / sse MCP / audio | no | OpenCode never emits or advertises — skip | skip |

## Wire contract (fixed — both sides build to this)

### Commands QML → harness

```jsonc
{"cmd":"send","sessionId":"...","cwd":"...","text":"...","attachments":["/path/a.png","file:///path/b.txt"],"model":"","effort":"","mode":""}
{"cmd":"elicit","reqId":123,"accepted":true,"content":{"answer":"yes"}}   // accepted:false declines
{"cmd":"steer","sessionId":"...","cwd":"...","text":"..."}
{"cmd":"close","sessionId":"..."}
{"cmd":"delete","sessionId":"..."}
{"cmd":"fork","sessionId":"...","cwd":"..."}
// reply unchanged — add optional optionId:
{"cmd":"reply","reqId":123,"approved":true,"optionId":"allow_always"}
```

### Events harness → QML

```jsonc
{"type":"message.updated","properties":{"info":{"role":"user","id":"..."}}}
{"type":"elicitation","reqId":123,"sessionId":"...","message":"...","schema":{"type":"object","properties":{}}}
{"type":"compaction","sessionId":"...","phase":"start|summary","text":"..."}
{"type":"child.session","sessionId":"...","childSessionId":"...","parentSessionId":"...","depth":1,"title":"...","kind":"tool_call"}
{"type":"steer.result","sessionId":"...","outcome":"injected|promptRequired","reason":"..."}
{"type":"session.forked","sessionId":"<new id>"}
{"type":"context","sessionId":"...","used":0,"size":0,"cost":{"amount":0,"currency":"USD"}}
// existing error event used for attachment read failures
```

OpenCode validates the `elicitation/create` result with ACP's `ElicitationResult` schema.
The reply must be flat — `{"action":"accept","content":{…}}` or `{"action":"decline"}`.
A nested `{"outcome":…}` (the permission shape) fails validation and hangs the turn.
OpenCode question forms use `oneOf` (single select) and `array.items.anyOf` (multi select),
not `enum`; the QML form handles both.

### Backend interfaces

```rust
config::mcp_servers() -> Vec<serde_json::Value>          // stdio/http only, no mutation
attachments::content_blocks(paths:&[String], cwd:&str, allow_image:bool, allow_embedded:bool)
    -> anyhow::Result<Vec<serde_json::Value>>            // ACP content blocks
```

## Work packages

- **WP0 (main agent, foundation)**: `events.rs` new commands, `attachments.rs`, `main.rs` module, `Cargo.toml` base64.
- **WP1 (worker A)**: `src/acp.rs` — all protocol work, calls WP0 interfaces. Sole owner of acp.rs.
- **WP2 (worker B)**: `src/config.rs` — `mcp_servers()`. Sole owner of config.rs.
- **WP3 (worker C)**: `Harness.qml` — P0 UI only (permission options, elicitation form, attachments,
  user message id already handled). Sole owner of Harness.qml. Follow `Noon/AGENTS.md` style.
- **WP4 (supervisor)**: read-only review of every changed file, wire parity, panic paths.

Status: all work packages landed. Follow-up fixes:
- Elicitation reply uses flat `action` (was permission-shaped `outcome`, which hung the turn).
- Number/integer fields default to `0`; select/multi render from `oneOf` / `items.anyOf`.
- **Question UI morphs the bottom composer, one question at a time.** `Harness.pendingElicitation`
  hides `AiChat`'s `inputAreaCol` and shows `aiChat/ElicitComposer.qml` inside the same `LayerRect`,
  using the sidebar palette (`colLayer2/3`, `colOnLayer*`, `colSecondaryContainer`). `index` steps
  through the non-`_custom` fields with Back/Next, and Submit/Cancel call `Harness.answerElicitation()`
  with all collected values. The earlier global `DialogPanel` overlay, the in-sidebar dialog and the
  inline chat-card `ElicitForm` were removed — all clipped or looked foreign in the sidebar.
- **Root cause of "questions show text but no choices": after data crosses a QML `property var`
  boundary, arrays become QVariantList and `Array.isArray()` returns false, so `oneOf` /
  `items.anyOf` were read as empty. `NoonUtils.isList()` (length-based) is now used for schema
  arrays. This repo's `StyledRadioButton` also renders `description`, not `text`, so choices are
  drawn as plain rows with indicators instead of combo popups. Values are passed back explicitly
  from `ElicitComposer.collect()`.**
- Questions are always permitted: `config::perm_fill` injects `"question": "allow"` into
  both the global and session-scoped OpenCode configs, so the question tool never raises a
  `session/request_permission` prompt before the elicitation form appears.
- Attachment-only sends: `AiChat` send guards, `ChatUtils.sendText`, `Harness.sendUserMessage`
  and `_onSession` accept empty text when `_pendingAttachments` is non-empty; `do_send` accepts
  empty text when attachments exist and builds a prompt from attachment blocks only. Attachments
  travel as structured `send` fields, not text.
- Attachments are snapshotted per queue entry and cleared at `finishSend` (not re-read from the
  global list at request time), so queued sends cannot swap attachments between messages.
- `addAttachment` strips `file://` and decodes percent escapes (URLs only) so chips/cards and the
  Rust path use clean filenames. Any `array` schema field renders as comma-separated multi-value.
- `_pendingSend`, `messageQueue` and regenerate entries all carry an attachment snapshot, so
  attachments survive session creation and regeneration and never leak between messages.

## Verification gates

1. `cargo build --release` clean (no new warnings beyond the existing two dead-field warnings).
2. `./diff.sh --all` → 8/8 OK + ACP REPLAY MATCH.
3. Read-only probe: initialize with new capabilities, confirm OpenCode response unchanged.
4. No real prompts, no token spend, no writes to real config/DB during verification.

## Out of scope

- No changes to `scripts/go/ai/` (user decision).
- No commit until asked.
- P2 backend commands are implemented now; their QML controls can follow separately.
