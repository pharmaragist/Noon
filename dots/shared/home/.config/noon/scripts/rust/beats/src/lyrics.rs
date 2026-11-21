//! Lyrics fetching and caching for the beats library.

use anyhow::Result;
use serde::Deserialize;
use serde_json::Value;
use std::collections::HashSet;
use std::fs;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::{Mutex, OnceLock};
use std::time::Instant;

use super::clean::{clean_artist, clean_title, is_latin, query_tokens, split_segments};
use super::models::Track;
use super::store;

const LRC_HOST: &str = "https://lrclib.net/api/search";
const LYRICS_UA: &str = "beats-lyrics/1.0";

static AGENT: OnceLock<ureq::Agent> = OnceLock::new();

#[derive(Deserialize)]
struct LrcResult {
    #[serde(rename = "trackName", default)]
    track: String,
    #[serde(rename = "artistName", default)]
    artist: String,
    #[serde(default)]
    duration: Value,
    #[serde(rename = "syncedLyrics", default)]
    synced: String,
    #[serde(rename = "plainLyrics", default)]
    plain: String,
}

pub(crate) fn stem_of(rel: &str) -> String {
    let base = rel.rsplit('/').next().unwrap_or(rel);
    let prefix = rel.len() - base.len();
    match base.rfind('.') {
        Some(i) if i > 0 => rel[..prefix + i].to_string(),
        _ => rel.to_string(),
    }
}

fn lrc_path(music_dir: &str, rel: &str) -> PathBuf {
    store::lyrics_dir(music_dir).join(format!("{}.lrc", stem_of(rel)))
}

fn agent() -> &'static ureq::Agent {
    AGENT.get_or_init(|| {
        let config = ureq::config::Config::builder()
            .timeout_global(Some(std::time::Duration::from_secs(10)))
            .build();
        ureq::Agent::new_with_config(config)
    })
}

fn fetch_json(params: &[(&str, String)]) -> Option<Value> {
    let mut request = agent().get(LRC_HOST);
    for (key, value) in params {
        request = request.query(*key, value);
    }
    let mut response = request.header("User-Agent", LYRICS_UA).call().ok()?;
    if !(200..300).contains(&response.status().as_u16()) {
        return None;
    }
    let bytes = response
        .body_mut()
        .with_config()
        .limit(8 * 1024 * 1024)
        .read_to_vec()
        .ok()?;
    serde_json::Deserializer::from_slice(&bytes)
        .into_iter::<Value>()
        .next()?
        .ok()
}

fn search_attempts(title: &str, artist: &str) -> Vec<Vec<(&'static str, String)>> {
    let segments = split_segments(title);
    if segments.len() > 1 {
        return segments
            .into_iter()
            .take(4)
            .map(|s| vec![("q", s)])
            .collect();
    }
    let free = format!("{title} {artist}");
    if !is_latin(title) {
        return vec![vec![("q", free)]];
    }
    let clean_artist = clean_artist(artist);
    vec![
        vec![
            ("track_name", clean_title(title, &clean_artist)),
            ("artist_name", clean_artist.clone()),
        ],
        vec![("q", free)],
    ]
}

fn duration_ok(duration: &Value, want: f64) -> bool {
    if want == 0.0 {
        return true;
    }
    let got = match duration {
        Value::Number(n) => n.as_f64(),
        Value::String(s) => s.trim().parse::<f64>().ok(),
        _ => None,
    };
    match got {
        Some(got) if got != 0.0 => (got - want).abs() <= 3.0,
        _ => true,
    }
}

fn name_ok(track: &str, artist: &str, tokens: &[String]) -> bool {
    if tokens.is_empty() {
        return true;
    }
    let hay = format!("{track} {artist}").to_lowercase();
    tokens.iter().any(|t| hay.contains(t))
}

pub fn get_lyrics(title: &str, artist: &str, music_dir: &str, rel: &str, duration: f64) -> String {
    let title = title.trim();
    let artist = artist.trim();
    if title.is_empty() || rel.is_empty() {
        return String::new();
    }
    let path = lrc_path(music_dir, rel);
    if let Ok(data) = fs::read(&path) {
        return String::from_utf8_lossy(&data).into_owned();
    }
    let tokens = query_tokens(title, artist);
    let mut synced = String::new();
    let mut plain = String::new();
    for params in search_attempts(title, artist) {
        let Some(value) = fetch_json(&params) else {
            return String::new();
        };
        let Some(list) = value.as_array() else {
            continue;
        };
        for item in list {
            let Ok(result) = serde_json::from_value::<LrcResult>(item.clone()) else {
                return String::new();
            };
            if !duration_ok(&result.duration, duration)
                || !name_ok(&result.track, &result.artist, &tokens)
            {
                continue;
            }
            if synced.is_empty() && !result.synced.is_empty() {
                synced = result.synced;
            }
            if plain.is_empty() && !result.plain.is_empty() {
                plain = result.plain;
            }
        }
        if !synced.is_empty() {
            break;
        }
    }
    if !synced.is_empty() {
        let Some(parent) = path.parent() else {
            return String::new();
        };
        if fs::create_dir_all(parent).is_err() {
            return String::new();
        }
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            let _ = fs::set_permissions(parent, fs::Permissions::from_mode(0o755));
        }
        let mut options = fs::OpenOptions::new();
        options.write(true).create(true).truncate(true);
        #[cfg(unix)]
        {
            use std::os::unix::fs::OpenOptionsExt;
            options.mode(0o644);
        }
        if let Ok(mut file) = options.open(&path) {
            if file.write_all(synced.as_bytes()).is_ok() {
                return synced;
            }
        }
        return String::new();
    }
    plain
}

