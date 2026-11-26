use std::collections::BTreeSet;
use std::env;
use std::error::Error;
use std::fs;
use std::io;
use std::os::unix::process::CommandExt;
use std::path::{Path, PathBuf};
use std::process::Command;

use ratatui::Terminal;
use ratatui::backend::CrosstermBackend;
use ratatui::crossterm::cursor::{Hide, Show};
use ratatui::crossterm::event::{
    self, DisableMouseCapture, EnableMouseCapture, Event, KeyCode, KeyEventKind, MouseButton,
    MouseEventKind,
};
use ratatui::crossterm::execute;
use ratatui::crossterm::terminal::{
    EnterAlternateScreen, LeaveAlternateScreen, disable_raw_mode, enable_raw_mode,
};
use ratatui::layout::{Alignment, Constraint, Layout, Rect};
use ratatui::style::{Color, Modifier, Style};
use ratatui::text::{Line, Span};
use ratatui::widgets::{
    Block, Borders, List, ListItem, ListState, Paragraph, Scrollbar, ScrollbarOrientation,
    ScrollbarState,
};
use serde::{Deserialize, Serialize};

#[derive(Clone, Copy, PartialEq, Eq)]
enum Page {
    Welcome,
    Compositor,
    Bundles,
    Configs,
    Nvidia,
    Build,
    Method,
    Review,
}

const PAGES: [(Page, &str); 8] = [
    (Page::Welcome, "Welcome"),
    (Page::Compositor, "Compositor / Desktop"),
    (Page::Bundles, "Bundles"),
    (Page::Configs, "Configs"),
    (Page::Nvidia, "NVIDIA driver"),
    (Page::Build, "Build Noon-libqt"),
    (Page::Method, "Install method"),
    (Page::Review, "Review"),
];
const METHODS: [(&str, &str); 2] = [
    ("copy", "Copy files from the repo"),
    ("link", "Symlink files to the repo"),
];
const COMPOSITOR_ORDER: [&str; 3] = ["hyprland", "niri", "mango"];
const BUNDLE_ORDER: [&str; 6] = ["core", "desktop", "devel", "apps", "extra", "gaming"];
const DRIVER_ORDER: [&str; 6] = ["open", "latest", "580xx", "470xx", "390xx", "340xx"];
const GPU_PREFIXES: [(&str, &[&str]); 12] = [
    ("GB", &["blackwell"]),
    ("AD", &["ada"]),
    ("GA", &["ampere"]),
    ("TU", &["turing"]),
    ("GV100", &["volta"]),
    ("GP", &["pascal"]),
    ("GM", &["maxwell"]),
    ("GK", &["kepler"]),
    ("GF", &["fermi"]),
    ("GT2", &["tesla"]),
    ("G8", &["tesla"]),
    ("G9", &["tesla"]),
];

impl Page {
    fn title(self) -> &'static str {
        PAGES
            .iter()
            .find(|(page, _)| *page == self)
            .map(|(_, title)| *title)
            .unwrap_or("")
    }
}

#[derive(Clone, Copy, PartialEq, Eq)]
enum Focus {
    Selection,
    Packages,
}

#[derive(Clone, Copy)]
enum Marker {
    Check(bool),
    None,
}

struct Row {
    text: String,
    marker: Marker,
    disabled: bool,
}

fn row(text: impl Into<String>, marker: Marker, disabled: bool) -> Row {
    Row {
        text: text.into(),
        marker,
        disabled,
    }
}

/// The plan is the hand-off between the selector and install.sh: decisions
/// only, never package lists. The executor still reads the .conf files.
#[derive(Serialize, Deserialize)]
struct Plan {
    version: u32,
    distro: String,
    #[serde(default)]
    compositor: String,
    bundles: Vec<String>,
    components: Vec<String>,
    nvidia: String,
    libqt: bool,
    method: String,
    onlydots: bool,
    remove: bool,
    force: bool,
}

struct Bundle {
    key: String,
    checked: bool,
    locked: bool,
    packages: Vec<String>,
}

struct Config {
    key: String,
    checked: bool,
    kind: String,
    dest: String,
    files: Vec<String>,
}

struct Driver {
    id: String,
    label: String,
    gpus: Vec<String>,
    arch: String,
    packages: Vec<String>,
}

struct Compositor {
    key: String,
    name: String,
    command: String,
    description: Vec<String>,
    packages: Vec<String>,
}

struct App {
    repo: PathBuf,
    distro: String,
    compositors: Vec<Compositor>,
    compositor: usize,
    bundles: Vec<Bundle>,
    configs: Vec<Config>,
    drivers: Vec<Driver>,
    compatible: Vec<usize>,
    nvidia_visible: bool,
    build_libqt: bool,
    driver: Option<usize>,
    method_index: usize,
    onlydots: bool,
    remove: bool,
    force: bool,
    page: Page,
    cursor: usize,
    focus: Focus,
    pkg_offset: usize,
    left_inner: Rect,
    right_viewport: usize,
    should_quit: bool,
    confirmed: bool,
}

fn detect_distro() -> String {
    if let Ok(value) = env::var("NOON_DISTRO") {
        return value;
    }
    let os = fs::read_to_string("/etc/os-release").unwrap_or_default();
    let get = |key: &str| {
        os.lines()
            .find_map(|line| line.strip_prefix(key))
            .map(|value| value.trim_matches('"').to_string())
            .unwrap_or_default()
    };
    let id = get("ID=");
    let like = get("ID_LIKE=");
    if id == "fedora" || like.contains("fedora") {
        "fedora".into()
    } else if id == "arch" || like.contains("arch") {
        "arch".into()
    } else {
        id
    }
}

fn bundle_label(key: &str) -> String {
    match key {
        "core" => "Core shell",
        "apps" => "Optional desktop applications",
        "desktop" => "Desktop apps, media and audio",
        "devel" => "Build dependencies",
        "gaming" => "Gaming packages",
        "extra" => "Extras and system helpers",
        _ => key,
    }
    .into()
}

