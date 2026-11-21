//! Atomic file I/O and path helpers for beats state.

use anyhow::{anyhow, Context, Result};
use serde::de::DeserializeOwned;
use serde::Serialize;
use std::fs;
use std::path::{Path, PathBuf};

use super::models::Command;

fn beats_dir() -> PathBuf {
    let home = std::env::var("HOME").unwrap_or_else(|_| "/tmp".into());
    PathBuf::from(home).join(".cache/noon/beats")
}

pub fn pid_path() -> PathBuf {
    beats_dir().join("daemon.pid")
}

pub fn log_path() -> PathBuf {
    beats_dir().join("daemon.log")
}

pub fn cmd_path(music_dir: &str) -> PathBuf {
    PathBuf::from(music_dir).join(".beats/cmd.json")
}

pub fn lyrics_path(music_dir: &str) -> PathBuf {
    PathBuf::from(music_dir).join(".beats/lyrics.json")
}

pub fn library_path(music_dir: &str) -> PathBuf {
    PathBuf::from(music_dir).join(".beats/library.json")
}

pub fn covers_dir(music_dir: &str) -> PathBuf {
    PathBuf::from(music_dir).join(".beats/coverarts")
}

pub fn lyrics_dir(music_dir: &str) -> PathBuf {
    PathBuf::from(music_dir).join(".beats/lyrics")
}

pub fn write_json<T: Serialize>(path: &Path, value: &T) -> Result<()> {
    let dir = path
        .parent()
        .ok_or_else(|| anyhow!("no parent directory"))?;
    fs::create_dir_all(dir)?;
    let data = serde_json::to_vec(value)?;
    let tmp = dir.join(format!(".json-{}", std::process::id()));
    fs::write(&tmp, &data)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&tmp, fs::Permissions::from_mode(0o644))?;
    }
    fs::rename(&tmp, path)?;
    Ok(())
}

pub fn read_json<T: DeserializeOwned>(path: &Path) -> Result<T> {
    let text =
        fs::read_to_string(path).with_context(|| format!("store read {}", path.display()))?;
    serde_json::from_str(&text).with_context(|| format!("store read {}", path.display()))
}

pub fn consume_cmd(music_dir: &str) -> Result<Option<Command>> {
    let path = cmd_path(music_dir);
    let text = match fs::read_to_string(&path) {
        Ok(text) => text,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(None),
        Err(e) => return Err(e.into()),
    };
    let cmd: Command = match serde_json::from_str(&text) {
        Ok(cmd) => cmd,
        Err(e) => {
            eprintln!("beats: bad cmd file: {e}");
            let _ = fs::remove_file(&path);
            return Ok(None);
        }
    };
    fs::remove_file(&path).with_context(|| format!("store consume {}", path.display()))?;
    Ok(Some(cmd))
}