fn read_library(music_dir: &str) -> Result<Vec<Track>> {
    store::read_json::<Vec<Track>>(&store::library_path(music_dir))
}

fn short_title(s: &str) -> &str {
    match s.char_indices().nth(40) {
        Some((i, _)) => &s[..i],
        None => s,
    }
}

struct Progress {
    done: usize,
    found: usize,
}

pub fn fetch_all(music_dir: &str, limit: Option<usize>, workers: usize) {
    let tracks = match read_library(music_dir) {
        Ok(tracks) => tracks,
        Err(e) => {
            eprintln!(
                "beats: cannot read {}: {e}",
                store::library_path(music_dir).display()
            );
            return;
        }
    };
    let mut todo: Vec<Track> = tracks
        .iter()
        .filter(|t| !t.title.trim().is_empty() && !t.file.is_empty())
        .filter(|t| !lrc_path(music_dir, &t.file).exists())
        .cloned()
        .collect();
    if let Some(limit) = limit {
        if limit > 0 && todo.len() > limit {
            todo.truncate(limit);
        }
    }
    let total = todo.len();
    let workers = workers.max(1);
    println!(
        "{} tracks | {total} without lyrics | {workers} workers",
        tracks.len()
    );
    if total == 0 {
        println!("fetched 0/0. done.");
        return;
    }
    let start = Instant::now();
    let index = AtomicUsize::new(0);
    let progress = Mutex::new(Progress { done: 0, found: 0 });
    std::thread::scope(|scope| {
        for _ in 0..workers.min(total) {
            scope.spawn(|| loop {
                let i = index.fetch_add(1, Ordering::Relaxed);
                if i >= total {
                    break;
                }
                let track = &todo[i];
                let text = get_lyrics(
                    &track.title,
                    &track.artist,
                    music_dir,
                    &track.file,
                    track.duration,
                );
                let mut state = progress.lock().unwrap_or_else(|e| e.into_inner());
                state.done += 1;
                let mark = if text.is_empty() {
                    "-"
                } else {
                    state.found += 1;
                    "+"
                };
                let eta = (start.elapsed().as_secs_f64() / state.done as f64)
                    * (total - state.done) as f64;
                println!(
                    "[{}/{}] {} {}  (eta {}s)",
                    state.done,
                    total,
                    mark,
                    short_title(&track.title),
                    eta as u64
                );
            });
        }
    });
    let state = progress.lock().unwrap_or_else(|e| e.into_inner());
    println!("fetched {}/{total}. done.", state.found);
}

fn prune_dir(dir: &Path, by_base: bool, valid: &HashSet<String>) -> usize {
    let mut removed = 0;
    for entry in walkdir::WalkDir::new(dir) {
        let Ok(entry) = entry else { continue };
        if entry.file_type().is_dir() {
            continue;
        }
        let key = if by_base {
            entry.file_name().to_string_lossy().into_owned()
        } else {
            entry
                .path()
                .strip_prefix(dir)
                .map(|p| p.to_string_lossy().replace('\\', "/"))
                .unwrap_or_else(|_| entry.file_name().to_string_lossy().into_owned())
        };
        if !valid.contains(&key) && fs::remove_file(entry.path()).is_ok() {
            removed += 1;
        }
    }
    removed
}

pub fn prune_orphans(music_dir: &str) -> Result<()> {
    let Ok(tracks) = read_library(music_dir) else {
        return Ok(());
    };
    let mut covers = HashSet::new();
    let mut lyrics = HashSet::new();
    for track in tracks {
        if !track.file.is_empty() {
            lyrics.insert(format!("{}.lrc", stem_of(&track.file)));
        }
        if !track.cover.is_empty() {
            covers.insert(
                Path::new(&track.cover)
                    .file_name()
                    .map(|n| n.to_string_lossy().into_owned())
                    .unwrap_or_default(),
            );
        }
    }
    let mut removed = prune_dir(&store::covers_dir(music_dir), true, &covers);
    removed += prune_dir(&store::lyrics_dir(music_dir), false, &lyrics);
    if removed > 0 {
        println!("beats: pruned {removed} orphan art/lyric files");
    }
    Ok(())
}