fn bundle_rank(key: &str) -> usize {
    BUNDLE_ORDER
        .iter()
        .position(|name| *name == key)
        .unwrap_or(BUNDLE_ORDER.len())
}

/// The compositor id and its config directory differ only for Hyprland.
fn compositor_config_dir(key: &str) -> &str {
    if key == "hyprland" { "hypr" } else { key }
}

fn parse_packages(path: &Path) -> Vec<String> {
    let mut packages = Vec::new();
    let mut block = "";
    for line in fs::read_to_string(path)
        .unwrap_or_default()
        .lines()
        .map(str::trim)
    {
        if line.is_empty() || line.starts_with('#') {
            continue;
        }
        if !block.is_empty() {
            if line == "}" {
                block = "";
            } else if block == "pkgs" {
                packages.extend(line.split_whitespace().map(String::from));
            }
            continue;
        }
        for name in ["copr", "pkgs", "python", "script"] {
            if line.starts_with(name) && line[name.len()..].trim_start().starts_with('{') {
                block = name;
                break;
            }
        }
    }
    packages
}

fn sorted_paths(root: &Path, keep: impl Fn(&Path) -> bool) -> Vec<PathBuf> {
    let mut paths: Vec<PathBuf> = fs::read_dir(root)
        .into_iter()
        .flatten()
        .flatten()
        .map(|entry| entry.path())
        .filter(|path| keep(path))
        .collect();
    paths.sort();
    paths
}

fn load_drivers(dots: &Path, distro: &str) -> Vec<Driver> {
    let mut drivers: Vec<Driver> = sorted_paths(&dots.join(distro).join("nvidia"), |p| {
        p.extension().and_then(|ext| ext.to_str()) == Some("conf")
    })
    .into_iter()
    .map(|path| {
        let id = path
            .file_stem()
            .map(|name| name.to_string_lossy().into_owned())
            .unwrap_or_default();
        let text = fs::read_to_string(&path).unwrap_or_default();
        let meta = |key: &str| {
            text.lines()
                .find_map(|line| line.trim().strip_prefix(key).map(str::trim))
                .unwrap_or("")
                .to_string()
        };
        let label = meta("# DESC:");
        Driver {
            label: if label.is_empty() { id.clone() } else { label },
            id,
            gpus: meta("# GPU:")
                .split_whitespace()
                .map(String::from)
                .collect(),
            arch: meta("# ARCH:"),
            packages: parse_packages(&path),
        }
    })
    .collect();
    drivers.sort_by_key(|driver| {
        DRIVER_ORDER
            .iter()
            .position(|id| *id == driver.id)
            .unwrap_or(DRIVER_ORDER.len())
    });
    drivers
}

fn load_compositors(dots: &Path, distro: &str) -> Vec<Compositor> {
    let mut compositors: Vec<Compositor> =
        sorted_paths(&dots.join(distro).join("compositors"), |p| {
            p.extension().and_then(|ext| ext.to_str()) == Some("conf")
        })
        .into_iter()
        .map(|path| {
            let key = path
                .file_stem()
                .map(|name| name.to_string_lossy().into_owned())
                .unwrap_or_default();
            let text = fs::read_to_string(&path).unwrap_or_default();
            let meta = |prefix: &str| {
                text.lines()
                    .find_map(|line| line.trim().strip_prefix(prefix).map(str::trim))
                    .unwrap_or("")
                    .to_string()
            };
            let description: Vec<String> = text
                .lines()
                .filter_map(|line| line.trim().strip_prefix("# DESC:").map(str::trim))
                .map(String::from)
                .collect();
            Compositor {
                name: meta("# NAME:"),
                command: meta("# CMD:"),
                description,
                packages: parse_packages(&path),
                key,
            }
        })
        .collect();
    compositors.sort_by_key(|comp| {
        COMPOSITOR_ORDER
            .iter()
            .position(|id| *id == comp.key)
            .unwrap_or(COMPOSITOR_ORDER.len())
    });
    compositors
}

fn detect_gpus() -> Option<BTreeSet<String>> {
    let output = Command::new("lspci").arg("-nn").output().ok()?;
    if !output.status.success() {
        return None;
    }
    let mut found = BTreeSet::new();
    for line in String::from_utf8_lossy(&output.stdout).lines() {
        if !line.contains("10de:") {
            continue;
        }
        for token in line.split(['[', ']']) {
            for word in token.split_whitespace() {
                let word = word.trim_matches(|c: char| !c.is_ascii_alphanumeric());
                let word = word.to_uppercase();
                for (prefix, families) in GPU_PREFIXES {
                    if word.starts_with(prefix) {
                        found.extend(families.iter().map(|family| (*family).to_string()));
                    }
                }
            }
        }
    }
    Some(found)
}

fn compatible_drivers(drivers: &[Driver], detected: &Option<BTreeSet<String>>) -> Vec<usize> {
    match detected {
        Some(gpus) => drivers
            .iter()
            .enumerate()
            .filter(|(_, driver)| driver.gpus.iter().any(|gpu| gpus.contains(gpu)))
            .map(|(index, _)| index)
            .collect(),
        None => (0..drivers.len()).collect(),
    }
}

fn config_info(path: &Path) -> (String, String) {
    let mut kind = String::new();
    let mut dest = String::new();
    for line in fs::read_to_string(path).unwrap_or_default().lines() {
        if let Some(value) = line.strip_prefix("TYPE=") {
            kind = value.trim().into();
        } else if let Some(value) = line.strip_prefix("DESTINATION=") {
            dest = value.trim().into();
        }
    }
    (kind, dest)
}

