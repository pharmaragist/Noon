//! Embedded cover extraction.

use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicUsize, Ordering};
use std::sync::Mutex;
use std::sync::OnceLock;
use std::time::SystemTime;

use anyhow::Result;
use lofty::picture::MimeType;
use lofty::prelude::*;
use rayon::prelude::*;

use super::library::get_library;
use super::store;

static MPRIS_ART: OnceLock<Mutex<HashMap<String, (Option<SystemTime>, PathBuf)>>> = OnceLock::new();

fn cover_ok(music_dir: &str, cover: &str) -> bool {
    if cover.is_empty() {
        return false;
    }
    fs::metadata(Path::new(music_dir).join(cover))
        .map(|m| m.is_file() && m.len() > 0)
        .unwrap_or(false)
}

fn valid_image(data: &[u8]) -> bool {
    data.len() >= 64
        && ((data[0] == 0xFF && data[1] == 0xD8 && data[2] == 0xFF)
            || data.starts_with(&[0x89, b'P', b'N', b'G']))
}

fn extract_cover(abs: &Path) -> Option<(Vec<u8>, String)> {
    let tagged = lofty::read_from_path(abs).ok()?;
    let picture = tagged.primary_tag()?.pictures().first()?;
    let data = picture.data();
    if !valid_image(data) {
        return None;
    }
    let png =
        picture.mime_type() == Some(&MimeType::Png) || data.starts_with(&[0x89, b'P', b'N', b'G']);
    Some((data.to_vec(), if png { "png" } else { "jpg" }.to_string()))
}

pub fn art_path(dir: &str, rel: &str) -> Option<PathBuf> {
    let abs = Path::new(dir).join(rel);
    let mtime = fs::metadata(&abs).and_then(|m| m.modified()).ok();
    let cache = MPRIS_ART.get_or_init(|| Mutex::new(HashMap::new()));
    if let Ok(map) = cache.lock() {
        if let Some((stamped, path)) = map.get(rel) {
            if stamped == &mtime && path.is_file() {
                return Some(path.clone());
            }
        }
    }
    let (data, ext) = extract_cover(&abs)?;
    let out_dir = store::mpris_art_dir();
    let name = format!("{:x}", md5::compute(rel.as_bytes()));
    let path = out_dir.join(format!("{name}.{ext}"));
    if !path.is_file() {
        fs::create_dir_all(&out_dir).ok()?;
        let tmp = path.with_extension(format!("tmp-{}", std::process::id()));
        fs::write(&tmp, &data).ok()?;
        fs::rename(&tmp, &path).ok()?;
    }
    if let Ok(mut map) = cache.lock() {
        map.insert(rel.to_string(), (mtime, path.clone()));
    }
    Some(path)
}

pub fn build_covers(music_dir: &str) -> Result<()> {
    let tracks = get_library(music_dir)?;
    let pending: Vec<String> = tracks
        .iter()
        .filter(|t| !cover_ok(music_dir, &t.cover))
        .map(|t| t.file.clone())
        .collect();
    let workers = rayon::current_num_threads().max(1);
    eprintln!("  Total:   {}", tracks.len());
    eprintln!("  Cached:  {}", tracks.len() - pending.len());
    eprintln!("  Pending: {}", pending.len());
    eprintln!("  Workers: {workers}\n");

    if pending.is_empty() {
        eprintln!("  Nothing to do.");
        return Ok(());
    }

    let covers_dir = store::covers_dir(music_dir);
    fs::create_dir_all(&covers_dir)?;

    let dedup: Mutex<HashMap<String, PathBuf>> = Mutex::new(HashMap::new());
    let added: Mutex<HashMap<String, String>> = Mutex::new(HashMap::new());
    let done = AtomicUsize::new(0);
    let total = pending.len();

    pending.par_iter().for_each(|rel| {
        let abs = PathBuf::from(music_dir).join(rel);
        let Some((data, ext)) = extract_cover(&abs) else {
            return;
        };
        let digest = format!("{:x}", md5::compute(rel.as_bytes()));
        let name = &digest[..12];
        let out = covers_dir.join(format!("{name}.{ext}"));

        let sum = format!("{:x}", md5::compute(&data));
        let key = &sum[..16];
        let mut seen = dedup.lock().unwrap();
        if let Some(src) = seen.get(key).cloned() {
            if fs::hard_link(&src, &out).is_err() && fs::write(&out, &data).is_err() {
                eprintln!("  [COVER ERR] {rel}");
                return;
            }
        } else if fs::write(&out, &data).is_err() {
            eprintln!("  [COVER ERR] {rel}");
            return;
        }
        seen.entry(key.to_string()).or_insert_with(|| out.clone());
        drop(seen);

        let cover_rel = out
            .strip_prefix(music_dir)
            .unwrap_or(&out)
            .to_string_lossy()
            .replace('\\', "/");
        added.lock().unwrap().insert(rel.clone(), cover_rel);
        let n = done.fetch_add(1, Ordering::Relaxed) + 1;
        eprintln!("  [{n}/{total}] {rel}");
    });

    let added = added.into_inner().unwrap();
    let n = done.load(Ordering::Relaxed);
    if n > 0 {
        let mut tracks = tracks;
        for track in &mut tracks {
            if let Some(cover) = added.get(&track.file) {
                track.cover = cover.clone();
            }
        }
        store::write_json(&store::library_path(music_dir), &tracks)?;
    }
    eprintln!("\nDone. {n} new covers extracted.");
    Ok(())
}
