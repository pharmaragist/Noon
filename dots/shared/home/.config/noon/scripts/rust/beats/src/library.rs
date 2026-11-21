//! Library scanning and mtime-keyed index.

use std::collections::HashMap;
use std::ffi::OsStr;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{Arc, Mutex, OnceLock};
use std::time::SystemTime;

use anyhow::{anyhow, Result};
use chrono::{DateTime, Utc};
use lofty::prelude::*;
use lofty::tag::{ItemKey, Tag};
use rayon::prelude::*;
use walkdir::WalkDir;

use super::models::{Track, LAST_MODIFIED_LAYOUT};
use super::store;

const AUDIO_EXTS: &[&str] = &[
    "mp3", "flac", "ogg", "opus", "m4a", "aac", "wav", "wma", "mp4",
];

type IndexCache = HashMap<String, (i64, Arc<HashMap<String, Track>>)>;
static INDEX: OnceLock<Mutex<IndexCache>> = OnceLock::new();

fn slash(path: &Path) -> String {
    path.to_string_lossy().replace('\\', "/")
}

fn is_audio(path: &Path) -> bool {
    path.extension()
        .and_then(OsStr::to_str)
        .is_some_and(|ext| AUDIO_EXTS.iter().any(|e| ext.eq_ignore_ascii_case(e)))
}

fn iso_mtime(path: &Path) -> String {
    let modified = fs::metadata(path)
        .and_then(|m| m.modified())
        .unwrap_or(SystemTime::UNIX_EPOCH);
    DateTime::<Utc>::from(modified)
        .format(LAST_MODIFIED_LAYOUT)
        .to_string()
}

fn scan_mtimes(music_dir: &str) -> Result<HashMap<String, String>> {
    let root = Path::new(music_dir);
    if !fs::metadata(root)?.is_dir() {
        return Err(anyhow!("library scan {music_dir}: not a directory"));
    }
    let files: Vec<PathBuf> = WalkDir::new(root)
        .into_iter()
        .filter_entry(|e| !(e.file_type().is_dir() && e.file_name() == ".beats"))
        .filter_map(Result::ok)
        .filter(|e| e.file_type().is_file() && is_audio(e.path()))
        .map(|e| e.into_path())
        .collect();
    Ok(files
        .par_iter()
        .filter_map(|path| {
            let rel = path.strip_prefix(root).ok()?;
            Some((slash(rel), iso_mtime(path)))
        })
        .collect())
}

// All tags are considered: files often carry ID3v1 and ID3v2, or APEv2 alongside.
fn tag_value(tags: &[&Tag], keys: &[ItemKey]) -> String {
    tags.iter()
        .flat_map(|tag| keys.iter().filter_map(|&key| tag.get_string(key)))
        .map(str::trim)
        .find(|s| !s.is_empty())
        .unwrap_or("")
        .to_string()
}

fn read_track(music_dir: &str, rel: &str, iso_mt: &str) -> Option<Track> {
    let abs = PathBuf::from(music_dir).join(rel);
    if !abs.is_file() {
        return None;
    }
    let fallback_title = Path::new(rel)
        .file_stem()
        .map(|s| s.to_string_lossy().into_owned())
        .unwrap_or_default();
    let tagged = lofty::read_from_path(&abs).ok()?;
    let tags: Vec<&Tag> = tagged.tags().iter().collect();
    let mut track = Track {
        file: rel.to_string(),
        title: fallback_title,
        last_modified: iso_mt.to_string(),
        duration: tagged.properties().duration().as_secs_f64(),
        ..Default::default()
    };
    track.title = tag_value(&tags, &[ItemKey::TrackTitle]);
    if track.title.is_empty() {
        track.title = Path::new(rel)
            .file_stem()
            .map(|s| s.to_string_lossy().into_owned())
            .unwrap_or_default();
    }
    track.artist = tag_value(&tags, &[ItemKey::TrackArtist, ItemKey::AlbumArtist]);
    track.album = tag_value(&tags, &[ItemKey::AlbumTitle]);
    track.genre = tag_value(&tags, &[ItemKey::Genre]);
    track.date = tag_value(
        &tags,
        &[
            ItemKey::RecordingDate,
            ItemKey::Year,
            ItemKey::OriginalReleaseDate,
            ItemKey::ReleaseDate,
        ],
    );
    track.track = tag_value(&tags, &[ItemKey::TrackNumber])
        .split_once('/')
        .map(|(head, _)| head.trim().to_string())
        .unwrap_or_default();
    Some(track)
}

fn sorted_desc(mut tracks: Vec<Track>) -> Vec<Track> {
    // sort_by is stable: equal mtimes keep their persisted/scan order.
    tracks.sort_by(|a, b| b.last_modified.cmp(&a.last_modified));
    tracks
}

fn cached_tracks(music_dir: &str, mtimes: &HashMap<String, String>) -> Option<Vec<Track>> {
    let tracks = store::read_json::<Vec<Track>>(&store::library_path(music_dir)).ok()?;
    if tracks.len() != mtimes.len() {
        return None;
    }
    tracks
        .iter()
        .all(|t| mtimes.get(&t.file).map(String::as_str) == Some(t.last_modified.as_str()))
        .then_some(tracks)
}

fn mtime_key(path: &Path) -> i64 {
    let Ok(meta) = fs::metadata(path) else {
        return 0;
    };
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;
        meta.mtime_nsec() as i64
    }
    #[cfg(not(unix))]
    {
        let _ = meta;
        0
    }
}

pub fn get_library(music_dir: &str) -> Result<Vec<Track>> {
    let mtimes = scan_mtimes(music_dir)?;
    let mut rels: Vec<String> = mtimes.keys().cloned().collect();
    rels.sort();

    let cached = cached_tracks(music_dir, &mtimes);
    let pending = if cached.is_some() { 0 } else { rels.len() };
    eprintln!("  Total:   {}", rels.len());
    eprintln!("  Cached:  {}", rels.len() - pending);
    eprintln!("  Pending: {pending}");
    eprintln!("  Workers: {}", rayon::current_num_threads().max(1));

    if let Some(cached) = cached {
        return Ok(sorted_desc(cached));
    }

    let mut tracks: Vec<Track> = rels
        .par_iter()
        .filter_map(|rel| read_track(music_dir, rel, &mtimes[rel]))
        .collect();
    tracks = sorted_desc(tracks);
    store::write_json(&store::library_path(music_dir), &tracks)?;
    Ok(tracks)
}

pub fn track_index(music_dir: &str) -> Result<Arc<HashMap<String, Track>>> {
    let lib_file = store::library_path(music_dir);
    let stamp = mtime_key(&lib_file);
    let cache = INDEX.get_or_init(|| Mutex::new(HashMap::new()));

    if let Ok(cache) = cache.lock() {
        if let Some((cached_stamp, idx)) = cache.get(music_dir) {
            if *cached_stamp == stamp {
                return Ok(Arc::clone(idx));
            }
        }
    }

    let tracks = store::read_json::<Vec<Track>>(&lib_file)
        .or_else(|_| get_library(music_dir))
        .unwrap_or_default();
    let idx: HashMap<String, Track> = tracks.into_iter().map(|t| (t.file.clone(), t)).collect();

    let idx = Arc::new(idx);
    if let Ok(mut cache) = cache.lock() {
        cache.insert(music_dir.to_string(), (stamp, Arc::clone(&idx)));
    }
    Ok(idx)
}