fn collect_files(root: &Path) -> Vec<String> {
    fn walk(dir: &Path, root: &Path, out: &mut Vec<String>) {
        for entry in sorted_paths(dir, |_| true) {
            let Ok(meta) = fs::symlink_metadata(&entry) else {
                continue;
            };
            let kind = meta.file_type();
            if kind.is_dir() {
                walk(&entry, root, out);
            } else if kind.is_file()
                && entry.file_name().and_then(|name| name.to_str()) != Some("INSTALLER_CONFIG")
            {
                out.push(
                    entry
                        .strip_prefix(root)
                        .unwrap_or(&entry)
                        .to_string_lossy()
                        .into_owned(),
                );
            }
        }
    }
    let mut files = Vec::new();
    walk(root, root, &mut files);
    files
}

impl App {
    fn new() -> Result<Self, Box<dyn Error>> {
        let repo = match env::var_os("NOON_REPO") {
            Some(value) => PathBuf::from(value),
            None => {
                let exe = env::current_exe()?;
                let parent = exe.parent().unwrap_or(Path::new("."));
                let shipped = parent
                    .file_name()
                    .is_some_and(|name| name == "dots" || name == "bin");
                if shipped {
                    parent.parent().unwrap_or(parent).to_path_buf()
                } else {
                    parent.to_path_buf()
                }
            }
        };
        let dots = env::var_os("NOON_DOTS_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(|| repo.join("dots"));
        let distro = detect_distro();
        let distro_dir = dots.join(&distro);

        let compositors = load_compositors(&dots, &distro);
        let compositor = compositors
            .iter()
            .position(|comp| comp.key == "hyprland")
            .unwrap_or(0);

        let mut bundles = Vec::new();
        for path in sorted_paths(&distro_dir, |p| {
            p.extension().and_then(|e| e.to_str()) == Some("conf")
        }) {
            let key = path
                .file_stem()
                .map(|name| name.to_string_lossy().into_owned())
                .unwrap_or_default();
            let locked = key == "core" || key == "devel";
            let checked = locked || key == "desktop";
            bundles.push(Bundle {
                key,
                checked,
                locked,
                packages: parse_packages(&path),
            });
        }
        bundles.sort_by_key(|bundle| bundle_rank(&bundle.key));

        let drivers = load_drivers(&dots, &distro);
        let detected = detect_gpus();
        let compatible = compatible_drivers(&drivers, &detected);
        let nvidia_visible = !drivers.is_empty() && (detected.is_none() || !compatible.is_empty());

        let mut configs = Vec::new();
        for path in sorted_paths(&dots.join("shared"), |p| {
            p.join("INSTALLER_CONFIG").is_file()
        }) {
            let key = path
                .file_name()
                .map(|name| name.to_string_lossy().into_owned())
                .unwrap_or_default();
            let (kind, dest) = config_info(&path.join("INSTALLER_CONFIG"));
            configs.push(Config {
                key,
                checked: true,
                kind,
                dest,
                files: collect_files(&path),
            });
        }

        Ok(Self {
            repo,
            distro,
            compositors,
            compositor,
            bundles,
            configs,
            drivers,
            compatible,
            nvidia_visible,
            build_libqt: true,
            driver: None,
            method_index: 0,
            onlydots: false,
            remove: false,
            force: false,
            page: Page::Welcome,
            cursor: 0,
            focus: Focus::Selection,
            pkg_offset: 0,
            left_inner: Rect::default(),
            right_viewport: 1,
            should_quit: false,
            confirmed: false,
        })
    }

    fn plan(&self) -> Plan {
        let mut bundles: Vec<String> = self
            .bundles
            .iter()
            .filter(|bundle| bundle.checked)
            .map(|bundle| bundle.key.clone())
            .collect();
        bundles.sort_by_key(|key| bundle_rank(key));
        let compositor = if self.onlydots {
            "none".into()
        } else {
            self.compositors
                .get(self.compositor)
                .map(|comp| comp.key.clone())
                .unwrap_or_else(|| "hyprland".into())
        };
        Plan {
            version: 1,
            distro: self.distro.clone(),
            compositor,
            bundles,
            components: self
                .configs
                .iter()
                .filter(|config| config.checked)
                .map(|config| config.key.clone())
                .collect(),
            nvidia: self
                .driver
                .map(|index| self.drivers[index].id.clone())
                .unwrap_or_else(|| "none".into()),
            libqt: self.build_libqt,
            method: METHODS[self.method_index].0.into(),
            onlydots: self.onlydots,
            remove: self.remove,
            force: self.force,
        }
    }

    fn set_driver(&mut self, id: &str) -> Result<(), String> {
        match self.drivers.iter().position(|driver| driver.id == id) {
            Some(index) => {
                self.driver = Some(index);
                Ok(())
            }
            None => Err(format!(
                "unknown NVIDIA driver: {id} (expected one of: {})",
                self.drivers
                    .iter()
                    .map(|driver| driver.id.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            )),
        }
    }

    fn set_compositor(&mut self, id: &str) -> Result<(), String> {
        match self.compositors.iter().position(|comp| comp.key == id) {
            Some(index) => {
                self.compositor = index;
                Ok(())
            }
            None => Err(format!(
                "unknown compositor: {id} (expected one of: {})",
                self.compositors
                    .iter()
                    .map(|comp| comp.key.as_str())
                    .collect::<Vec<_>>()
                    .join(", ")
            )),
        }
    }

    fn apply_flags(&mut self, args: &[String]) -> Result<(), String> {
        let mut i = 0;
        while i < args.len() {
            let arg = args[i].as_str();
            match arg {
                "-f" | "--force" => self.force = true,
                "--remove" => self.remove = true,
                "--all" => {
                    for bundle in &mut self.bundles {
                        if bundle.key != "core" {
                            bundle.checked = true;
                        }
                    }
                }
                "--apps" | "--desktop" | "--dev" | "--devel" | "--misc" | "--extra"
                | "--gaming" => {
                    let key = match arg {
                        "--dev" | "--devel" => "devel",
                        "--misc" | "--extra" => "extra",
                        _ => &arg[2..],
                    };
                    let Some(bundle) = self.bundles.iter_mut().find(|b| b.key == key) else {
                        return Err(format!("no '{key}' bundle for distro {}", self.distro));
                    };
                    bundle.checked = true;
                }
                "--nvidia" => self.driver = self.compatible.first().copied(),
                "--nvidia-old" => self.set_driver("580xx")?,
                "--no-libqt" => self.build_libqt = false,
                "--onlydots" => self.onlydots = true,
                "--nvidia-driver" => {
                    let value = args
                        .get(i + 1)
                        .ok_or("--nvidia-driver requires a driver id")?;
                    self.set_driver(value)?;
                    i += 1;
                }
                _ if arg.starts_with("--nvidia-driver=") => {
                    self.set_driver(&arg["--nvidia-driver=".len()..])?;
                }
                "--compositor" => {
                    let value = args
                        .get(i + 1)
                        .ok_or("--compositor requires a compositor id")?;
                    self.set_compositor(value)?;
                    i += 1;
                }
                _ if arg.starts_with("--compositor=") => {
                    self.set_compositor(&arg["--compositor=".len()..])?;
                }
                "--components" | "--method" => {
                    let value = args
                        .get(i + 1)
                        .ok_or_else(|| format!("{arg} requires a value"))?;
                    if arg == "--components" {
                        self.apply_components(value);
                    } else {
                        self.apply_method(value)?;
                    }
                    i += 1;
                }
                _ if arg.starts_with("--components=") => {
                    self.apply_components(&arg["--components=".len()..]);
                }
                _ if arg.starts_with("--method=") => {
                    self.apply_method(&arg["--method=".len()..])?;
                }
                _ => return Err(format!("unknown option: {arg}")),
            }
            i += 1;
        }
        // --onlydots wins over every package flag, regardless of order.
        if self.onlydots {
            for bundle in &mut self.bundles {
                bundle.checked = false;
            }
            self.driver = None;
            self.build_libqt = false;
        }
        Ok(())
    }

    fn apply_components(&mut self, value: &str) {
        let wanted: Vec<&str> = value
            .split(',')
            .map(str::trim)
            .filter(|s| !s.is_empty())
            .collect();
        for config in &mut self.configs {
            config.checked = wanted.contains(&config.key.as_str());
        }
    }

    fn apply_method(&mut self, value: &str) -> Result<(), String> {
        match METHODS.iter().position(|(key, _)| *key == value) {
            Some(index) => {
                self.method_index = index;
                Ok(())
            }
            None => Err(format!("invalid --method: {value} (expected copy or link)")),
        }
    }

    fn visible_pages(&self) -> Vec<Page> {
        PAGES
            .iter()
            .map(|(page, _)| *page)
            .filter(|page| *page != Page::Nvidia || self.nvidia_visible)
            .collect()
    }

    fn page_index(&self) -> usize {
        self.visible_pages()
            .iter()
            .position(|page| *page == self.page)
            .unwrap_or(0)
    }

    fn driver_rows(&self) -> Vec<Option<usize>> {
        let mut indices = if self.nvidia_visible && self.compatible.is_empty() {
            (0..self.drivers.len()).collect()
        } else {
            self.compatible.clone()
        };
        if let Some(selected) = self.driver {
            if !indices.contains(&selected) {
                indices.push(selected);
            }
        }
        indices.sort_by_key(|index| {
            DRIVER_ORDER
                .iter()
                .position(|id| *id == self.drivers[*index].id)
                .unwrap_or(DRIVER_ORDER.len())
        });
        let mut rows = vec![None];
        rows.extend(indices.into_iter().map(Some));
        rows
    }

    fn rows(&self) -> Vec<Row> {
        match self.page {
            Page::Welcome => Vec::new(),
            Page::Compositor => self
                .compositors
                .iter()
                .enumerate()
                .map(|(i, comp)| row(&comp.name, Marker::Check(i == self.compositor), false))
                .collect(),
            Page::Bundles => self
                .bundles
                .iter()
                .map(|b| row(bundle_label(&b.key), Marker::Check(b.checked), b.locked))
                .collect(),
            Page::Configs => self
                .configs
                .iter()
                .map(|config| {
                    let text = if config.kind.is_empty() {
                        config.key.clone()
                    } else {
                        format!("{}  [{}]", config.kind, config.key)
                    };
                    row(text, Marker::Check(config.checked), false)
                })
                .collect(),
            Page::Nvidia => self
                .driver_rows()
                .iter()
                .map(|driver| {
                    let text = match driver {
                        None => "No NVIDIA driver".into(),
                        Some(index) => {
                            let selected = &self.drivers[*index];
                            format!("{} ({})", selected.label, selected.id)
                        }
                    };
                    row(text, Marker::Check(*driver == self.driver), false)
                })
                .collect(),
            Page::Build => vec![row(
                "Build and install Noon-libqt",
                Marker::Check(self.build_libqt),
                false,
            )],
            Page::Method => METHODS
                .iter()
                .enumerate()
                .map(|(i, (_, label))| row(*label, Marker::Check(i == self.method_index), false))
                .collect(),
            Page::Review => {
                let plan = self.plan();
                let mut rows = vec![row(
                    format!(
                        "Bundles: {} {}",
                        plan.bundles.len(),
                        if plan.bundles.len() == 1 {
                            "bundle"
                        } else {
                            "bundles"
                        }
                    ),
                    Marker::None,
                    true,
                )];
                rows.extend(
                    plan.bundles
                        .iter()
                        .map(|key| row(format!("  {key}"), Marker::None, true)),
                );
                rows.push(row("", Marker::None, true));
                rows.push(row(
                    format!("Noon-libqt: {}", if plan.libqt { "build" } else { "skip" }),
                    Marker::None,
                    true,
                ));
                rows.push(row(format!("NVIDIA:  {}", plan.nvidia), Marker::None, true));
                rows.push(row(format!("Method:  {}", plan.method), Marker::None, true));
                rows.push(row("", Marker::None, true));
                rows.push(row("Install", Marker::None, false));
                rows.push(row("Cancel", Marker::None, false));
                rows
            }
        }
    }

    fn cursor_max(&self) -> usize {
        match self.page {
            Page::Welcome => 0,
            Page::Review => 1,
            _ => self.rows().len().saturating_sub(1),
        }
    }

    fn highlighted_row(&self) -> usize {
        let len = self.rows().len();
        if self.page == Page::Review {
            len.saturating_sub(2) + self.cursor
        } else {
            self.cursor.min(len.saturating_sub(1))
        }
    }

    fn selected_packages(&self) -> Vec<String> {
        let plan = self.plan();
        let mut packages = BTreeSet::new();
        for key in &plan.bundles {
            if let Some(bundle) = self.bundles.iter().find(|b| &b.key == key) {
                packages.extend(bundle.packages.iter().cloned());
            }
        }
        if plan.compositor != "none" {
            if let Some(comp) = self.compositors.iter().find(|c| c.key == plan.compositor) {
                packages.extend(comp.packages.iter().cloned());
            }
        }
        if let Some(driver) = self.drivers.iter().find(|driver| driver.id == plan.nvidia) {
            packages.extend(driver.packages.iter().cloned());
        }
        packages.into_iter().collect()
    }

    /// Name + description for the hovered compositor, shown above the sidebar list.
    fn preview_lines(&self, width: usize) -> Vec<Line<'static>> {
        let Some(comp) = self.compositors.get(self.cursor) else {
            return Vec::new();
        };
        let style = Style::default().fg(Color::Cyan);
        let center = |text: String| {
            let pad = width.saturating_sub(text.chars().count()) / 2;
            Line::from(Span::styled(format!("{}{}", " ".repeat(pad), text), style))
        };
        let mut lines = vec![center(comp.name.clone())];
        lines.extend(comp.description.iter().cloned().map(center));
        lines
    }

    /// Config dirs belonging to a compositor other than the selected one.
    fn hidden_compositor_file(&self, file: &str) -> bool {
        let selected = self.plan().compositor;
        if selected == "none" {
            return false;
        }
        self.compositors
            .iter()
            .filter(|comp| comp.key != selected)
            .any(|comp| {
                let dir = compositor_config_dir(&comp.key);
                file.starts_with(&format!(".config/{dir}/"))
            })
    }

    fn sidebar(&self) -> (String, Vec<String>) {
        match self.page {
            Page::Welcome => (
                "Welcome".into(),
                [
                    "Configure and install",
                    "the Noon shell.",
                    "",
                    "Enter  continue",
                    "q      cancel",
                ]
                .iter()
                .map(|line| (*line).into())
                .collect(),
            ),
            Page::Compositor => match self.compositors.get(self.cursor) {
                Some(comp) => (
                    format!("{} ({}) - {}", comp.key, comp.packages.len(), comp.command),
                    comp.packages.clone(),
                ),
                None => ("Packages".into(), Vec::new()),
            },
            Page::Bundles => match self.bundles.get(self.cursor) {
                Some(bundle) => (
                    format!("{} ({})", bundle.key, bundle.packages.len()),
                    bundle.packages.clone(),
                ),
                None => ("Packages".into(), Vec::new()),
            },
            Page::Configs => {
                let i = self.cursor.min(self.configs.len().saturating_sub(1));
                match self.configs.get(i) {
                    Some(config) => {
                        let meta = match (!config.kind.is_empty(), !config.dest.is_empty()) {
                            (true, true) => format!("{} -> {}", config.kind, config.dest),
                            (true, false) => config.kind.clone(),
                            (false, true) => config.dest.clone(),
                            (false, false) => String::new(),
                        };
                        let mut lines = Vec::new();
                        if !meta.is_empty() {
                            lines.push(format!("  {meta}"));
                            lines.push(String::new());
                        }
                        let visible: Vec<&String> = config
                            .files
                            .iter()
                            .filter(|file| !self.hidden_compositor_file(file))
                            .collect();
                        lines.extend(visible.iter().map(|file| (*file).clone()));
                        (format!("{} ({} files)", config.key, visible.len()), lines)
                    }
                    None => ("Files".into(), Vec::new()),
                }
            }
            Page::Nvidia => match self.driver_rows().get(self.cursor).copied().flatten() {
                None => (
                    "No NVIDIA driver".into(),
                    vec!["No driver packages will be installed.".into()],
                ),
                Some(index) => {
                    let driver = &self.drivers[index];
                    let mut lines = vec![driver.label.clone()];
                    if !driver.arch.is_empty() {
                        lines.push(format!("GPUs: {}", driver.arch));
                    }
                    lines.push(String::new());
                    lines.extend(driver.packages.iter().cloned());
                    (format!("{} ({})", driver.id, driver.packages.len()), lines)
                }
            },
            Page::Build => match self.bundles.iter().find(|b| b.key == "devel") {
                Some(devel) => (
                    format!("devel ({}) - always installed", devel.packages.len()),
                    devel.packages.clone(),
                ),
                None => (
                    "Noon-libqt".into(),
                    vec![
                        if self.build_libqt {
                            "Build enabled; no devel.conf found."
                        } else {
                            "Build disabled: --no-libqt"
                        }
                        .into(),
                    ],
                ),
            },
            Page::Method => {
                let i = self.cursor.min(METHODS.len() - 1);
                let lines: Vec<String> = if i == 0 {
                    [
                        "Regular directories are created in place.",
                        "Files are copied from this repo.",
                        "Later repo changes do not affect installed files.",
                    ]
                } else {
                    [
                        "Directories stay real so you can add your own files.",
                        "Individual files become symlinks into this repo.",
                        "Repo edits are reflected immediately.",
                    ]
                }
                .iter()
                .map(|line| (*line).into())
                .collect();
                (METHODS[i].0.into(), lines)
            }
            Page::Review => {
                if self.cursor == 0 {
                    let packages = self.selected_packages();
                    (format!("Selected ({})", packages.len()), packages)
                } else {
                    (
                        "Cancel".into(),
                        vec![
                            "Nothing will be installed.".into(),
                            "No packages will be installed.".into(),
                            "No files will be copied or linked.".into(),
                        ],
                    )
                }
            }
        }
    }

    fn sidebar_len(&self) -> usize {
        self.sidebar().1.len()
    }

    fn scroll(&mut self, delta: isize) {
        let max = self.sidebar_len().saturating_sub(self.right_viewport) as isize;
        self.pkg_offset = (self.pkg_offset as isize + delta).clamp(0, max) as usize;
    }

    fn move_cursor(&mut self, delta: isize) {
        let next = (self.cursor as isize + delta).clamp(0, self.cursor_max() as isize) as usize;
        if next != self.cursor {
            self.cursor = next;
            self.pkg_offset = 0;
        }
    }

    fn set_page(&mut self, index: usize) {
        if let Some(page) = self.visible_pages().get(index).copied() {
            self.page = page;
        }
        self.cursor = 0;
        self.pkg_offset = 0;
    }

    fn toggle(&mut self) {
        match self.page {
            Page::Welcome => {}
            Page::Compositor => {
                self.compositor = self.cursor.min(self.compositors.len().saturating_sub(1));
            }
            Page::Bundles => {
                if let Some(bundle) = self.bundles.get_mut(self.cursor) {
                    if !bundle.locked {
                        bundle.checked = !bundle.checked;
                    }
                }
            }
            Page::Configs => {
                if let Some(config) = self.configs.get_mut(self.cursor) {
                    config.checked = !config.checked;
                }
            }
            Page::Nvidia => self.driver = self.driver_rows().get(self.cursor).copied().flatten(),
            Page::Build => self.build_libqt = !self.build_libqt,
            Page::Method => self.method_index = self.cursor.min(METHODS.len() - 1),
            Page::Review => {
                if self.cursor == 0 {
                    self.confirmed = true;
                }
                self.should_quit = true;
            }
        }
    }

    fn next_page(&mut self) {
        let index = self.page_index();
        if index + 1 < self.visible_pages().len() {
            self.set_page(index + 1);
        }
    }

    fn prev_page(&mut self) {
        let index = self.page_index();
        if index == 0 {
            self.should_quit = true;
        } else {
            self.set_page(index - 1);
        }
    }
}

fn draw(frame: &mut ratatui::Frame, app: &mut App) {
    let accent = Style::default()
        .fg(Color::Cyan)
        .add_modifier(Modifier::BOLD);
    let cyan = Style::default().fg(Color::Cyan);
    let muted = Style::default().fg(Color::DarkGray);
    let chunks = Layout::vertical([
        Constraint::Length(2),
        Constraint::Min(1),
        Constraint::Length(1),
    ])
    .split(frame.area());

    frame.render_widget(
        Paragraph::new(Line::from(vec![
            Span::styled(" Noon installer", accent),
            Span::raw("   "),
            Span::styled(
                format!(
                    "Page {}/{} - {}",
                    app.page_index() + 1,
                    app.visible_pages().len(),
                    app.page.title()
                ),
                muted,
            ),
            Span::raw("   "),
            Span::styled(
                format!("distro: {}   repo: {}", app.distro, app.repo.display()),
                muted,
            ),
        ])),
        chunks[0],
    );

    let columns = Layout::horizontal([Constraint::Percentage(68), Constraint::Percentage(32)])
        .split(chunks[1]);
    let (left, right) = (columns[0], columns[1]);
    frame.render_widget(
        Block::default().borders(Borders::RIGHT).border_style(muted),
        left,
    );
    app.left_inner = Rect {
        x: left.x + 1,
        y: left.y,
        width: left.width.saturating_sub(2),
        height: left.height,
    };

    if app.page == Page::Welcome {
        let intro = [
            Line::from(Span::styled("Noon", accent)),
            Line::from(Span::styled("A Wayland shell that feels like home", muted)),
            Line::from(""),
            Line::from(Span::styled("Enter  Begin installation", cyan)),
            Line::from(Span::styled("q      Cancel", muted)),
        ];
        let pad = app.left_inner.height.saturating_sub(intro.len() as u16) / 2;
        let mut lines = vec![Line::from(""); pad as usize];
        lines.extend(intro);
        frame.render_widget(
            Paragraph::new(lines).alignment(Alignment::Center),
            app.left_inner,
        );
    } else {
        let rows = app.rows();
        let highlight = app.highlighted_row();
        let items: Vec<ListItem> = rows
            .iter()
            .enumerate()
            .map(|(i, item)| {
                let (marker, marker_style) = match item.marker {
                    Marker::Check(true) => (
                        "[x]",
                        if item.disabled {
                            muted
                        } else {
                            Style::default()
                                .fg(Color::Green)
                                .add_modifier(Modifier::BOLD)
                        },
                    ),
                    Marker::Check(false) => ("[ ]", muted),
                    Marker::None => ("   ", muted),
                };
                let prefix = if app.page == Page::Review
                    && i >= rows.len().saturating_sub(2)
                    && i == highlight
                {
                    "> "
                } else {
                    "  "
                };
                ListItem::new(Line::from(vec![
                    Span::raw(prefix),
                    Span::styled(marker, marker_style),
                    Span::raw(" "),
                    Span::styled(
                        item.text.clone(),
                        if item.disabled {
                            muted
                        } else {
                            Style::default().fg(Color::White)
                        },
                    ),
                ]))
            })
            .collect();
        let mut state = ListState::default();
        state.select(Some(highlight));
        let highlight_style = if app.focus == Focus::Selection {
            Style::default()
                .fg(Color::White)
                .add_modifier(Modifier::REVERSED)
        } else {
            muted
        };
        frame.render_stateful_widget(
            List::new(items).highlight_style(highlight_style),
            app.left_inner,
            &mut state,
        );
    }

    let (title, packages) = app.sidebar();
    let inner_width = right.width.saturating_sub(2) as usize;
    let preview: Vec<Line<'static>> = if app.page == Page::Compositor {
        app.preview_lines(inner_width.max(8))
    } else {
        Vec::new()
    };
    let max_preview = (right.height as usize).saturating_sub(4);
    let preview: Vec<Line<'static>> = preview.into_iter().take(max_preview).collect();
    let preview_height = if preview.is_empty() {
        0
    } else {
        preview.len() + 2
    };
    let right_parts = Layout::vertical([
        Constraint::Length(preview_height as u16),
        Constraint::Length(1),
        Constraint::Min(1),
    ])
    .split(right);
    if !preview.is_empty() {
        frame.render_widget(
            Paragraph::new(preview).block(
                Block::default()
                    .borders(Borders::ALL)
                    .border_style(muted)
                    .title(" Preview "),
            ),
            right_parts[0],
        );
    }
    frame.render_widget(
        Paragraph::new(Line::from(Span::styled(title, accent))),
        right_parts[1],
    );
    let list_area = right_parts[2];
    let list_inner = Rect {
        x: list_area.x + 1,
        y: list_area.y,
        width: list_area.width.saturating_sub(3),
        height: list_area.height,
    };
    app.right_viewport = list_inner.height.max(1) as usize;
    app.pkg_offset = app
        .pkg_offset
        .min(packages.len().saturating_sub(app.right_viewport));
    let end = (app.pkg_offset + app.right_viewport).min(packages.len());
    frame.render_widget(
        List::new(packages[app.pkg_offset..end].iter().map(|package| {
            ListItem::new(Line::from(Span::styled(
                format!("  {package}"),
                Style::default().fg(Color::Gray),
            )))
        })),
        list_inner,
    );
    let mut scrollbar = ScrollbarState::new(packages.len())
        .position(app.pkg_offset)
        .viewport_content_length(app.right_viewport);
    frame.render_stateful_widget(
        Scrollbar::new(ScrollbarOrientation::VerticalRight)
            .begin_symbol(None)
            .end_symbol(None)
            .track_symbol(Some(" "))
            .thumb_symbol("█"),
        list_area,
        &mut scrollbar,
    );

