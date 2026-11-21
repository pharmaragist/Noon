use anyhow::Result;
use clap::{Parser, Subcommand};
use ini::Ini;
use rayon::prelude::*;
use serde::Serialize;
use std::collections::HashSet;
use std::fs;
use std::io::Read;
use std::path::PathBuf;
use std::process::{Command, ExitCode, Stdio};
use std::time::Duration;
use wait_timeout::ChildExt;

const TIMEOUT: Duration = Duration::from_secs(2);

#[derive(Parser)]
#[command(name = "icon-theme-manager", about = "List or set Qt/GTK icon themes")]
struct Cli {
    #[command(subcommand)]
    command: Commands,
}

#[derive(Subcommand)]
enum Commands {
    List,
    Set { theme_id: String },
}

#[derive(Serialize)]
struct IconThemeInfo {
    id: String,
    name: String,
    current: bool,
    preview: Option<String>,
}

#[derive(Serialize)]
struct SetThemeResult {
    theme: String,
    qt: bool,
    gtk: bool,
    success: bool,
}

fn icon_base_dirs() -> Vec<PathBuf> {
    let mut dirs = vec![PathBuf::from("/usr/share/icons")];
    if let Some(home) = dirs::home_dir() {
        dirs.push(home.join(".local/share/icons"));
        dirs.push(home.join(".icons"));
    }
    dirs
}

fn run_cmd(program: &str, args: &[&str]) -> Option<String> {
    let mut child = Command::new(program)
        .args(args)
        .stdout(Stdio::piped())
        .stderr(Stdio::null())
        .spawn()
        .ok()?;

    match child.wait_timeout(TIMEOUT).ok()? {
        Some(status) if status.success() => {}
        Some(_) => return None,
        None => {
            let _ = child.kill();
            let _ = child.wait();
            return None;
        }
    }

    let mut output = String::new();
    child.stdout.take()?.read_to_string(&mut output).ok()?;
    Some(output.trim().to_string())
}

fn run_value(program: &str, args: &[&str]) -> Option<String> {
    run_cmd(program, args).filter(|value| !value.is_empty())
}

fn run_ok(program: &str, args: &[&str]) -> bool {
    run_cmd(program, args).is_some()
}

fn gtk_theme() -> Option<String> {
    let path = dirs::home_dir()?.join(".config/gtk-3.0/settings.ini");
    let ini = Ini::load_from_file(path).ok()?;
    let value = ini.section(Some("Settings"))?.get("gtk-icon-theme-name")?;
    (!value.is_empty()).then(|| value.to_string())
}

fn current_themes() -> (Option<String>, Option<String>) {
    let qt = run_value("kreadconfig6", &["--group", "Icons", "--key", "Theme"])
        .or_else(|| run_value("kreadconfig5", &["--group", "Icons", "--key", "Theme"]));
    let gtk = gtk_theme().or_else(|| {
        let value = run_value(
            "gsettings",
            &["get", "org.gnome.desktop.interface", "icon-theme"],
        )?;
        let value = value.trim_matches(['\'', '"']).trim();
        (!value.is_empty()).then(|| value.to_string())
    });
    (qt, gtk)
}

fn find_theme_dir(theme: &str, bases: &[PathBuf]) -> Option<PathBuf> {
    bases
        .iter()
        .map(|base| base.join(theme))
        .find(|candidate| candidate.join("index.theme").is_file())
}

fn find_icon(
    theme: &str,
    icon: &str,
    bases: &[PathBuf],
    visited: &mut HashSet<String>,
) -> Option<String> {
    if !visited.insert(theme.to_string()) {
        return None;
    }
    let dir = find_theme_dir(theme, bases)?;
    let ini = Ini::load_from_file(dir.join("index.theme")).ok()?;
    let section = ini.section(Some("Icon Theme"))?;

    let mut scalable = Vec::new();
    let mut other = Vec::new();
    for entry in section
        .get("Directories")
        .unwrap_or_default()
        .split(',')
        .map(str::trim)
        .filter(|entry| !entry.is_empty())
    {
        let is_scalable = ini
            .section(Some(entry))
            .and_then(|section| section.get("Type"))
            == Some("Scalable");
        if is_scalable {
            scalable.push(entry);
        } else {
            other.push(entry);
        }
    }

    for entry in scalable.into_iter().chain(other) {
        for extension in ["svg", "png", "xpm"] {
            let candidate = dir.join(entry).join(format!("{icon}.{extension}"));
            if candidate.is_file() {
                return Some(candidate.to_string_lossy().into_owned());
            }
        }
    }

    for parent in section
        .get("Inherits")
        .unwrap_or_default()
        .split(',')
        .map(str::trim)
        .filter(|parent| !parent.is_empty())
    {
        if let Some(found) = find_icon(parent, icon, bases, visited) {
            return Some(found);
        }
    }

    (theme != "hicolor")
        .then(|| find_icon("hicolor", icon, bases, visited))
        .flatten()
}

