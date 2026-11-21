//! Noon color service: reads looks.json, extracts a color, calls matugen.

mod utils;

use std::cmp::Reverse;
use std::collections::{HashMap, HashSet};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, Stdio};

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand, ValueEnum};
use image::imageops::FilterType;
use image::RgbImage;
use palette::{FromColor, Hsv, Srgb};
use serde::{Deserialize, Serialize};
use serde_json::{Map, Value};

const VIDEO_EXTENSIONS: &[&str] = &["mp4", "mkv", "avi", "mov", "webm", "mpeg", "mpg", "flv"];
const IMAGE_EXTENSIONS: &[&str] = &["jpg", "jpeg", "png", "gif", "bmp", "tiff", "tif", "webp"];

#[derive(Parser)]
#[command(about = "Noon color generation service")]
struct Args {
    #[command(subcommand)]
    command: Verb,
}

#[derive(Subcommand)]
enum Verb {
    Set {
        file: PathBuf,
        #[arg(long)]
        mode: Option<Mode>,
        #[arg(long)]
        scheme: Option<String>,
    },
    Color {
        hex: String,
        #[arg(long)]
        mode: Option<Mode>,
        #[arg(long)]
        scheme: Option<String>,
    },
    Mode {
        #[arg(value_enum)]
        mode: ModeChange,
    },
    Json {
        path: PathBuf,
        #[arg(long)]
        mode: Option<Mode>,
    },
    Choose {
        #[arg(long)]
        mode: Option<Mode>,
        #[arg(long)]
        scheme: Option<String>,
    },
    Pick,
}

#[derive(Clone, Copy, ValueEnum)]
enum Mode {
    Dark,
    Light,
}

impl Mode {
    fn name(self) -> &'static str {
        match self {
            Self::Dark => "dark",
            Self::Light => "light",
        }
    }
}

#[derive(Clone, Copy, ValueEnum)]
enum ModeChange {
    Dark,
    Light,
    Toggle,
}

#[derive(Serialize, Deserialize, Clone)]
#[serde(rename_all = "camelCase", default)]
struct Looks {
    mode: String,
    scheme: String,
    auto_shell_mode: bool,
    auto_scheme_selection: bool,
    is_bright: bool,
    is_live: bool,
    extracted_color: String,
    darkness: f64,
    lightness: f64,
    contrast: f64,
    #[serde(flatten)]
    extra: Map<String, Value>,
}

impl Default for Looks {
    fn default() -> Self {
        Self {
            mode: "dark".into(),
            scheme: "scheme-tonal-spot".into(),
            auto_shell_mode: false,
            auto_scheme_selection: false,
            is_bright: false,
            is_live: false,
            extracted_color: String::new(),
            darkness: 0.0,
            lightness: 0.0,
            contrast: 0.0,
            extra: Map::new(),
        }
    }
}

struct Analysis {
    color: String,
    mode: &'static str,
    bright: bool,
    scheme: &'static str,
}

struct App {
    looks: Looks,
}

impl App {
    fn new() -> Self {
        Self { looks: load() }
    }

