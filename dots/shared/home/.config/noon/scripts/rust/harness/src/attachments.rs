//! Native attachment handling. QML passes paths only; all reading, MIME
//! classification and ACP content-block encoding happens here.

use anyhow::{anyhow, Result};
use base64::Engine;
use serde_json::{json, Value};
use std::fs;
use std::path::{Path, PathBuf};

/// Larger files degrade to a resource link instead of blowing up the prompt.
const MAX_BYTES: u64 = 2 * 1024 * 1024;

fn local_path(raw: &str, cwd: &str) -> PathBuf {
    let raw = raw.trim();
    let stripped = raw.strip_prefix("file://").unwrap_or(raw);
    let path = Path::new(stripped);
    if path.is_absolute() {
        path.to_path_buf()
    } else {
        Path::new(cwd).join(path)
    }
}

fn mime_for(path: &Path) -> &'static str {
    let ext = path
        .extension()
        .and_then(|e| e.to_str())
        .unwrap_or("")
        .to_ascii_lowercase();
    match ext.as_str() {
        "png" => "image/png",
        "jpg" | "jpeg" => "image/jpeg",
        "gif" => "image/gif",
        "webp" => "image/webp",
        "svg" => "image/svg+xml",
        "bmp" => "image/bmp",
        "txt" | "md" | "json" | "jsonc" | "rs" | "go" | "py" | "js" | "ts" | "lua" | "qml"
        | "sh" | "yaml" | "yml" | "toml" | "csv" | "log" => "text/plain",
        "html" | "htm" => "text/html",
        "pdf" => "application/pdf",
        _ => "application/octet-stream",
    }
}

fn resource_link(path: &Path) -> Value {
    json!({
        "type": "resource_link",
        "uri": format!("file://{}", path.display()),
        "name": path.file_name().unwrap_or_default().to_string_lossy(),
    })
}

/// Convert attachment paths into ACP content blocks. Callers append these
/// after the user's text block in `session/prompt`.
pub fn content_blocks(
    paths: &[String],
    cwd: &str,
    allow_image: bool,
    allow_embedded: bool,
) -> Result<Vec<Value>> {
    let mut blocks = Vec::new();
    for raw in paths {
        if raw.trim().is_empty() {
            continue;
        }
        let path = local_path(raw, cwd);
        let meta = fs::metadata(&path)
            .map_err(|e| anyhow!("attachment {}: {e}", path.display()))?;
        if meta.len() > MAX_BYTES {
            blocks.push(resource_link(&path));
            continue;
        }
        let bytes = fs::read(&path)
            .map_err(|e| anyhow!("attachment {}: {e}", path.display()))?;
        let mime_type = mime_for(&path);

        if mime_type.starts_with("image/") {
            if allow_image {
                blocks.push(json!({
                    "type": "image",
                    "data": base64::engine::general_purpose::STANDARD.encode(&bytes),
                    "mimeType": mime_type,
                }));
            } else {
                blocks.push(resource_link(&path));
            }
            continue;
        }

        if allow_embedded {
            let resource = if mime_type.starts_with("text/") || mime_type == "application/json" {
                json!({
                    "uri": format!("file://{}", path.display()),
                    "mimeType": mime_type,
                    "text": String::from_utf8_lossy(&bytes),
                })
            } else {
                json!({
                    "uri": format!("file://{}", path.display()),
                    "mimeType": mime_type,
                    "blob": base64::engine::general_purpose::STANDARD.encode(&bytes),
                })
            };
            blocks.push(json!({ "type": "resource", "resource": resource }));
        } else {
            blocks.push(resource_link(&path));
        }
    }
    Ok(blocks)
}
