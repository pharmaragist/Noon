//! ACP stdio bridge: spawns `opencode acp`, speaks raw JSON-RPC 2.0 to it and
//! translates its messages into the NDJSON event stream consumed by Harness.qml.
//!
//! Uses smol only (no tokio). The `futures` pipes of `smol::process` already
//! implement `futures::io::{AsyncRead, AsyncWrite}`, so line framing is done
//! directly with `futures::io::BufReader`.
//!
//! DEVIATION (permitted fallback): an SDK connection driver was evaluated and
//! dropped for wire divergence. Its `Builder` requires
//! macro-assisted `AsyncFnMut` hooks plus a `Client.v1()` protocol guard that
//! cannot be compile-checked in isolation here; it generates string-UUID
//! request ids instead of Go's int64, cancels pending requests on `Drop`, and
//! installs an auto-error `Responder` guard. Each of those changes bytes on the
//! wire. This module instead implements a small raw JSON-RPC 2.0 layer over
//! `futures::io` lines, which reproduces the Go bridge's wire contract exactly.

use anyhow::{anyhow, Context, Result};
use crate::common::{data_home, take_chars, truncate_string};
use crate::events::{HarnessCommand, ReqId};
use futures::channel::{mpsc, oneshot};
use futures::io::{AsyncBufReadExt, AsyncWriteExt, BufReader};
use futures::stream::StreamExt;
use serde_json::{json, Map, Value};
use smol::process::{Command, Stdio};
use std::collections::HashMap;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::Duration;

const DEFAULT_TIMEOUT: Duration = Duration::from_secs(60);
const NEW_TIMEOUT: Duration = Duration::from_secs(180);
const PROMPT_TIMEOUT: Duration = Duration::from_secs(600);

/// Mirror of qemit(): marshal and write one NDJSON line; errors are ignored.
fn emit(v: Value) {
    let _ = crate::events::emit(&v);
}

fn error_event(message: impl Into<String>) -> Value {
    json!({"type": "error", "message": message.into()})
}

/// Build a `child.session` event from either an `opencode/session/child_update`
/// notification or a tool part's `_meta["opencode/child-session"]`. `fallback_sid`
/// supplies `sessionId` when the source omits `rootSessionId`.
fn child_session_event(params: &Value, fallback_sid: &str, kind: &str) -> Value {
    let root = params
        .get("rootSessionId")
        .and_then(Value::as_str)
        .filter(|s| !s.is_empty())
        .unwrap_or(fallback_sid);
    json!({
        "type": "child.session",
        "sessionId": root,
        "childSessionId": params.get("childSessionId").and_then(Value::as_str).unwrap_or(""),
        "parentSessionId": params.get("parentSessionId").and_then(Value::as_str).unwrap_or(""),
        "depth": params.get("depth").cloned().unwrap_or(json!(0)),
        "title": params.get("title").and_then(Value::as_str).unwrap_or(""),
        "kind": kind,
    })
}

/// Go: opencodeDataDir() — $HOME/.local/share/opencode
fn opencode_data_dir() -> String {
    format!("{}/.local/share/opencode", std::env::var("HOME").unwrap_or_default())
}

/// Go: cwdOf() — a non-empty cwd wins (with `file://` stripped), else cwd,
/// else $HOME. `HarnessCommand` defaults `cwd` to "" when absent.
fn cwd_of(cwd: &str) -> String {
    if !cwd.is_empty() {
        return cwd.strip_prefix("file://").unwrap_or(cwd).to_string();
    }
    std::env::current_dir()
        .map(|p| p.to_string_lossy().into_owned())
        .unwrap_or_else(|_| std::env::var("HOME").unwrap_or_default())
}

// ---------------------------------------------------------------------------
// configOptions / modes helpers (OpenCode non-standard fields)
// ---------------------------------------------------------------------------

/// Go: configValues — returns (Option<values>, current). `None` models Go's
/// `nil []string`, which serializes to JSON `null` (distinct from `[]`).
fn config_values(opts: &Value, id: &str) -> (Option<Vec<String>>, String) {
    let mut values: Option<Vec<String>> = None;
    let mut current = String::new();

    if let Some(arr) = opts.as_array() {
        for o in arr {
            if o.get("id").and_then(Value::as_str) != Some(id) {
                continue;
            }
            // Go: list := o.Options; if len(list)==0 { list = o.Values }
            let list = o
                .get("options")
                .and_then(Value::as_array)
                .filter(|a| !a.is_empty())
                .or_else(|| o.get("values").and_then(Value::as_array));
            if let Some(list) = list {
                for m in list {
                    let val = m
                        .get("value")
                        .and_then(Value::as_str)
                        .filter(|s| !s.is_empty())
                        .or_else(|| {
                            m.get("valueId")
                                .and_then(Value::as_str)
                                .filter(|s| !s.is_empty())
                        });
                    if let Some(v) = val {
                        values.get_or_insert_with(Vec::new).push(v.to_string());
                    }
                }
            }
            current = o
                .get("currentValue")
                .and_then(Value::as_str)
                .filter(|s| !s.is_empty())
                .or_else(|| o.get("currentValueId").and_then(Value::as_str))
                .unwrap_or("")
                .to_string();
        }
    }
    (values, current)
}

fn parse_config(res: &Value, id: &str) -> (Option<Vec<String>>, String) {
    config_values(res.get("configOptions").unwrap_or(&Value::Null), id)
}

fn parse_efforts(res: &Value) -> (Option<Vec<String>>, String) {
    parse_config(res, "effort")
}

fn mode_ids(modes: &Value) -> Vec<String> {
    modes
        .get("availableModes")
        .and_then(Value::as_array)
        .map(|a| {
            a.iter()
                .filter_map(|m| m.get("id").and_then(Value::as_str).map(str::to_string))
                .collect()
        })
        .unwrap_or_default()
}

// ---------------------------------------------------------------------------
// truncation (UTF-8 safe: the plan's correctness fix over Go's byte slicing)
// ---------------------------------------------------------------------------

