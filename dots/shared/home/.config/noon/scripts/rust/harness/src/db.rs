use anyhow::Result;
use crate::common::{data_home, truncate_string};
use regex::Regex;
use rusqlite::{Connection, OpenFlags};
use serde::Serialize;
use serde_json::value::RawValue;
use serde_json::Value;

#[derive(Serialize)]
pub struct Session {
    id: String,
    title: String,
    created: i64,
    updated: i64,
    directory: String,
    #[serde(rename = "projectId")]
    project_id: String,
}

#[derive(Serialize)]
pub struct ToolCall {
    tool: String,
    #[serde(rename = "callID")]
    call_id: String,
    status: String,
    input: Box<RawValue>,
    output: String,
}

#[derive(Serialize)]
pub struct Message {
    role: String,
    content: String,
    #[serde(rename = "thinkText", skip_serializing_if = "String::is_empty")]
    think_text: String,
    #[serde(rename = "rawContent")]
    raw_content: String,
    model: String,
    thinking: bool,
    done: bool,
    queued: bool,
    tools: Vec<ToolCall>,
    #[serde(rename = "annotationSources")]
    annotation_sources: Vec<Value>,
    #[serde(rename = "visibleToUser")]
    visible_to_user: bool,
    #[serde(rename = "functionPending")]
    function_pending: bool,
    #[serde(skip_serializing_if = "String::is_empty")]
    agent: String,
}

#[derive(serde::Deserialize)]
struct RowData {
    #[serde(default)]
    agent: Option<String>,
    #[serde(default)]
    model: RowModel,
    #[serde(default)]
    content: Vec<ContentPart>,
    #[serde(default)]
    text: Option<String>,
}

#[derive(serde::Deserialize, Default)]
struct RowModel {
    #[serde(default)]
    id: Option<String>,
}

#[derive(serde::Deserialize)]
struct ContentPart {
    #[serde(rename = "type", default)]
    kind: Option<String>,
    #[serde(default)]
    text: Option<String>,
    #[serde(default)]
    id: Option<String>,
    #[serde(default)]
    name: Option<String>,
    #[serde(default)]
    state: Option<Box<RawValue>>,
}

/// Mirrors Go's `st` struct: `input` is a RawMessage (byte-preserving),
/// while `error` is `interface{}` and is therefore re-marshalled with
/// alphabetically sorted keys.
#[derive(serde::Deserialize, Default)]
struct ToolState {
    #[serde(default)]
    status: String,
    #[serde(default)]
    input: Option<Box<RawValue>>,
    #[serde(default)]
    output: Option<Value>,
    #[serde(default)]
    error: Option<Value>,
}

fn open_db() -> Result<Connection> {
    let db_file = format!("{}/opencode/opencode.db", data_home());
    let uri = format!("file:{db_file}?mode=ro");
    let conn = Connection::open_with_flags(
        uri,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_URI,
    )?;
    Ok(conn)
}

