use std::io::Write;
use std::sync::Mutex;

use serde::Deserialize;
use serde_json::Value;

/// Serializes `value` as one JSON line on stdout and flushes it.
///
/// Writes are serialized under a global lock so concurrent smol tasks can
/// never interleave partial lines. `serde_json::to_string` leaves HTML
/// escaping off, matching the Go harness (`SetEscapeHTML(false)`).
pub fn emit<T: serde::Serialize>(value: &T) -> anyhow::Result<()> {
    let line = serde_json::to_string(value)?;
    static EMIT_LOCK: Mutex<()> = Mutex::new(());
    let _guard = EMIT_LOCK.lock().unwrap_or_else(|err| err.into_inner());
    let stdout = std::io::stdout();
    let mut out = stdout.lock();
    writeln!(out, "{line}")?;
    out.flush()?;
    Ok(())
}

#[derive(Debug, Deserialize)]
#[serde(tag = "cmd", rename_all = "lowercase")]
pub enum HarnessCommand {
    List {
        #[serde(rename = "sessionId", default)]
        session_id: String,
        #[serde(default)]
        cwd: String,
    },
    New {
        #[serde(rename = "sessionId", alias = "session_id", default)]
        session_id: String,
        #[serde(default)]
        cwd: String,
        #[serde(default)]
        model: String,
        #[serde(default)]
        effort: String,
        #[serde(default)]
        mode: String,
    },
    Send {
        #[serde(rename = "sessionId")]
        session_id: String,
        #[serde(default)]
        cwd: String,
        text: String,
        #[serde(default)]
        attachments: Vec<String>,
        #[serde(default)]
        model: String,
        #[serde(default)]
        effort: String,
        #[serde(default)]
        mode: String,
    },
    Elicit {
        #[serde(rename = "reqId")]
        req_id: ReqId,
        #[serde(default)]
        accepted: bool,
        #[serde(default)]
        content: Value,
    },
    Steer {
        #[serde(rename = "sessionId")]
        session_id: String,
        #[serde(default)]
        cwd: String,
        text: String,
    },
    Close {
        #[serde(rename = "sessionId")]
        session_id: String,
    },
    Delete {
        #[serde(rename = "sessionId")]
        session_id: String,
    },
    Fork {
        #[serde(rename = "sessionId")]
        session_id: String,
        #[serde(default)]
        cwd: String,
    },
    Model {
        #[serde(rename = "sessionId")]
        session_id: String,
        #[serde(default)]
        cwd: String,
        model: String,
    },
    Mode {
        #[serde(rename = "sessionId")]
        session_id: String,
        #[serde(default)]
        cwd: String,
        mode: String,
    },
    Reply {
        #[serde(rename = "reqId", alias = "req_id")]
        req_id: ReqId,
        #[serde(default)]
        approved: bool,
        #[serde(rename = "optionId", default)]
        option_id: String,
    },
    Cancel {
        #[serde(rename = "sessionId")]
        session_id: String,
    },
    Sync {
        #[serde(rename = "sessionId", default)]
        session_id: String,
        #[serde(default)]
        cwd: String,
    },
}

#[derive(Debug, Deserialize)]
#[serde(untagged)]
pub enum ReqId {
    Num(u64),
    Str(String),
}

impl ReqId {
    /// Normalizes a JSON number or numeric string into the request id used
    /// by the ACP bridge (Go accepted float64/string/int64).
    pub fn as_u64(&self) -> Option<u64> {
        match self {
            ReqId::Num(n) => Some(*n),
            ReqId::Str(s) => s.parse().ok(),
        }
    }
}