/// Go: truncateBlob. When the value is a JSON object, truncate its `content`
/// string and return compact JSON text; otherwise return the raw JSON text,
/// truncated. Key ordering matches Go (serde_json's BTreeMap-backed Map sorts
/// keys, as does encoding/json for maps).
fn truncate_blob(v: &Value, max: usize) -> String {
    if let Some(obj) = v.as_object() {
        let mut clone = obj.clone();
        if let Some(c) = clone.get("content").and_then(Value::as_str) {
            if c.chars().count() > max {
                let cut = format!("{}…", take_chars(c, max));
                clone.insert("content".to_string(), json!(cut));
            }
        }
        return Value::Object(clone).to_string();
    }
    let s = v.to_string();
    if s.chars().count() > max {
        format!("{}…", take_chars(&s, max))
    } else {
        s
    }
}

/// Go: toolText — flatten the content blocks of a tool_call_update.
fn tool_text(content: Option<&Value>) -> String {
    let content = match content {
        Some(v) if !v.is_null() => v,
        _ => return String::new(),
    };
    let blocks = match content.as_array() {
        Some(a) => a,
        None => return truncate_blob(content, 4000),
    };
    let mut out = String::new();
    for bl in blocks {
        if let Some(t) = bl
            .get("content")
            .and_then(|c| c.get("text"))
            .and_then(Value::as_str)
            .filter(|t| !t.is_empty())
        {
            out.push_str(t);
            continue;
        }
        if let Some(t) = bl.get("text").and_then(Value::as_str).filter(|t| !t.is_empty()) {
            out.push_str(t);
            continue;
        }
        if let Some(d) = bl.get("diff") {
            let path = d.get("path").and_then(Value::as_str).unwrap_or("");
            let new_text = d.get("newText").and_then(Value::as_str).unwrap_or("");
            out.push_str(&format!("diff {}\n{}", path, new_text));
            continue;
        }
        if let Some(t) = bl.get("terminalId").and_then(Value::as_str).filter(|t| !t.is_empty()) {
            out.push_str(&format!("[terminal {}]", t));
        }
    }
    truncate_string(&out, 4000)
}

// ---------------------------------------------------------------------------
// JSON-RPC wire types
// ---------------------------------------------------------------------------

#[derive(Debug)]
struct AcpError {
    message: String,
}

#[derive(Debug)]
struct AcpResponse {
    id: u64,
    result: Option<Value>,
    error: Option<AcpError>,
}

fn parse_response(obj: &Map<String, Value>) -> AcpResponse {
    AcpResponse {
        id: obj.get("id").and_then(Value::as_u64).unwrap_or(0),
        result: obj.get("result").cloned(),
        error: obj.get("error").and_then(Value::as_object).map(|e| AcpError {
            message: e
                .get("message")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string(),
        }),
    }
}

#[derive(Clone)]
struct PermOption {
    option_id: String,
    kind: String,
    session_id: String,
}

struct PendingPerm {
    /// The exact id as received on the wire, echoed back in the reply.
    id: Value,
    options: Vec<PermOption>,
}

/// Normalize an incoming agent request id (number or string) to the string we
/// put in `permission.asked.id`; QML echoes that string back as `reqId`.
fn id_key(id: &Value) -> Option<String> {
    match id {
        Value::Number(n) => Some(n.to_string()),
        Value::String(s) => Some(s.clone()),
        _ => None,
    }
}

fn pick_allow_option(opts: &[PermOption]) -> String {
    for o in opts {
        if o.kind == "allow_once" {
            return o.option_id.clone();
        }
    }
    for o in opts {
        if o.kind == "allow_always" {
            return o.option_id.clone();
        }
    }
    for o in opts {
        if !o.kind.starts_with("reject") {
            return o.option_id.clone();
        }
    }
    String::new()
}

// ---------------------------------------------------------------------------
// Bridge
// ---------------------------------------------------------------------------

struct Bridge {
    /// Serializes all writes to the child's stdin (mpsc to a dedicated writer
    /// task). This replaces Go's `mu` around `stdin.Write`.
    write_tx: mpsc::UnboundedSender<String>,
    exited: AtomicBool,
    /// `agentCapabilities.promptCapabilities` from the initialize response.
    /// Defaults false so attachments degrade to resource links.
    allow_image: AtomicBool,
    allow_embedded: AtomicBool,
    next_id: AtomicU64,
    pending: Mutex<HashMap<u64, oneshot::Sender<AcpResponse>>>,
    known: Mutex<HashMap<String, String>>,
    last_msg: Mutex<HashMap<String, String>>,
    perm_opt: Mutex<HashMap<String, PendingPerm>>,
    /// Elicitation requests awaiting a `elicit` command, keyed by normalized
    /// ReqId; value is the exact wire id to echo back in the reply.
    pending_elicit: Mutex<HashMap<String, Value>>,
    sess_locks: Mutex<HashMap<String, Arc<futures::lock::Mutex<()>>>>,
}

impl Bridge {
    fn new(write_tx: mpsc::UnboundedSender<String>) -> Self {
        Self {
            write_tx,
            exited: AtomicBool::new(false),
            allow_image: AtomicBool::new(false),
            allow_embedded: AtomicBool::new(false),
            next_id: AtomicU64::new(0),
            pending: Mutex::new(HashMap::new()),
            known: Mutex::new(HashMap::new()),
            last_msg: Mutex::new(HashMap::new()),
            perm_opt: Mutex::new(HashMap::new()),
            pending_elicit: Mutex::new(HashMap::new()),
            sess_locks: Mutex::new(HashMap::new()),
        }
    }

    // -- raw I/O ------------------------------------------------------------

    fn send_raw(&self, msg: &Value) -> Result<()> {
        if self.exited.load(Ordering::Relaxed) {
            return Err(anyhow!("agent process exited"));
        }
        let mut line = serde_json::to_string(msg)?;
        line.push('\n');
        self.write_tx
            .unbounded_send(line)
            .map_err(|_| anyhow!("agent process exited"))
    }