    let hint = if app.focus == Focus::Selection {
        " Tab focus list   space toggle   enter next   esc back   q quit"
    } else {
        " Tab focus list   up/down scroll   pgup/pgdn page   home/end   q quit"
    };
    frame.render_widget(
        Paragraph::new(Line::from(Span::styled(hint, muted))),
        chunks[2],
    );
}

fn run(
    terminal: &mut Terminal<CrosstermBackend<io::Stdout>>,
    app: &mut App,
) -> Result<(), Box<dyn Error>> {
    loop {
        terminal.draw(|frame| draw(frame, app))?;
        match event::read()? {
            Event::Key(key) if key.kind == KeyEventKind::Press => match key.code {
                KeyCode::Char('q' | 'Q') => app.should_quit = true,
                KeyCode::Esc | KeyCode::Backspace => app.prev_page(),
                KeyCode::Char('c')
                    if key
                        .modifiers
                        .contains(ratatui::crossterm::event::KeyModifiers::CONTROL) =>
                {
                    app.should_quit = true;
                }
                KeyCode::Tab => {
                    app.focus = match app.focus {
                        Focus::Selection => Focus::Packages,
                        Focus::Packages => Focus::Selection,
                    };
                }
                KeyCode::Up => {
                    if app.focus == Focus::Packages {
                        app.scroll(-1);
                    } else {
                        app.move_cursor(-1);
                    }
                }
                KeyCode::Down => {
                    if app.focus == Focus::Packages {
                        app.scroll(1);
                    } else {
                        app.move_cursor(1);
                    }
                }
                KeyCode::PageUp => app.scroll(-(app.right_viewport as isize)),
                KeyCode::PageDown => app.scroll(app.right_viewport as isize),
                KeyCode::Home => app.pkg_offset = 0,
                KeyCode::End => {
                    app.pkg_offset = app.sidebar_len().saturating_sub(app.right_viewport);
                }
                KeyCode::Char(' ') | KeyCode::Enter => {
                    if app.focus == Focus::Selection {
                        if key.code == KeyCode::Enter && app.page != Page::Review {
                            app.next_page();
                        } else {
                            app.toggle();
                        }
                    }
                }
                _ => {}
            },
            Event::Mouse(mouse) => match mouse.kind {
                MouseEventKind::ScrollUp => app.scroll(-3),
                MouseEventKind::ScrollDown => app.scroll(3),
                MouseEventKind::Down(MouseButton::Left) => {
                    let inner = app.left_inner;
                    if inner.contains((mouse.column, mouse.row).into()) {
                        let index = (mouse.row - inner.y) as usize;
                        let max = app.cursor_max();
                        app.cursor = if app.page == Page::Review && index + 2 >= app.rows().len() {
                            (index + 2 - app.rows().len()).min(1)
                        } else {
                            index.min(max)
                        };
                        app.focus = Focus::Selection;
                    }
                }
                _ => {}
            },
            _ => {}
        }
        if app.should_quit {
            break;
        }
    }
    Ok(())
}