fn collapse_injected_blocks(s: &str) -> String {
    let skill_header_re =
        Regex::new(r#"(?s)Follow the skill named "([^"]*)".*?<skill>.*?</skill>\s*Task:\s*"#)
            .expect("valid skill header regex");

    let s = skill_header_re
        .replace_all(s, |caps: &regex::Captures| {
            let m = &caps[0];
            if m.len() < 200 {
                return m.to_string();
            }
            let name = &caps[1];
            if name.is_empty() {
                "[<skill> context hidden]".to_string()
            } else {
                format!("[Skill \"{name}\" injected]\n\n")
            }
        })
        .into_owned();

    let skill_re = Regex::new(r#"(?s)<skill>.*?</skill>"#).expect("valid skill tag regex");
    skill_re
        .replace_all(&s, |caps: &regex::Captures| {
            let m = &caps[0];
            if m.len() < 200 {
                m.to_string()
            } else {
                "[<skill> context hidden]".to_string()
            }
        })
        .into_owned()
}

fn json_string(v: Option<&Value>) -> String {
    match v {
        Some(Value::String(s)) => s.clone(),
        _ => String::new(),
    }
}

pub fn cmd_sessions() -> Result<()> {
    let conn = open_db()?;
    let mut stmt = conn.prepare(
        "SELECT id, title, time_created, time_updated, directory, project_id \
         FROM session_v2 ORDER BY time_updated DESC",
    )?;
    let rows = stmt.query_map([], |row| {
        Ok(Session {
            id: row.get(0)?,
            title: row.get::<_, Option<String>>(1)?.unwrap_or_default(),
            created: row.get(2)?,
            updated: row.get(3)?,
            directory: row.get(4)?,
            project_id: row.get(5)?,
        })
    })?;

    let out: Vec<Session> = rows.collect::<rusqlite::Result<Vec<_>>>()?;
    crate::events::emit(&out)?;
    Ok(())
}

pub fn cmd_chat(session_id: &str, limit: i64, offset: i64) -> Result<()> {
    let limit = limit.clamp(1, 50);
    let offset = offset.max(0);

    let conn = open_db()?;
    let mut stmt = conn.prepare(
        "SELECT seq, type, data FROM session_message WHERE session_id = ? \
         ORDER BY seq DESC LIMIT ? OFFSET ?",
    )?;
    let rows = stmt.query_map(rusqlite::params![session_id, limit, offset], |row| {
        Ok((
            row.get::<_, i64>(0)?,
            row.get::<_, String>(1)?,
            row.get::<_, String>(2)?,
        ))
    })?;

    let mut collected: Vec<(i64, String, String)> =
        rows.collect::<rusqlite::Result<Vec<_>>>()?;
    collected.reverse();

    let mut out: Vec<Message> = Vec::new();
    for (_seq, typ, data) in collected {
        let d: RowData = match serde_json::from_str(&data) {
            Ok(d) => d,
            Err(_) => continue,
        };

        let mut txt = String::new();
        let mut think = String::new();
        let mut tools: Vec<ToolCall> = Vec::new();

        if typ == "user" {
            txt.push_str(d.text.as_deref().unwrap_or(""));
        } else {
            for part in &d.content {
                match part.kind.as_deref().unwrap_or("") {
                    "text" => txt.push_str(part.text.as_deref().unwrap_or("")),
                    "reasoning" => think.push_str(part.text.as_deref().unwrap_or("")),
                    "tool" => {
                        let state: ToolState = part
                            .state
                            .as_ref()
                            .and_then(|raw| serde_json::from_str(raw.get()).ok())
                            .unwrap_or_default();
                        let input = match state.input {
                            Some(raw) => raw,
                            None => serde_json::from_str("null")?,
                        };
                        let mut output = json_string(state.output.as_ref());
                        if output.is_empty() {
                            if let Some(err) = state.error.filter(|v| !v.is_null()) {
                                output = match err {
                                    Value::String(s) => s,
                                    other => serde_json::to_string(&other)?,
                                };
                            }
                        }
                        tools.push(ToolCall {
                            tool: part.name.clone().unwrap_or_default(),
                            call_id: part.id.clone().unwrap_or_default(),
                            status: state.status,
                            input,
                            output: truncate_string(&output, 4000),
                        });
                    }
                    _ => {}
                }
            }
        }

        if typ == "user" && txt.trim().is_empty() {
            continue;
        }
        if typ != "user"
            && txt.trim().is_empty()
            && think.trim().is_empty()
            && tools.is_empty()
        {
            continue;
        }

        let raw = truncate_string(&txt, 100000);
        let content = truncate_string(&collapse_injected_blocks(&txt), 30000);
        let role = if typ != "user" && typ != "assistant" {
            "assistant".to_string()
        } else {
            typ
        };

        out.push(Message {
            role,
            content,
            think_text: truncate_string(&think, 30000),
            raw_content: raw,
            model: d.model.id.unwrap_or_default(),
            thinking: false,
            done: true,
            queued: false,
            tools,
            annotation_sources: Vec::new(),
            visible_to_user: true,
            function_pending: false,
            agent: d.agent.unwrap_or_default(),
        });
    }

    crate::events::emit(&out)?;
    Ok(())
}