    async fn call(&self, method: &str, params: Value, timeout: Duration) -> Result<Value> {
        let id = self.next_id.fetch_add(1, Ordering::Relaxed) + 1;
        let (tx, rx) = oneshot::channel::<AcpResponse>();
        self.pending.lock().unwrap().insert(id, tx);

        let req = json!({
            "jsonrpc": "2.0",
            "id": id,
            "method": method,
            "params": params,
        });
        if let Err(e) = self.send_raw(&req) {
            self.pending.lock().unwrap().remove(&id);
            return Err(e);
        }

        let wait = Box::pin(async {
            match rx.await {
                Ok(resp) => {
                    if let Some(err) = resp.error {
                        Err(anyhow!("ACP {}: {}", method, err.message))
                    } else {
                        Ok(resp.result.unwrap_or(Value::Null))
                    }
                }
                // oneshot closed => exit watcher drained pendings.
                Err(_) => Err(anyhow!("ACP {}: agent process exited", method)),
            }
        });
        let timer = Box::pin(smol::Timer::after(timeout));
        match futures::future::select(wait, timer).await {
            futures::future::Either::Left((res, _)) => res,
            futures::future::Either::Right((_, _)) => {
                self.pending.lock().unwrap().remove(&id);
                Err(anyhow!("ACP {}: timeout", method))
            }
        }
    }

    fn notify(&self, method: &str, params: &Value) -> Result<()> {
        self.send_raw(&json!({"jsonrpc": "2.0", "method": method, "params": params}))
    }

    fn reply(&self, id: &Value, result: &Value) -> Result<()> {
        self.send_raw(&json!({"jsonrpc": "2.0", "id": id, "result": result}))
    }

    fn reply_error(&self, id: &Value, code: i64, message: &str) -> Result<()> {
        self.send_raw(&json!({
            "jsonrpc": "2.0",
            "id": id,
            "error": {"code": code, "message": message},
        }))
    }

    /// Complete a pending `call()` early so its future stops waiting.
    fn cancel_call(&self, id: u64) {
        if let Some(tx) = self.pending.lock().unwrap().remove(&id) {
            let _ = tx.send(AcpResponse {
                id,
                result: None,
                error: Some(AcpError {
                    message: "request cancelled".to_string(),
                }),
            });
        }
    }

    /// `$/cancel_request` params: `{"id": <number|string>}`.
    fn on_cancel_request(&self, obj: &Map<String, Value>) {
        let params = obj.get("params").unwrap_or(&Value::Null);
        let id = params.get("id");
        let n = id
            .and_then(Value::as_u64)
            .or_else(|| id.and_then(Value::as_str).and_then(|s| s.parse().ok()));
        if let Some(n) = n {
            self.cancel_call(n);
        }
    }

    // -- child lifecycle ----------------------------------------------------

    async fn on_child_exit(&self, message: String) {
        self.exited.store(true, Ordering::Relaxed);
        let pending: Vec<(u64, oneshot::Sender<AcpResponse>)> =
            self.pending.lock().unwrap().drain().collect();
        for (id, tx) in pending {
            let _ = tx.send(AcpResponse {
                id,
                result: None,
                error: Some(AcpError {
                    message: "agent process exited".to_string(),
                }),
            });
        }
        emit(json!({"type": "agent.exited", "message": message}));
    }

    // -- inbound child messages ---------------------------------------------

    async fn handle_line(&self, line: &str) {
        let line = line.trim();
        if line.is_empty() {
            return;
        }
        let v: Value = match serde_json::from_str(line) {
            Ok(v) => v,
            Err(_) => return,
        };
        let obj = match v.as_object() {
            Some(o) => o,
            None => return,
        };
        let has_id = obj.contains_key("id");
        let has_method = obj.contains_key("method");

        if has_id && !has_method {
            // Response to one of our requests.
            let resp = parse_response(obj);
            let tx = self.pending.lock().unwrap().remove(&resp.id);
            if let Some(tx) = tx {
                let _ = tx.send(resp);
            }
            return;
        }
        let method = obj.get("method").and_then(Value::as_str).unwrap_or("");
        if has_id && has_method {
            if method == "$/cancel_request" {
                self.on_cancel_request(obj);
                if let Some(id) = obj.get("id") {
                    let _ = self.reply(id, &json!({}));
                }
                return;
            }
            self.on_agent_request(obj).await;
            return;
        }
        // Notifications.
        if method == "$/cancel_request" {
            self.on_cancel_request(obj);
            return;
        }
        if method == "opencode/session/child_update" {
            let params = obj.get("params").unwrap_or(&Value::Null);
            emit(child_session_event(params, "", "notification"));
            return;
        }
        if method != "session/update" {
            return;
        }
        let params = match obj.get("params") {
            Some(p) => p,
            None => return,
        };
        let sid = params.get("sessionId").and_then(Value::as_str).unwrap_or("");
        let update = match params.get("update") {
            Some(u) => u,
            None => return,
        };
        self.on_update(sid, update).await;
    }