fn shell_quote(value: &str) -> String {
    format!("'{}'", value.replace('\'', r"'\''"))
}

fn shell_array(values: &[String]) -> String {
    format!(
        "({})",
        values
            .iter()
            .map(|value| shell_quote(value))
            .collect::<Vec<_>>()
            .join(" ")
    )
}

fn plan_output_path() -> Result<PathBuf, Box<dyn Error>> {
    match env::var_os("HOME") {
        Some(home) => {
            let base = env::var_os("XDG_STATE_HOME")
                .map(PathBuf::from)
                .unwrap_or_else(|| PathBuf::from(home).join(".local/state"));
            let dir = base.join("noon");
            fs::create_dir_all(&dir)?;
            Ok(dir.join("install-plan.json"))
        }
        None => Ok(env::temp_dir().join(format!("noon-plan-{}.json", std::process::id()))),
    }
}

const PLAN_USAGE: &str = concat!(
    "Usage: tui [--plan [OPTIONS] [--output FILE]] | [--plan-shell FILE]\n",
    "\n",
    "With no arguments, opens the interactive selector.\n",
    "--plan       Build a JSON install plan from classic install.sh flags.\n",
    "--output     Write the plan to FILE instead of stdout.\n",
    "--plan-shell Print shell variables from a plan file (used by install.sh).\n",
    "\n",
    "Plan flags: -f|--force --all --compositor ID --apps --desktop --dev|--devel\n",
    "            --misc|--extra --gaming --nvidia --nvidia-old --nvidia-driver ID\n",
    "            --no-libqt --onlydots --remove --components a,b --method copy|link\n",
);

