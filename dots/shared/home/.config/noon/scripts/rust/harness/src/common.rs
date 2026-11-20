//! Shared helpers used by more than one module.

use std::path::PathBuf;

/// Go: dataHome() — SESSION_DIR > XDG_DATA_HOME > $HOME/.local/share.
pub fn data_home() -> String {
    std::env::var("SESSION_DIR")
        .ok()
        .filter(|s| !s.is_empty())
        .or_else(|| std::env::var("XDG_DATA_HOME").ok().filter(|s| !s.is_empty()))
        .unwrap_or_else(|| format!("{}/.local/share", std::env::var("HOME").unwrap_or_default()))
}

/// Harness state root: SESSION_DIR > XDG_STATE_HOME/noon/harness > ~/.local/state/noon/harness.
pub fn state_home() -> PathBuf {
    if let Ok(dir) = std::env::var("SESSION_DIR") {
        if !dir.trim().is_empty() {
            return PathBuf::from(dir);
        }
    }
    if let Ok(dir) = std::env::var("XDG_STATE_HOME") {
        if !dir.trim().is_empty() {
            return PathBuf::from(dir).join("noon").join("harness");
        }
    }
    PathBuf::from(format!(
        "{}/.local/state/noon/harness",
        std::env::var("HOME").unwrap_or_default()
    ))
}

/// `${DISTRO}` substitution value for the bundled SOUL template.
pub fn distro() -> String {
    std::fs::read_to_string("/etc/os-release")
        .ok()
        .and_then(|s| {
            s.lines()
                .find_map(|line| line.strip_prefix("PRETTY_NAME="))
                .map(|v| v.trim().trim_matches('"').to_string())
        })
        .filter(|s| !s.is_empty())
        .unwrap_or_else(|| "Linux".to_string())
}

pub fn take_chars(s: &str, max: usize) -> String {
    s.chars().take(max).collect()
}

/// UTF-8 safe truncation with the Go harness' marker.
pub fn truncate_string(s: &str, max: usize) -> String {
    if s.chars().count() > max {
        format!("{}\n\n…(truncated)", take_chars(s, max))
    } else {
        s.to_string()
    }
}