    async fn on_agent_request(&self, obj: &Map<String, Value>) {
        let method = obj.get("method").and_then(Value::as_str).unwrap_or("");
        let id_val = match obj.get("id") {
            Some(v) if !v.is_null() => v.clone(),
            _ => return,
        };

        if method == "session/request_permission" {
            let params = obj.get("params").unwrap_or(&Value::Null);
            let sid = params
                .get("sessionId")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            let call = params.get("toolCall").unwrap_or(&Value::Null);
            let call_id = call.get("toolCallId").and_then(Value::as_str).unwrap_or("");
            let title = call.get("title").and_then(Value::as_str).unwrap_or("");

            let mut opts_out = Vec::new();
            let mut stored = Vec::new();
            if let Some(options) = params.get("options").and_then(Value::as_array) {
                for o in options {
                    let option_id = o.get("optionId").and_then(Value::as_str).unwrap_or("");
                    let name = o.get("name").and_then(Value::as_str).unwrap_or("");
                    let kind = o.get("kind").and_then(Value::as_str).unwrap_or("");
                    opts_out.push(json!({"optionId": option_id, "name": name, "kind": kind}));
                    stored.push(PermOption {
                        option_id: option_id.to_string(),
                        kind: kind.to_string(),
                        session_id: sid.clone(),
                    });
                }
            }

            let key = match id_key(&id_val) {
                Some(k) => k,
                None => return,
            };
            let msg_id = self
                .last_msg
                .lock()
                .unwrap()
                .get(&sid)
                .cloned()
                .unwrap_or_default();
            self.perm_opt.lock().unwrap().insert(
                key.clone(),
                PendingPerm {
                    id: id_val,
                    options: stored,
                },
            );
            emit(json!({
                "type": "permission.asked",
                "properties": {
                    "id": key,
                    "sessionID": sid,
                    "tool": {"messageID": msg_id, "callID": call_id, "title": title},
                    "options": opts_out,
                },
            }));
            return;
        }

        if method == "elicitation/create" {
            let params = obj.get("params").unwrap_or(&Value::Null);
            let sid = params
                .get("sessionId")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            let key = match id_key(&id_val) {
                Some(k) => k,
                None => return,
            };
            self.pending_elicit.lock().unwrap().insert(key, id_val.clone());
            emit(json!({
                "type": "elicitation",
                "reqId": &id_val,
                "sessionId": sid,
                "message": params.get("message").cloned().unwrap_or(Value::Null),
                "schema": params.get("requestedSchema").cloned().unwrap_or(Value::Null),
            }));
            return;
        }

        if method == "fs/read_text_file"
            || method == "fs/write_text_file"
            || method.starts_with("terminal/")
        {
            let _ = self.reply_error(
                &id_val,
                -32601,
                &format!("client does not implement {}", method),
            );
            return;
        }

        let params_str = obj
            .get("params")
            .map(|p| p.to_string())
            .unwrap_or_else(|| "null".to_string());
        emit(json!({
            "type": "agent-request",
            "reqId": &id_val,
            "method": method,
            "params": params_str,
        }));
        // Never leave an unknown agent request unanswered.
        let _ = self.reply_error(&id_val, -32601, &format!("method not found: {}", method));
    }

    async fn on_update(&self, sid: &str, u: &Value) {
        let kind = u.get("sessionUpdate").and_then(Value::as_str).unwrap_or("");
        let own_msg_id = u.get("messageId").and_then(Value::as_str).unwrap_or("");

        // Go: update lastMsg from updates that carry a messageId, and use the
        // remembered value for tool parts.
        let msg_id = {
            let mut m = self.last_msg.lock().unwrap();
            if !own_msg_id.is_empty() {
                m.insert(sid.to_string(), own_msg_id.to_string());
            }
            m.get(sid).cloned().unwrap_or_default()
        };

        match kind {
            "user_message_chunk" => {
                emit(json!({
                    "type": "message.updated",
                    "properties": {"info": {"role": "user", "id": own_msg_id}},
                }));
            }
            "agent_thought_chunk" | "agent_message_chunk" => {
                let text = u
                    .get("content")
                    .and_then(|c| c.get("text"))
                    .and_then(Value::as_str)
                    .unwrap_or("");
                if text.is_empty() {
                    return;
                }
                let part_type = if kind == "agent_thought_chunk" {
                    "reasoning"
                } else {
                    "text"
                };
                emit(json!({
                    "type": "message.part.updated",
                    "properties": {"part": {
                        "type": part_type,
                        "messageID": own_msg_id,
                        "text": text,
                    }},
                }));
            }
            "tool_call" => {
                if let Some(meta) = u.get("_meta").and_then(|m| m.get("opencode/child-session")) {
                    emit(child_session_event(meta, sid, "tool_call"));
                }
                let input_raw = u.get("rawInput");
                let input: Value = match input_raw {
                    Some(v) if !v.is_null() => {
                        let blob = truncate_blob(v, 4000);
                        serde_json::from_str(&blob).unwrap_or_else(|_| json!(blob))
                    }
                    _ => Value::Null,
                };
                emit(json!({
                    "type": "message.part.updated",
                    "properties": {"part": {
                        "type": "tool",
                        "tool": u.get("title").and_then(Value::as_str).unwrap_or(""),
                        "callID": u.get("toolCallId").and_then(Value::as_str).unwrap_or(""),
                        "messageID": msg_id,
                        "kind": u.get("kind").and_then(Value::as_str).unwrap_or(""),
                        "locations": u.get("locations").cloned().unwrap_or(Value::Null),
                        "state": {"status": "pending", "input": input},
                    }},
                }));
            }
            "tool_call_update" => {
                if let Some(meta) = u.get("_meta").and_then(|m| m.get("opencode/child-session")) {
                    emit(child_session_event(meta, sid, "tool_call"));
                }
                emit(json!({
                    "type": "message.part.updated",
                    "properties": {"part": {
                        "type": "tool",
                        "tool": u.get("title").and_then(Value::as_str).unwrap_or(""),
                        "callID": u.get("toolCallId").and_then(Value::as_str).unwrap_or(""),
                        "messageID": msg_id,
                        "kind": u.get("kind").and_then(Value::as_str).unwrap_or(""),
                        "locations": u.get("locations").cloned().unwrap_or(Value::Null),
                        "state": {
                            "status": u.get("status").and_then(Value::as_str).unwrap_or(""),
                            "output": tool_text(u.get("content")),
                        },
                    }},
                }));
            }
            "available_commands_update" => {
                let names: Vec<String> = u
                    .get("availableCommands")
                    .and_then(Value::as_array)
                    .map(|a| {
                        a.iter()
                            .filter_map(|c| c.get("name").and_then(Value::as_str).map(str::to_string))
                            .collect()
                    })
                    .unwrap_or_default();
                emit(json!({"type": "commands", "sessionId": sid, "commands": names}));
            }
            "usage_update" => {
                let mut ev = json!({
                    "type": "context",
                    "sessionId": sid,
                    "used": u.get("used").cloned().unwrap_or(Value::Null),
                    "size": u.get("size").cloned().unwrap_or(Value::Null),
                });
                if let Some(cost) = u.get("cost").filter(|c| c.is_object()) {
                    ev["cost"] = json!({
                        "amount": cost.get("amount").cloned().unwrap_or(Value::Null),
                        "currency": cost.get("currency").cloned().unwrap_or(Value::Null),
                    });
                }
                emit(ev);
            }
            "session_info_update" => {
                if let Some(title) = u.get("title").and_then(Value::as_str).filter(|t| !t.is_empty()) {
                    emit(json!({"type": "session.info", "sessionId": sid, "title": title}));
                }
            }
            "current_mode_update" => {
                if let Some(mode) = u
                    .get("currentModeId")
                    .and_then(Value::as_str)
                    .filter(|m| !m.is_empty())
                {
                    emit(json!({"type": "mode", "sessionId": sid, "mode": mode}));
                }
            }
            "config_option_update" => {
                emit(json!({"type": "config", "sessionId": sid, "update": u.clone()}));
            }
            "plan" => {
                emit(json!({"type": "plan", "sessionId": sid, "plan": u.clone()}));
            }
            "compaction_update" | "compaction_summary_chunk" => {
                let phase = if kind == "compaction_update" { "start" } else { "summary" };
                let text = u
                    .get("text")
                    .and_then(Value::as_str)
                    .or_else(|| {
                        u.get("content")
                            .and_then(|c| c.get("text"))
                            .and_then(Value::as_str)
                    })
                    .unwrap_or("");
                emit(json!({
                    "type": "compaction",
                    "sessionId": sid,
                    "phase": phase,
                    "text": text,
                }));
            }
            _ => {
                emit(json!({"type": "update", "sessionId": sid, "kind": kind}));
            }
        }
    }

