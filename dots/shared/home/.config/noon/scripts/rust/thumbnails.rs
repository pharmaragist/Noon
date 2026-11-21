//! Generate thumbnails for a wallpaper folder.

mod utils;

use std::collections::{HashMap, HashSet};
use std::fs::{self, File};
use std::os::unix::fs::MetadataExt;
use std::path::{Path, PathBuf};

use anyhow::{bail, Context, Result};
use clap::Parser;
use fd_lock::RwLock;
use image::imageops::FilterType;
use image::GenericImageView;
use png::text_metadata::TEXtChunk;
use png::{BitDepth, ColorType, Compression, Encoder};
use rayon::prelude::*;
use serde::{Deserialize, Serialize};
use url::Url;
use walkdir::WalkDir;

const VIDEO_EXTENSIONS: &[&str] = &["mp4", "webm", "mkv", "mov", "avi", "m4v"];
const SIDECAR: &str = ".thumbnails.json";
const THUMB_SIZE: u32 = 512;

#[derive(Parser)]
#[command(about = "Generate thumbnails for a wallpaper folder")]
struct Args {
    #[arg(short = 'd', long = "img_dirs")]
    dir: PathBuf,
}

#[derive(Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
struct Entry {
    hash: String,
    mtime: i64,
    file_name: String,
    uri: String,
    thumbnail_path: String,
    thumbnail_uri: String,
}

#[derive(Serialize, Deserialize)]
#[serde(default)]
struct Sidecar {
    version: u32,
    files: HashMap<String, Entry>,
}

impl Default for Sidecar {
    fn default() -> Self {
        Self {
            version: 1,
            files: HashMap::new(),
        }
    }
}

fn cache_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(|| PathBuf::from("/tmp"))
        .join("noon/media/thumbnails/wallpapers")
}

fn hash(uri: &str) -> String {
    format!("{:x}", md5::compute(uri.as_bytes()))
}

fn file_uri(path: &Path) -> Result<String> {
    let absolute =
        fs::canonicalize(path).with_context(|| format!("resolving {}", path.display()))?;
    Ok(Url::from_file_path(&absolute)
        .map_err(|_| anyhow::anyhow!("not a file URL: {}", absolute.display()))?
        .to_string())
}

fn uri_of(path: &Path) -> String {
    Url::from_file_path(path)
        .map(|url| url.to_string())
        .unwrap_or_default()
}

fn thumbnail_path(uri: &str) -> PathBuf {
    cache_dir().join(format!("{}.png", hash(uri)))
}

fn mtime(path: &Path) -> Result<i64> {
    Ok(fs::metadata(path)?.mtime())
}

fn load_sidecar(dir: &Path) -> Sidecar {
    fs::read_to_string(dir.join(SIDECAR))
        .ok()
        .and_then(|text| serde_json::from_str(&text).ok())
        .unwrap_or_default()
}

fn save_sidecar(dir: &Path, sidecar: &Sidecar) -> Result<()> {
    let temp = dir.join(".thumbnails.json.tmp");
    serde_json::to_writer_pretty(File::create(&temp)?, sidecar)?;
    fs::rename(&temp, dir.join(SIDECAR))?;
    Ok(())
}

fn write_thumbnail(
    image: &image::DynamicImage,
    uri: &str,
    modified: i64,
    target: &Path,
) -> Result<()> {
    let thumb = image.resize(THUMB_SIZE, THUMB_SIZE, FilterType::Lanczos3);
    let (width, height) = thumb.dimensions();
    let rgba = thumb.to_rgba8();
    let mut encoder = Encoder::new(File::create(target)?, width, height);
    encoder.set_color(ColorType::Rgba);
    encoder.set_depth(BitDepth::Eight);
    encoder.set_compression(Compression::Fast);
    let mut writer = encoder.write_header()?;
    writer.write_text_chunk(&TEXtChunk::new("Thumb::URI", uri))?;
    writer.write_text_chunk(&TEXtChunk::new("Thumb::MTime", modified.to_string()))?;
    writer.write_text_chunk(&TEXtChunk::new("Software", "Noon Thumbnails"))?;
    writer.write_image_data(rgba.as_raw())?;
    Ok(())
}