    fn shell_mode(&self) -> &'static str {
        if self.looks.mode == "light" {
            "light"
        } else {
            "dark"
        }
    }

    fn scheme(&self) -> &str {
        if self.looks.scheme.is_empty() {
            "scheme-tonal-spot"
        } else {
            &self.looks.scheme
        }
    }

    fn apply(&mut self, color: &str, mode: &str, scheme: &str) {
        self.looks.extracted_color = color.into();
        let mut command = Command::new("matugen");
        command.args(["color", "hex", color, "--mode", mode, "--continue-on-error"]);
        if scheme != "scheme-tonal-spot" {
            command.args(["--type", scheme]);
        }
        if self.looks.darkness != 0.0 {
            command.args(["--lightness-dark", &self.looks.darkness.to_string()]);
        }
        if self.looks.lightness != 0.0 {
            command.args(["--lightness-light", &self.looks.lightness.to_string()]);
        }
        if self.looks.contrast != 0.0 {
            command.args(["--contrast", &self.looks.contrast.to_string()]);
        }
        let _ = command.stdout(Stdio::null()).stderr(Stdio::null()).status();
    }

    fn set_image(&mut self, file: &Path, mode: Option<Mode>, scheme: Option<&str>) -> Result<()> {
        if !file.is_file() {
            bail!("file not found: {}", file.display());
        }
        let (image, live) = source_image(file)?;
        let analysis = analyse(&image);

        let fallback = self.shell_mode();
        let current_mode = match mode {
            Some(mode) => mode.name(),
            None if self.looks.auto_shell_mode => analysis.mode,
            None => fallback,
        };
        self.looks.is_bright = analysis.bright;
        self.looks.is_live = live;

        let current_scheme = match scheme {
            Some(scheme) => scheme.to_string(),
            None if self.looks.auto_scheme_selection => analysis.scheme.to_string(),
            None => self.scheme().to_string(),
        };

        self.apply(&analysis.color, current_mode, &current_scheme);
        self.looks.mode = current_mode.into();
        self.looks.scheme = current_scheme;
        Ok(())
    }

    fn set_color(&mut self, hex: &str, mode: Option<Mode>, scheme: Option<&str>) -> Result<()> {
        let hex = hex.trim_start_matches('#');
        if hex.len() != 6 || !hex.chars().all(|c| c.is_ascii_hexdigit()) {
            bail!("invalid colour format (use #RRGGBB or RRGGBB)");
        }
        let mode = mode.map_or_else(
            || self.shell_mode().to_string(),
            |mode| mode.name().to_string(),
        );
        let scheme = scheme.map_or_else(|| self.scheme().to_string(), |scheme| scheme.to_string());
        self.looks.is_bright = false;
        self.looks.is_live = false;
        self.apply(hex, &mode, &scheme);
        self.looks.mode = mode;
        self.looks.scheme = scheme;
        Ok(())
    }

    fn set_mode(&mut self, change: ModeChange) -> Result<()> {
        let mode = match change {
            ModeChange::Dark => "dark",
            ModeChange::Light => "light",
            ModeChange::Toggle if self.shell_mode() == "dark" => "light",
            ModeChange::Toggle => "dark",
        };
        self.looks.mode = mode.into();
        let color = self.looks.extracted_color.clone();
        if !color.is_empty() {
            let scheme = self.scheme().to_string();
            self.apply(&color, mode, &scheme);
        }
        Ok(())
    }

    fn apply_palette(&mut self, path: &Path, mode: Option<Mode>) -> Result<()> {
        if !path.is_file() {
            bail!("palette not found: {}", path.display());
        }
        let mode = mode.map_or_else(
            || self.shell_mode().to_string(),
            |mode| mode.name().to_string(),
        );
        let status = Command::new("matugen")
            .args(["json"])
            .arg(path)
            .args(["--mode", &mode])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .context("matugen not found")?;
        if !status.success() {
            bail!("matugen failed for {}", path.display());
        }
        self.looks.mode = mode;
        Ok(())
    }

    fn choose(&mut self, mode: Option<Mode>, scheme: Option<&str>) -> Result<()> {
        let file = pick_file()?;
        self.set_image(&file, mode, scheme)
    }

    fn pick(&mut self) -> Result<()> {
        let color = pick_color().context("no color selected")?;
        self.set_color(&color, None, None)
    }
}

fn load() -> Looks {
    let Ok(path) = looks_path() else {
        return Looks::default();
    };
    match std::fs::read_to_string(&path) {
        Ok(text) => serde_json::from_str(&text).unwrap_or_else(|error| {
            eprintln!("WARNING: error loading looks: {error}");
            Looks::default()
        }),
        Err(error) => {
            if path.exists() {
                eprintln!("WARNING: error loading looks: {error}");
            }
            Looks::default()
        }
    }
}

fn looks_path() -> Result<PathBuf> {
    Ok(dirs::home_dir()
        .context("HOME is not set")?
        .join(".noon/user/looks.json"))
}

fn extension(path: &Path) -> String {
    path.extension()
        .and_then(|value| value.to_str())
        .unwrap_or("")
        .to_ascii_lowercase()
}

fn source_image(path: &Path) -> Result<(RgbImage, bool)> {
    let ext = extension(path);
    if VIDEO_EXTENSIONS.contains(&ext.as_str()) {
        let duration = utils::video::duration(path).unwrap_or(0.0);
        let at = if duration > 0.0 {
            (duration * 0.5).clamp(1.0, 10.0)
        } else {
            10.0
        };
        let image =
            utils::video::frame_at(path, at).or_else(|_| utils::video::frame_at(path, 0.1))?;
        Ok((image, true))
    } else if IMAGE_EXTENSIONS.contains(&ext.as_str()) {
        Ok((image::open(path)?.to_rgb8(), false))
    } else {
        bail!("color source is not a valid image: {}", path.display())
    }
}