fn plan_command(args: &[String]) -> Result<(), Box<dyn Error>> {
    let mut output = None;
    let mut flags = Vec::new();
    let mut i = 0;
    while i < args.len() {
        let arg = args[i].as_str();
        match arg {
            "--output" => {
                output = Some(PathBuf::from(
                    args.get(i + 1).ok_or("--output requires a file")?,
                ));
                i += 2;
                continue;
            }
            "--help" | "-h" => {
                println!("{PLAN_USAGE}");
                return Ok(());
            }
            _ if arg.starts_with("--output=") => {
                output = Some(PathBuf::from(&arg["--output=".len()..]));
            }
            _ => flags.push(args[i].clone()),
        }
        i += 1;
    }
    let mut app = App::new()?;
    app.apply_flags(&flags)?;
    let json = serde_json::to_string_pretty(&app.plan())?;
    match output {
        Some(path) => fs::write(path, json)?,
        None => println!("{json}"),
    }
    Ok(())
}

fn plan_shell_command(path: &str) -> Result<(), Box<dyn Error>> {
    let plan: Plan = serde_json::from_str(&fs::read_to_string(path)?)?;
    let app = App::new()?;
    let dots = env::var_os("NOON_DOTS_DIR")
        .map(PathBuf::from)
        .unwrap_or_else(|| app.repo.join("dots"));
    let drivers = load_drivers(&dots, &plan.distro);
    let nvidia = match plan.nvidia.as_str() {
        "nvidia" if plan.distro == "fedora" => "latest",
        "nvidia" => "open",
        "nvidia-old" => "580xx",
        other => other,
    };
    let compositor = if plan.compositor.is_empty() {
        "hyprland"
    } else {
        plan.compositor.as_str()
    };
    if plan.version != 1
        || (nvidia != "none" && !drivers.iter().any(|driver| driver.id == nvidia))
        || (compositor != "none" && !app.compositors.iter().any(|comp| comp.key == compositor))
        || !METHODS.iter().any(|(key, _)| *key == plan.method)
    {
        return Err("invalid install plan".into());
    }
    for (key, value) in [
        ("PLAN_DISTRO", shell_quote(&plan.distro)),
        ("PLAN_COMPOSITOR", shell_quote(compositor)),
        ("PLAN_BUNDLES", shell_array(&plan.bundles)),
        ("PLAN_COMPONENTS", shell_array(&plan.components)),
        ("PLAN_NVIDIA", shell_quote(nvidia)),
        ("PLAN_LIBQT", plan.libqt.to_string()),
        ("PLAN_METHOD", shell_quote(&plan.method)),
        ("PLAN_ONLYDOTS", plan.onlydots.to_string()),
        ("PLAN_REMOVE", plan.remove.to_string()),
        ("PLAN_FORCE", plan.force.to_string()),
    ] {
        println!("{key}={value}");
    }
    Ok(())
}