    // -- session/config helpers ---------------------------------------------

    async fn session_lock(&self, sid: &str) -> Arc<futures::lock::Mutex<()>> {
        let mut locks = self.sess_locks.lock().unwrap();
        locks
            .entry(sid.to_string())
            .or_insert_with(|| Arc::new(futures::lock::Mutex::new(())))
            .clone()
    }

    async fn emit_session_state(&self, sid: &str, opts: &Value, fallback: Option<&Value>) {
        let (models, _) = config_values(opts, "model");
        if models.as_ref().map_or(false, |v| !v.is_empty()) {
            emit(json!({"type": "models", "sessionId": sid, "models": models}));
        }
        let (_, model) = config_values(opts, "model");
        if !model.is_empty() {
            emit(json!({"type": "model", "sessionId": sid, "model": model}));
        }
        let (efforts, effort) = config_values(opts, "effort");
        if efforts.is_some() {
            emit(json!({
                "type": "efforts",
                "sessionId": sid,
                "efforts": efforts.unwrap_or_default(),
                "effort": effort,
            }));
        }
        let (list, mode) = config_values(opts, "mode");
        if list.as_ref().map_or(false, |v| !v.is_empty()) || !mode.is_empty() {
            emit(json!({"type": "mode", "sessionId": sid, "mode": mode, "modes": list}));
        } else if let Some(fb) = fallback {
            emit(json!({
                "type": "mode",
                "sessionId": sid,
                "mode": fb.get("currentModeId").and_then(Value::as_str).unwrap_or(""),
                "modes": mode_ids(fb),
            }));
        }
    }

    async fn apply_config(&self, sid: &str, id: &str, value: &str) -> Option<Value> {
        match self
            .call(
                "session/set_config_option",
                json!({"sessionId": sid, "configId": id, "value": value}),
                DEFAULT_TIMEOUT,
            )
            .await
        {
            Ok(res) => Some(res),
            Err(e) => {
                emit(error_event(e.to_string()));
                None
            }
        }
    }

    async fn set_config_quiet(&self, sid: &str, id: &str, value: &str) -> String {
        match self.apply_config(sid, id, value).await {
            Some(res) => parse_config(&res, id).1,
            None => String::new(),
        }
    }

    async fn set_config(&self, sid: &str, id: &str, value: &str) -> String {
        let res = match self.apply_config(sid, id, value).await {
            Some(r) => r,
            None => return String::new(),
        };
        let confirmed = parse_config(&res, id).1;
        match id {
            "model" => {
                if !confirmed.is_empty() {
                    emit(json!({"type": "model", "sessionId": sid, "model": &confirmed}));
                }
                let (efforts, cur) = parse_efforts(&res);
                match efforts {
                    Some(e) => emit(json!({
                        "type": "efforts", "sessionId": sid, "efforts": e, "effort": cur,
                    })),
                    None => emit(json!({
                        "type": "efforts", "sessionId": sid, "efforts": [], "effort": "",
                    })),
                }
            }
            "effort" => {
                let (efforts, cur) = parse_efforts(&res);
                if let Some(e) = efforts {
                    emit(json!({
                        "type": "efforts", "sessionId": sid, "efforts": e, "effort": cur,
                    }));
                }
            }
            "mode" => {
                if !confirmed.is_empty() {
                    emit(json!({"type": "mode", "sessionId": sid, "mode": &confirmed}));
                }
            }
            _ => {}
        }
        confirmed
    }

    async fn apply_if_requested(&self, sid: &str, id: &str, value: &str, old: String) -> String {
        if value.is_empty() || value == old {
            return old;
        }
        let confirmed = self.set_config_quiet(sid, id, value).await;
        if confirmed.is_empty() {
            old
        } else {
            confirmed
        }
    }

    async fn ensure_known(&self, sid: &str, cwd: &str) -> Result<()> {
        if self.known.lock().unwrap().contains_key(sid) {
            return Ok(());
        }
        let res = self
            .call(
                "session/resume",
                json!({"sessionId": sid, "cwd": cwd, "mcpServers": crate::config::mcp_servers()}),
                DEFAULT_TIMEOUT,
            )
            .await?;
        // Go: any valid JSON response goes through emitSessionState (a missing
        // configOptions just yields empty opts, while `modes` may still drive
        // the mode fallback).
        self.emit_session_state(
            sid,
            res.get("configOptions").unwrap_or(&Value::Null),
            res.get("modes"),
        )
        .await;
        self.known
            .lock()
            .unwrap()
            .insert(sid.to_string(), cwd.to_string());
        Ok(())
    }