fn analyse(image: &RgbImage) -> Analysis {
    let small = image::imageops::resize(image, 64, 64, FilterType::Triangle);
    let mut buckets: HashMap<u16, [u64; 4]> = HashMap::new();
    let mut sums = [0u64; 3];
    let mut squares = [0u64; 3];
    let mut luma = 0u64;
    let mut saturation = 0.0f64;
    let mut hues = HashSet::new();

    for pixel in small.pixels() {
        let [r, g, b] = pixel.0;
        for (index, value) in [r, g, b].into_iter().enumerate() {
            sums[index] += u64::from(value);
            squares[index] += u64::from(value) * u64::from(value);
        }
        luma += 299 * u64::from(r) + 587 * u64::from(g) + 114 * u64::from(b);
        let hsv = hsv(r, g, b);
        saturation += f64::from(hsv.saturation);
        hues.insert(hsv.hue.into_positive_degrees() as i32);
        let key = (u16::from(r >> 4) << 8) | (u16::from(g >> 4) << 4) | u16::from(b >> 4);
        let bucket = buckets.entry(key).or_insert([0; 4]);
        bucket[0] += 1;
        bucket[1] += u64::from(r);
        bucket[2] += u64::from(g);
        bucket[3] += u64::from(b);
    }

    let mut top: Vec<[u64; 4]> = buckets.into_values().collect();
    top.sort_by_key(|bucket| Reverse(bucket[0]));
    top.truncate(8);

    let mut best_score = -1.0f64;
    let mut best_color = String::new();
    for [count, r, g, b] in top {
        let (r, g, b) = ((r / count) as u8, (g / count) as u8, (b / count) as u8);
        let hsv = hsv(r, g, b);
        let score = f64::from(hsv.saturation) * f64::from(hsv.value);
        if score > best_score {
            best_score = score;
            best_color = format!("{r:02X}{g:02X}{b:02X}");
        }
    }

    let pixels = f64::from(small.width()) * f64::from(small.height());
    let bright = luma as f64 / (pixels * 1000.0) >= 127.0;
    let average_saturation = saturation / pixels;
    let mean = [
        sums[0] as f64 / pixels,
        sums[1] as f64 / pixels,
        sums[2] as f64 / pixels,
    ];
    let variance = (0..3)
        .map(|index| squares[index] as f64 / pixels - mean[index] * mean[index])
        .sum::<f64>()
        / 3.0;

    let scheme = if variance < 50.0 {
        "scheme-monochrome"
    } else if average_saturation < 0.15 {
        "scheme-neutral"
    } else if average_saturation > 0.6 && hues.len() > 180 {
        "scheme-vibrant"
    } else if hues.len() > 260 {
        "scheme-rainbow"
    } else if average_saturation > 0.45 && hues.len() > 80 {
        "scheme-expressive"
    } else if hues.len() < 60 {
        "scheme-content"
    } else {
        "scheme-tonal-spot"
    };

    Analysis {
        color: best_color,
        mode: if bright { "light" } else { "dark" },
        bright,
        scheme,
    }
}

fn hsv(r: u8, g: u8, b: u8) -> Hsv {
    Hsv::from_color(Srgb::new(
        f32::from(r) / 255.0,
        f32::from(g) / 255.0,
        f32::from(b) / 255.0,
    ))
}

fn capture(command: &mut Command) -> Option<String> {
    let output = command.stderr(Stdio::null()).output().ok()?;
    if !output.status.success() {
        return None;
    }
    let text = String::from_utf8_lossy(&output.stdout).trim().to_string();
    (!text.is_empty()).then_some(text)
}

fn pictures_dir() -> PathBuf {
    dirs::home_dir().unwrap_or_default().join("Pictures")
}

fn pick_file() -> Result<PathBuf> {
    let base = pictures_dir();
    let start = ["Wallpapers/showcase", "Wallpapers", ""]
        .iter()
        .map(|subdir| base.join(subdir))
        .find(|candidate| candidate.exists())
        .unwrap_or(base);

    if let Some(path) = capture(
        Command::new("kdialog")
            .arg("--getopenfilename")
            .arg(&start)
            .args(["--title", "Choose wallpaper"]),
    ) {
        return Ok(PathBuf::from(path));
    }
    if let Some(path) = capture(
        Command::new("zenity")
            .arg("--file-selection")
            .arg(format!("--filename={}", start.display())),
    ) {
        return Ok(PathBuf::from(path));
    }

    print!("Wallpaper path (default: {}): ", start.display());
    io::stdout().flush()?;
    let mut line = String::new();
    io::stdin().read_line(&mut line)?;
    let line = line.trim();
    Ok(if line.is_empty() {
        start
    } else {
        PathBuf::from(line)
    })
}

fn pick_color() -> Result<String> {
    for mut command in [
        {
            let mut command = Command::new("hyprpicker");
            command.arg("--no-fancy");
            command
        },
        {
            let mut command = Command::new("kdialog");
            command.args(["--getcolor", "Pick color"]);
            command
        },
        {
            let mut command = Command::new("zenity");
            command.arg("--color-selection");
            command
        },
    ] {
        if let Some(color) = capture(&mut command) {
            return Ok(color.trim_start_matches('#').to_string());
        }
    }
    bail!("no color picker available")
}

fn main() -> Result<()> {
    let args = Args::parse();
    let mut app = App::new();
    let result = match args.command {
        Verb::Set { file, mode, scheme } => app.set_image(&file, mode, scheme.as_deref()),
        Verb::Color { hex, mode, scheme } => app.set_color(&hex, mode, scheme.as_deref()),
        Verb::Mode { mode } => app.set_mode(mode),
        Verb::Json { path, mode } => app.apply_palette(&path, mode),
        Verb::Choose { mode, scheme } => app.choose(mode, scheme.as_deref()),
        Verb::Pick => app.pick(),
    };
    if let Err(error) = result {
        eprintln!("ERROR: {error:#}");
    }
    println!("{}", serde_json::to_string(&app.looks)?);
    Ok(())
}