fn make_thumbnail(path: &Path) -> Result<Entry> {
    let uri = file_uri(path)?;
    let modified = mtime(path)?;
    let target = thumbnail_path(&uri);
    fs::create_dir_all(target.parent().context("thumbnail path has no parent")?)?;

    let is_video = path
        .extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| {
            VIDEO_EXTENSIONS.contains(&extension.to_ascii_lowercase().as_str())
        });

    let image = if is_video {
        image::DynamicImage::ImageRgb8(utils::video::frame_at(path, 0.0)?)
    } else {
        image::open(path)?
    };
    write_thumbnail(&image, &uri, modified, &target)?;

    Ok(Entry {
        hash: hash(&uri),
        mtime: modified,
        file_name: path
            .file_name()
            .unwrap_or_default()
            .to_string_lossy()
            .into_owned(),
        thumbnail_uri: uri_of(&target),
        thumbnail_path: target.to_string_lossy().into_owned(),
        uri,
    })
}

fn refresh(dir: &Path) -> Result<()> {
    if !dir.is_dir() {
        bail!("{} isn't a valid directory", dir.display());
    }
    let mut sidecar = load_sidecar(dir);
    sidecar.files.retain(|relative, entry| {
        if mtime(&dir.join(relative)).is_ok_and(|modified| modified == entry.mtime) {
            return true;
        }
        let _ = fs::remove_file(cache_dir().join(format!("{}.png", entry.hash)));
        false
    });

    let pending: Vec<(PathBuf, String)> = WalkDir::new(dir)
        .min_depth(1)
        .max_depth(1)
        .into_iter()
        .filter_map(|entry| entry.ok())
        .filter(|entry| entry.file_type().is_file())
        .map(|entry| entry.into_path())
        .filter(|path| path.file_name().and_then(|name| name.to_str()) != Some(SIDECAR))
        .filter_map(|path| {
            let relative = path
                .strip_prefix(dir)
                .unwrap_or(&path)
                .to_string_lossy()
                .into_owned();
            let stale = sidecar.files.get(&relative).is_none_or(|entry| {
                mtime(&path)
                    .map(|modified| modified != entry.mtime)
                    .unwrap_or(true)
                    || !thumbnail_path(&entry.uri).exists()
            });
            stale.then_some((path, relative))
        })
        .collect();

    let results: Vec<(String, Result<Entry>)> = pending
        .into_par_iter()
        .map(|(path, relative)| (relative, make_thumbnail(&path)))
        .collect();
    for (relative, result) in results {
        match result {
            Ok(entry) => {
                sidecar.files.insert(relative, entry);
            }
            Err(error) => eprintln!("thumbnail failed for {relative}: {error:#}"),
        }
    }

    prune(dir, &mut sidecar);
    save_sidecar(dir, &sidecar)?;
    prune_cache(&sidecar);
    Ok(())
}

fn prune(dir: &Path, sidecar: &mut Sidecar) {
    sidecar.files.retain(|relative, entry| {
        let thumbnail = Path::new(&entry.thumbnail_path).is_file();
        if !thumbnail {
            let _ = fs::remove_file(&entry.thumbnail_path);
        }
        thumbnail && dir.join(relative).is_file()
    });
}

fn prune_cache(sidecar: &Sidecar) {
    let keep: HashSet<&str> = sidecar
        .files
        .values()
        .map(|entry| entry.hash.as_str())
        .collect();
    let Ok(entries) = fs::read_dir(cache_dir()) else {
        return;
    };
    for entry in entries.flatten() {
        let path = entry.path();
        if path.extension().is_none_or(|extension| extension != "png") {
            continue;
        }
        let stem = path.file_stem().unwrap_or_default().to_string_lossy();
        if !keep.contains(stem.as_ref()) {
            let _ = fs::remove_file(path);
        }
    }
}

fn main() -> Result<()> {
    let args = Args::parse();
    let mut lock = RwLock::new(File::create(
        std::env::temp_dir().join("thumbnails_service.lock"),
    )?);
    if lock.try_write().is_err() {
        bail!("another instance is already running");
    }
    fs::create_dir_all(cache_dir())?;
    refresh(&args.dir)
}