fn main() -> Result<(), Box<dyn Error>> {
    let args: Vec<String> = env::args().skip(1).collect();
    match args.first().map(String::as_str) {
        Some("--plan") => return plan_command(&args[1..]),
        Some("--plan-shell") => {
            let path = args.get(1).ok_or("--plan-shell requires a plan file")?;
            return plan_shell_command(path);
        }
        Some("--help") | Some("-h") => {
            println!("{PLAN_USAGE}");
            return Ok(());
        }
        Some(other) => return Err(format!("unknown option: {other}").into()),
        None => {}
    }

    let mut app = App::new()?;
    enable_raw_mode()?;
    let mut stdout = io::stdout();
    execute!(stdout, EnterAlternateScreen, EnableMouseCapture, Hide)?;
    let backend = CrosstermBackend::new(stdout);
    let mut terminal = Terminal::new(backend)?;
    let result = run(&mut terminal, &mut app);
    disable_raw_mode()?;
    execute!(
        terminal.backend_mut(),
        LeaveAlternateScreen,
        DisableMouseCapture,
        Show
    )?;
    result?;

    if app.confirmed {
        let path = plan_output_path()?;
        let installer = app.repo.join("install.sh");
        fs::write(&path, serde_json::to_string_pretty(&app.plan())?)?;
        println!("Plan saved to {}", path.display());
        println!("Running: {} --plan {}", installer.display(), path.display());
        return Err(Command::new(installer)
            .arg("--plan")
            .arg(&path)
            .exec()
            .into());
    }
    println!("Cancelled - no changes made.");
    Ok(())
}