fn themes(bases: &[PathBuf], qt: Option<&str>, gtk: Option<&str>) -> Vec<IconThemeInfo> {
    let mut seen = HashSet::new();
    let mut found = Vec::new();

    for base in bases {
        let Ok(entries) = fs::read_dir(base) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            let Some(id) = path.file_name().and_then(|name| name.to_str()) else {
                continue;
            };
            if !path.is_dir() || !seen.insert(id.to_string()) {
                continue;
            }
            let Ok(ini) = Ini::load_from_file(path.join("index.theme")) else {
                continue;
            };
            let Some(section) = ini.section(Some("Icon Theme")) else {
                continue;
            };
            let directories = section.get("Directories").unwrap_or_default().trim();
            if path.join("cursors").exists() && directories.is_empty() {
                continue;
            }
            let name = section
                .get("Name")
                .filter(|name| !name.is_empty())
                .unwrap_or(id)
                .to_string();
            found.push((id.to_string(), name));
        }
    }

    let mut themes: Vec<IconThemeInfo> = found
        .into_par_iter()
        .map(|(id, name)| {
            let mut visited = HashSet::new();
            IconThemeInfo {
                current: qt.is_some_and(|current| current == id)
                    || gtk.is_some_and(|current| current == id),
                preview: find_icon(&id, "folder", bases, &mut visited),
                id,
                name,
            }
        })
        .collect();

    themes.sort_by(|a, b| a.name.to_lowercase().cmp(&b.name.to_lowercase()));
    themes
}

fn update_gtk_theme(theme: &str) -> bool {
    let Some(path) = dirs::home_dir().map(|home| home.join(".config/gtk-3.0/settings.ini")) else {
        return false;
    };
    if let Some(parent) = path.parent() {
        if fs::create_dir_all(parent).is_err() {
            return false;
        }
    }

    let mut ini = if path.exists() {
        match Ini::load_from_file(&path) {
            Ok(ini) => ini,
            Err(_) => return false,
        }
    } else {
        Ini::new()
    };
    ini.with_section(Some("Settings"))
        .set("gtk-icon-theme-name", theme);
    ini.write_to_file(path).is_ok()
}

fn set_theme(theme: &str) -> SetThemeResult {
    let qt = run_ok(
        "kwriteconfig6",
        &["--group", "Icons", "--key", "Theme", theme],
    ) || run_ok(
        "kwriteconfig5",
        &["--group", "Icons", "--key", "Theme", theme],
    );
    let gtk = update_gtk_theme(theme)
        || run_ok(
            "gsettings",
            &["set", "org.gnome.desktop.interface", "icon-theme", theme],
        );

    SetThemeResult {
        theme: theme.to_string(),
        qt,
        gtk,
        success: qt || gtk,
    }
}

fn run() -> Result<ExitCode> {
    match Cli::parse().command {
        Commands::List => {
            let (qt, gtk) = current_themes();
            let list = themes(&icon_base_dirs(), qt.as_deref(), gtk.as_deref());
            println!("{}", serde_json::to_string_pretty(&list)?);
            Ok(ExitCode::SUCCESS)
        }
        Commands::Set { theme_id } => {
            let result = set_theme(&theme_id);
            println!("{}", serde_json::to_string_pretty(&result)?);
            Ok(if result.success {
                ExitCode::SUCCESS
            } else {
                ExitCode::FAILURE
            })
        }
    }
}

fn main() -> ExitCode {
    match run() {
        Ok(code) => code,
        Err(error) => {
            eprintln!("Error: {error:#}");
            ExitCode::FAILURE
        }
    }
}
