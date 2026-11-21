use anyhow::{bail, Context, Result};
use bzip2::read::BzDecoder;
use clap::Parser;
use flate2::read::GzDecoder;
use std::fs::{self, File};
use std::io;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};
use tar::Archive;
use url::Url;
use xz2::read::XzDecoder;
use zip::ZipArchive;

#[derive(Parser)]
#[command(name = "thawb", about = "ocs:// install handler for noon shell")]
struct Cli {
    url: String,
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum PlasmaPkgType {
    LookAndFeel,
    Theme,
    Plasmoid,
    Aurorae,
}

impl PlasmaPkgType {
    fn as_str(self) -> &'static str {
        match self {
            Self::LookAndFeel => "look-and-feel",
            Self::Theme => "theme",
            Self::Plasmoid => "plasmoid",
            Self::Aurorae => "aurorae",
        }
    }
}

#[derive(Debug, Clone)]
enum PkgCategory {
    Themes,
    Icons,
    Cursors,
    Wallpapers,
    Fonts,
    Plasma(PlasmaPkgType),
    Other,
}

impl PkgCategory {
    fn from_raw(raw: &str) -> Self {
        match raw.trim().to_ascii_lowercase().as_str() {
            "themes" => Self::Themes,
            "icons" => Self::Icons,
            "cursors" => Self::Cursors,
            "wallpapers" => Self::Wallpapers,
            "fonts" => Self::Fonts,
            "plasma5-look-and-feel" => Self::Plasma(PlasmaPkgType::LookAndFeel),
            "plasma5-desktopthemes" => Self::Plasma(PlasmaPkgType::Theme),
            "plasma5-plasmoids" => Self::Plasma(PlasmaPkgType::Plasmoid),
            "aurorae-themes" => Self::Plasma(PlasmaPkgType::Aurorae),
            _ => Self::Other,
        }
    }

    fn target_dir(&self, home: &Path) -> PathBuf {
        match self {
            Self::Themes => home.join(".themes"),
            Self::Icons | Self::Cursors => home.join(".icons"),
            Self::Wallpapers => home.join("Pictures/Wallpapers"),
            Self::Fonts => home.join(".local/share/fonts"),
            Self::Plasma(PlasmaPkgType::LookAndFeel) => {
                home.join(".local/share/plasma/look-and-feel")
            }
            Self::Plasma(PlasmaPkgType::Theme) => home.join(".local/share/plasma/desktoptheme"),
            Self::Plasma(PlasmaPkgType::Plasmoid) => home.join(".local/share/plasma/plasmoids"),
            Self::Plasma(PlasmaPkgType::Aurorae) => home.join(".local/share/aurorae/themes"),
            Self::Other => home.join(".local/share/thawb"),
        }
    }

    fn plasma_type(&self) -> Option<PlasmaPkgType> {
        match self {
            Self::Plasma(pkg) => Some(*pkg),
            _ => None,
        }
    }
}

struct OcsInfo {
    download_url: String,
    filename: String,
    category: PkgCategory,
    name: String,
}

fn parse_ocs_url(raw: &str) -> Result<OcsInfo> {
    let parsed = Url::parse(raw).with_context(|| format!("invalid OCS URL: {raw}"))?;
    let param = |key: &str| {
        parsed
            .query_pairs()
            .find(|(name, _)| name == key)
            .map(|(_, value)| value.into_owned())
    };

    let download_url = param("url").context("missing 'url' param in OCS link")?;
    let filename = param("filename")
        .filter(|name| !name.is_empty())
        .or_else(|| {
            let url = Url::parse(&download_url).ok()?;
            url.path_segments()?.next_back().map(str::to_string)
        })
        .unwrap_or_else(|| "archive".into());
    let name = param("name")
        .filter(|name| !name.is_empty())
        .unwrap_or_else(|| filename.clone());
    let category = PkgCategory::from_raw(param("type").as_deref().unwrap_or_default());

    Ok(OcsInfo {
        download_url,
        filename,
        category,
        name,
    })
}

fn download(url: &str, destination: &Path) -> Result<()> {
    eprintln!("[thawb] downloading {url}");
    let mut reader = ureq::get(url)
        .call()
        .with_context(|| format!("failed to request {url}"))?
        .into_body()
        .into_reader();
    let mut file = File::create(destination)
        .with_context(|| format!("failed to create {}", destination.display()))?;
    io::copy(&mut reader, &mut file)
        .with_context(|| format!("failed writing to {}", destination.display()))?;
    eprintln!("[thawb] saved to {}", destination.display());
    Ok(())
}

fn extract(archive: &Path, target: &Path) -> Result<()> {
    eprintln!(
        "[thawb] extracting {} -> {}",
        archive.display(),
        target.display()
    );
    let name = archive.to_string_lossy().to_ascii_lowercase();

    if name.ends_with(".zip") {
        ZipArchive::new(File::open(archive)?)?.extract(target)?;
    } else if name.ends_with(".tar.gz") || name.ends_with(".tgz") {
        Archive::new(GzDecoder::new(File::open(archive)?)).unpack(target)?;
    } else if name.ends_with(".tar.bz2") || name.ends_with(".tbz2") {
        Archive::new(BzDecoder::new(File::open(archive)?)).unpack(target)?;
    } else if name.ends_with(".tar.xz") || name.ends_with(".txz") {
        Archive::new(XzDecoder::new(File::open(archive)?)).unpack(target)?;
    } else if name.ends_with(".tar") {
        Archive::new(File::open(archive)?).unpack(target)?;
    } else {
        eprintln!("[thawb] not an archive, leaving file in place");
        return Ok(());
    }

    fs::remove_file(archive)?;
    eprintln!("[thawb] extraction complete");
    Ok(())
}

fn install_plasma_pkg(archive: &Path, pkg: PlasmaPkgType) -> Result<()> {
    eprintln!(
        "[thawb] plasmapkg2 -t {} -i {}",
        pkg.as_str(),
        archive.display()
    );
    let output = Command::new("plasmapkg2")
        .args(["-t", pkg.as_str(), "-i"])
        .arg(archive)
        .output()
        .context("failed to execute plasmapkg2")?;
    if !output.status.success() {
        bail!(
            "plasmapkg2 failed:\n{}",
            String::from_utf8_lossy(&output.stderr)
        );
    }
    fs::remove_file(archive)?;
    eprintln!("[thawb] plasmapkg2 done");
    Ok(())
}

fn install(raw_url: &str) -> Result<()> {
    let home = dirs::home_dir().context("cannot resolve home directory")?;
    let info = parse_ocs_url(raw_url)?;
    let target = info.category.target_dir(&home);
    fs::create_dir_all(&target)
        .with_context(|| format!("failed to create {}", target.display()))?;

    let archive = target.join(&info.filename);
    download(&info.download_url, &archive)?;
    match info.category.plasma_type() {
        Some(pkg) => install_plasma_pkg(&archive, pkg)?,
        None => extract(&archive, &target)?,
    }

    eprintln!("[thawb] installed: {}", info.name);
    Ok(())
}

fn main() -> ExitCode {
    let cli = Cli::parse();
    match install(&cli.url) {
        Ok(()) => ExitCode::SUCCESS,
        Err(error) => {
            eprintln!("[thawb] error: {error:#}");
            ExitCode::FAILURE
        }
    }
}