    // -- commands -----------------------------------------------------------

    async fn handle_command(&self, cmd: HarnessCommand) {
        match cmd {
            HarnessCommand::List { cwd, .. } => self.do_list(&cwd).await,
            HarnessCommand::New { cwd, model, effort, mode, .. } => {
                self.do_new(&cwd, &model, &effort, &mode).await
            }
            HarnessCommand::Send {
                session_id,
                cwd,
                text,
                attachments,
                model,
                effort,
                mode,
            } => {
                self.do_send(
                    &session_id,
                    &cwd,
                    &text,
                    &attachments,
                    &model,
                    &effort,
                    &mode,
                )
                .await
            }
            HarnessCommand::Elicit { req_id, accepted, content } => {
                self.do_elicit(&req_id, accepted, &content).await
            }
            HarnessCommand::Steer { session_id, cwd, text } => {
                self.do_steer(&session_id, &cwd, &text).await
            }
            HarnessCommand::Close { session_id } => self.do_close(&session_id).await,
            HarnessCommand::Delete { session_id } => self.do_delete(&session_id).await,
            HarnessCommand::Fork { session_id, cwd } => self.do_fork(&session_id, &cwd).await,
            HarnessCommand::Model { session_id, cwd, model } => {
                self.do_model(&session_id, &cwd, &model).await
            }
            HarnessCommand::Mode { session_id, cwd, mode } => {
                self.do_mode(&session_id, &cwd, &mode).await
            }
            HarnessCommand::Reply { req_id, approved, option_id } => {
                self.do_reply(&req_id, approved, &option_id).await
            }
            HarnessCommand::Cancel { session_id } => self.do_cancel(&session_id).await,
            HarnessCommand::Sync { session_id, cwd } => self.do_sync(&session_id, &cwd).await,
        }
    }

    async fn do_list(&self, cwd: &str) {
        let cwd = cwd_of(cwd);
        let mut all: Vec<Value> = Vec::new();
        let mut cursor = String::new();
        loop {
            let mut params = json!({"cwd": cwd});
            if !cursor.is_empty() {
                params["cursor"] = json!(cursor);
            }
            let res = match self.call("session/list", params, DEFAULT_TIMEOUT).await {
                Ok(r) => r,
                Err(e) => {
                    emit(error_event(e.to_string()));
                    return;
                }
            };
            let sessions = res.get("sessions").and_then(Value::as_array);
            if let Some(sessions) = sessions {
                for s in sessions {
                    all.push(json!({
                        "sessionId": s.get("sessionId").and_then(Value::as_str).unwrap_or(""),
                        "cwd": s.get("cwd").and_then(Value::as_str).unwrap_or(""),
                        "title": s.get("title").and_then(Value::as_str).unwrap_or(""),
                        "updatedAt": s.get("updatedAt").and_then(Value::as_str).unwrap_or(""),
                    }));
                }
            }
            let next = res
                .get("nextCursor")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            if next.is_empty() {
                break;
            }
            cursor = next;
        }
        emit(json!({"type": "sessions", "sessions": all}));
    }

    async fn do_new(&self, cmd_cwd: &str, model_req: &str, effort_req: &str, mode_req: &str) {
        let cwd = cwd_of(cmd_cwd);
        let res = match self
            .call(
                "session/new",
                json!({"cwd": cwd, "mcpServers": crate::config::mcp_servers()}),
                NEW_TIMEOUT,
            )
            .await
        {
            Ok(r) => r,
            Err(e) => {
                emit(error_event(e.to_string()));
                return;
            }
        };
        let sid = res.get("sessionId").and_then(Value::as_str).unwrap_or("").to_string();
        let opts = res.get("configOptions").cloned().unwrap_or(json!([]));
        let modes_fallback = res.get("modes").cloned();

        let (models, mut model) = config_values(&opts, "model");
        let (efforts, mut effort) = config_values(&opts, "effort");
        let (mut mode_list, mut mode) = config_values(&opts, "mode");
        if mode_list.as_ref().map_or(true, |v| v.is_empty()) {
            if let Some(fb) = &modes_fallback {
                mode = fb.get("currentModeId").and_then(Value::as_str).unwrap_or("").to_string();
                mode_list = Some(mode_ids(fb));
            }
        }

        self.known.lock().unwrap().insert(sid.clone(), cwd);

        model = self.apply_if_requested(&sid, "model", model_req, model).await;
        effort = self.apply_if_requested(&sid, "effort", effort_req, effort).await;
        mode = self.apply_if_requested(&sid, "mode", mode_req, mode).await;

        emit(json!({
            "type": "session",
            "sessionId": sid,
            "models": models,
            "model": model,
            "modes": mode_list,
            "mode": mode,
            "efforts": efforts,
            "effort": effort,
        }));
    }

