//! Config persistence for beats (~/.noon/user/beats.json).

use anyhow::{anyhow, Result};
use serde_json::{Map, Value};
use std::fs;
use std::path::PathBuf;

pub fn conf_path() -> Result<PathBuf> {
    let home = std::env::var("HOME").map_err(|_| anyhow!("cannot determine home directory"))?;
    Ok(PathBuf::from(home).join(".noon/user/beats.json"))
}

pub fn load() -> Result<Value> {
    let path = conf_path()?;
    let text = match fs::read_to_string(&path) {
        Ok(text) => text,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(Value::Object(Map::new())),
        Err(e) => return Err(anyhow!("config load {}: {e}", path.display())),
    };
    if text.trim().is_empty() {
        return Ok(Value::Object(Map::new()));
    }
    match serde_json::from_str(&text)? {
        Value::Object(map) => Ok(Value::Object(map)),
        Value::Null => Ok(Value::Object(Map::new())),
        _other => Err(anyhow!("config load {}: expected object", path.display())),
    }
    .map_err(|e| anyhow!("config load {}: {e}", path.display()))
}

pub fn save(value: &Value) -> Result<()> {
    let path = conf_path()?;
    let dir = path
        .parent()
        .ok_or_else(|| anyhow!("config has no parent"))?;
    fs::create_dir_all(dir)?;
    let mut text = serde_json::to_string_pretty(value)?;
    text.push('\n');
    let tmp = dir.join(format!(".beats.json.{}", std::process::id()));
    fs::write(&tmp, text)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&tmp, fs::Permissions::from_mode(0o644))?;
    }
    fs::rename(&tmp, &path)?;
    Ok(())
}

fn expand_home(s: &str) -> String {
    if s == "~" {
        std::env::var("HOME").unwrap_or_default()
    } else if let Some(rest) = s.strip_prefix("~/") {
        format!("{}/{}", std::env::var("HOME").unwrap_or_default(), rest)
    } else {
        s.to_string()
    }
}

pub fn music_dir() -> Result<String> {
    let cfg = load()?;
    match cfg.get("directory").and_then(Value::as_str) {
        Some(dir) if !dir.trim().is_empty() => Ok(expand_home(dir)),
        _ => Err(anyhow!(
            "beats.json missing: directory — run 'beats init' or set via shell"
        )),
    }
}

pub fn music_dir_or_fail() -> String {
    match music_dir() {
        Ok(dir) => dir,
        Err(e) => {
            eprintln!("beats: {e}");
            std::process::exit(1);
        }
    }
}

pub fn set_directory(dir: &str) -> Result<()> {
    if dir.trim().is_empty() {
        return Err(anyhow!("directory cannot be empty"));
    }
    let mut cfg = load()?;
    let map = cfg
        .as_object_mut()
        .ok_or_else(|| anyhow!("config is not an object"))?;
    map.insert("directory".into(), Value::String(expand_home(dir)));
    save(&cfg)
}