    async fn do_send(
        &self,
        sid: &str,
        cmd_cwd: &str,
        text: &str,
        attachments: &[String],
        model_req: &str,
        effort_req: &str,
        mode_req: &str,
    ) {
        if sid.is_empty() || (text.is_empty() && attachments.is_empty()) {
            emit(error_event("send needs sessionId, text, or attachments"));
            return;
        }
        let lock = self.session_lock(sid).await;
        let _guard = lock.lock().await;
        let cwd = cwd_of(cmd_cwd);
        if let Err(e) = self.ensure_known(sid, &cwd).await {
            emit(error_event(e.to_string()));
            return;
        }
        if !model_req.is_empty() {
            self.set_config(sid, "model", model_req).await;
        }
        if !effort_req.is_empty() {
            self.set_config(sid, "effort", effort_req).await;
        }
        if !mode_req.is_empty() {
            self.set_config(sid, "mode", mode_req).await;
        }

        let mut prompt = Vec::new();
        if !text.is_empty() {
            prompt.push(json!({"type": "text", "text": text}));
        }
        if !attachments.is_empty() {
            match crate::attachments::content_blocks(
                attachments,
                &cwd,
                self.allow_image.load(Ordering::Relaxed),
                self.allow_embedded.load(Ordering::Relaxed),
            ) {
                Ok(blocks) => prompt.extend(blocks),
                Err(e) => {
                    emit(error_event(e.to_string()));
                    return;
                }
            }
        }
        if prompt.is_empty() {
            emit(error_event("send has no prompt content"));
            return;
        }

        emit(json!({
            "type": "session.status",
            "properties": {"status": {"type": "busy"}},
        }));
        let res = self
            .call(
                "session/prompt",
                json!({"sessionId": sid, "prompt": prompt}),
                PROMPT_TIMEOUT,
            )
            .await;
        emit(json!({
            "type": "session.status",
            "properties": {"status": {"type": "idle"}},
        }));
        let res = match res {
            Ok(r) => r,
            Err(e) => {
                emit(error_event(e.to_string()));
                return;
            }
        };
        let stop_reason = res
            .get("stopReason")
            .and_then(Value::as_str)
            .unwrap_or("")
            .to_string();
        if let Some(usage) = res.get("usage").and_then(Value::as_object) {
            emit(json!({
                "type": "usage",
                "sessionId": sid,
                "input": usage.get("inputTokens").and_then(Value::as_i64).unwrap_or(0),
                "output": usage.get("outputTokens").and_then(Value::as_i64).unwrap_or(0),
                "total": usage.get("totalTokens").and_then(Value::as_i64).unwrap_or(0),
            }));
        }
        emit(json!({"type": "prompt-done", "stopReason": stop_reason}));
    }

    async fn do_model(&self, sid: &str, cmd_cwd: &str, model: &str) {
        if sid.is_empty() || model.is_empty() {
            return;
        }
        let lock = self.session_lock(sid).await;
        let _guard = lock.lock().await;
        if let Err(e) = self.ensure_known(sid, &cwd_of(cmd_cwd)).await {
            emit(error_event(e.to_string()));
            return;
        }
        self.set_config(sid, "model", model).await;
    }

    async fn do_mode(&self, sid: &str, cmd_cwd: &str, mode: &str) {
        if sid.is_empty() || mode.is_empty() {
            return;
        }
        let lock = self.session_lock(sid).await;
        let _guard = lock.lock().await;
        if let Err(e) = self.ensure_known(sid, &cwd_of(cmd_cwd)).await {
            emit(error_event(e.to_string()));
            return;
        }
        self.set_config(sid, "mode", mode).await;
    }

    async fn do_reply(&self, req_id: &ReqId, approved: bool, option_id_arg: &str) {
        let key = req_id.key();
        let mut option_id = option_id_arg.to_string();

        let stored = self.perm_opt.lock().unwrap().remove(&key);
        let options = stored
            .as_ref()
            .map(|p| p.options.clone())
            .unwrap_or_default();
        let wire_id = stored
            .map(|p| p.id)
            .unwrap_or_else(|| key.parse::<u64>().map(|n| json!(n)).unwrap_or(json!(key)));

        let outcome = if !approved {
            json!({"outcome": "cancelled"})
        } else {
            if option_id.is_empty() {
                option_id = pick_allow_option(&options);
            }
            if option_id.is_empty() {
                json!({"outcome": "cancelled"})
            } else {
                json!({"outcome": "selected", "optionId": option_id})
            }
        };
        // ACP RequestPermissionResponse: { "outcome": <RequestPermissionOutcome> }
        let _ = self.reply(&wire_id, &json!({"outcome": outcome}));
    }

    async fn do_elicit(&self, req_id: &ReqId, accepted: bool, content: &Value) {
        let key = req_id.key();
        let wire_id = match self.pending_elicit.lock().unwrap().remove(&key) {
            Some(id) => id,
            None => {
                emit(error_event(format!("unknown elicitation reqId: {}", key)));
                return;
            }
        };
        // ACP ElicitationResult uses a flat `action` discriminator, not `outcome`.
        let result = if accepted {
            json!({"action": "accept", "content": content})
        } else {
            json!({"action": "decline"})
        };
        let _ = self.reply(&wire_id, &result);
    }

    async fn do_steer(&self, sid: &str, cmd_cwd: &str, text: &str) {
        if sid.is_empty() || text.is_empty() {
            emit(error_event("steer needs sessionId and text"));
            return;
        }
        if let Err(e) = self.ensure_known(sid, &cwd_of(cmd_cwd)).await {
            emit(error_event(e.to_string()));
            return;
        }
        match self
            .call(
                "_session/steering",
                json!({"sessionId": sid, "prompt": [{"type": "text", "text": text}]}),
                DEFAULT_TIMEOUT,
            )
            .await
        {
            Ok(res) => emit(json!({
                "type": "steer.result",
                "sessionId": sid,
                "outcome": res.get("outcome").and_then(Value::as_str).unwrap_or(""),
                "reason": res.get("reason").and_then(Value::as_str).unwrap_or(""),
            })),
            Err(e) => emit(error_event(e.to_string())),
        }
    }

    async fn do_close(&self, sid: &str) {
        if sid.is_empty() {
            return;
        }
        match self
            .call("session/close", json!({"sessionId": sid}), DEFAULT_TIMEOUT)
            .await
        {
            Ok(_) => emit(json!({
                "type": "session.status",
                "sessionId": sid,
                "properties": {"status": {"type": "closed"}},
            })),
            Err(e) => emit(error_event(e.to_string())),
        }
    }

    async fn do_delete(&self, sid: &str) {
        if sid.is_empty() {
            return;
        }
        match self
            .call("session/delete", json!({"sessionId": sid}), DEFAULT_TIMEOUT)
            .await
        {
            Ok(_) => emit(json!({
                "type": "session.status",
                "sessionId": sid,
                "properties": {"status": {"type": "deleted"}},
            })),
            Err(e) => emit(error_event(e.to_string())),
        }
    }

    async fn do_fork(&self, sid: &str, cmd_cwd: &str) {
        if sid.is_empty() {
            return;
        }
        match self
            .call(
                "session/fork",
                json!({
                    "sessionId": sid,
                    "cwd": cwd_of(cmd_cwd),
                    "mcpServers": crate::config::mcp_servers(),
                }),
                DEFAULT_TIMEOUT,
            )
            .await
        {
            Ok(res) => emit(json!({
                "type": "session.forked",
                "sessionId": res.get("sessionId").and_then(Value::as_str).unwrap_or(""),
            })),
            Err(e) => emit(error_event(e.to_string())),
        }
    }

    async fn do_cancel(&self, sid: &str) {
        if sid.is_empty() {
            return;
        }
        let mut matched: Vec<(String, PendingPerm)> = Vec::new();
        {
            let mut perms = self.perm_opt.lock().unwrap();
            let keys: Vec<String> = perms
                .iter()
                .filter(|(_, p)| p.options.iter().any(|o| o.session_id == sid))
                .map(|(k, _)| k.clone())
                .collect();
            for k in keys {
                if let Some(p) = perms.remove(&k) {
                    matched.push((k, p));
                }
            }
        }
        for (_, p) in matched {
            let _ = self.reply(&p.id, &json!({"outcome": {"outcome": "cancelled"}}));
        }
        let _ = self.notify("session/cancel", &json!({"sessionId": sid}));
    }

    async fn do_sync(&self, sid: &str, cmd_cwd: &str) {
        if !sid.is_empty() {
            if let Err(e) = self.ensure_known(sid, &cwd_of(cmd_cwd)).await {
                emit(error_event(e.to_string()));
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Entry point
// ---------------------------------------------------------------------------

pub async fn cmd_acp() -> Result<()> {
    let mut child = Command::new("opencode")
        .arg("acp")
        .env("XDG_DATA_HOME", data_home())
        .env("OPENCODE_DATA_DIR", opencode_data_dir())
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit())
        .spawn()
        .context("spawn opencode acp")?;

    let child_stdin = child.stdin.take().context("child stdin")?;
    let child_stdout = child.stdout.take().context("child stdout")?;

    // All writes to the child are funnelled through one task owning ChildStdin.
    let (write_tx, mut write_rx) = mpsc::unbounded::<String>();
    smol::spawn(async move {
        let mut stdin = child_stdin;
        while let Some(line) = write_rx.next().await {
            if stdin.write_all(line.as_bytes()).await.is_err() || stdin.flush().await.is_err() {
                break;
            }
        }
    })
    .detach();

    let bridge = Arc::new(Bridge::new(write_tx));

    // Read the child's stdout, line by line, forever.
    {
        let b = bridge.clone();
        smol::spawn(async move {
            let mut lines = BufReader::new(child_stdout).lines();
            while let Some(line) = lines.next().await {
                match line {
                    Ok(l) => b.handle_line(&l).await,
                    Err(_) => break,
                }
            }
        })
        .detach();
    }

    // Watch the child's exit status. Go only fails pendings/emits when Wait()
    // returned an error (i.e. non-zero exit or spawn error); a clean exit is
    // deliberately silent.
    {
        let b = bridge.clone();
        smol::spawn(async move {
            let status = child.status().await;
            let message = match status {
                Ok(s) if s.success() => {
                    // Go stays silent on a clean exit, but its next write fails
                    // on the closed pipe. Mark the bridge dead so send_raw
                    // fails fast instead of waiting out a timeout.
                    b.exited.store(true, Ordering::Relaxed);
                    return;
                }
                Ok(s) => s.to_string(),
                Err(e) => e.to_string(),
            };
            b.on_child_exit(message).await;
        })
        .detach();
    }

    // initialize before ready (Go: cmdAcp returns the error on failure).
    let init_res = bridge
        .call(
            "initialize",
            json!({
                "protocolVersion": 1,
                "clientCapabilities": {
                    "elicitation": {"form": {}},
                    "session": {"compaction": {}},
                    "_meta": {"opencode/child-session-updates": true},
                },
            }),
            DEFAULT_TIMEOUT,
        )
        .await
        .context("initialize")?;
    let prompt_caps = init_res
        .get("agentCapabilities")
        .and_then(|a| a.get("promptCapabilities"));
    bridge.allow_image.store(
        prompt_caps
            .and_then(|p| p.get("image"))
            .and_then(Value::as_bool)
            .unwrap_or(false),
        Ordering::Relaxed,
    );
    bridge.allow_embedded.store(
        prompt_caps
            .and_then(|p| p.get("embeddedContext"))
            .and_then(Value::as_bool)
            .unwrap_or(false),
        Ordering::Relaxed,
    );
    emit(json!({"type": "ready"}));

    // Our own stdin: one blocking thread feeds an async channel; one smol task
    // per command (matching Go's `go br.doXxx(c)`).
    let (cmd_tx, mut cmd_rx) = mpsc::unbounded::<String>();
    std::thread::spawn(move || {
        use std::io::BufRead;
        let stdin = std::io::stdin();
        for line in stdin.lock().lines() {
            match line {
                Ok(l) => {
                    if cmd_tx.unbounded_send(l).is_err() {
                        break;
                    }
                }
                Err(_) => break,
            }
        }
    });

    while let Some(line) = cmd_rx.next().await {
        let line = line.trim();
        if line.is_empty() {
            continue;
        }
        let raw: Value = match serde_json::from_str(line) {
            Ok(v) => v,
            Err(e) => {
                emit(error_event(format!("invalid command: {}", e)));
                continue;
            }
        };
        // `HarnessCommand`'s internal tag rejects unknown commands for us.
        match serde_json::from_value::<HarnessCommand>(raw) {
            Ok(cmd) => {
                let b = bridge.clone();
                smol::spawn(async move {
                    b.handle_command(cmd).await;
                })
                .detach();
            }
            Err(e) => emit(error_event(format!("invalid command: {}", e))),
        }
    }

    Ok(())
}
