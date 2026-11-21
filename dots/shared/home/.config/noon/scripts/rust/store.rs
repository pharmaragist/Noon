//! Noon plugin store: newline-delimited JSON over stdin/stdout.

use std::collections::{HashMap, HashSet};
use std::fs::{self, File};
use std::io::{self, BufRead, Read, Write};
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode};
use std::time::{Duration, Instant};

use anyhow::{anyhow, bail, Context, Result};
use clap::{Parser, Subcommand};
use flate2::read::GzDecoder;
use serde::Serialize;
use serde_json::{json, Value};
use ureq::Agent;
use walkdir::WalkDir;
use zip::ZipArchive;

const INDEX_URL: &str =
    "https://raw.githubusercontent.com/pharmaragist/Noon-Plugins/dist/plugins.json";
const USER_AGENT: &str = "noon-store/2.0";
const MAX_BYTES: u64 = 64 * 1024 * 1024;
const CACHE_TTL: Duration = Duration::from_secs(300);

#[derive(Parser)]
struct Args {
    #[command(subcommand)]
    command: Option<Action>,
}

#[derive(Subcommand)]
enum Action {
    Install {
        path: PathBuf,
        #[arg(short, long)]
        group: Option<String>,
        #[arg(short, long)]
        force: bool,
    },
}

#[derive(Clone)]
struct Plugin {
    id: String,
    name: String,
    group: String,
    description: String,
    version: String,
    maintainer: String,
    icon: String,
    preview: String,
    download: String,
}

#[derive(Serialize)]
struct PluginView<'a> {
    id: &'a str,
    name: &'a str,
    group: &'a str,
    description: &'a str,
    version: &'a str,
    maintainer: &'a str,
    icon: &'a str,
    preview: &'a str,
    installed: bool,
}

struct Store {
    agent: Agent,
    cache: Option<(Instant, Vec<Plugin>)>,
}

impl Store {
    fn new() -> Self {
        let agent: Agent = Agent::config_builder()
            .timeout_global(Some(Duration::from_secs(30)))
            .user_agent(USER_AGENT)
            .build()
            .into();
        Self { agent, cache: None }
    }

    fn fetch(&self, url: &str) -> Result<Vec<u8>> {
        let mut response = self
            .agent
            .get(url)
            .call()
            .with_context(|| format!("fetching {url}"))?;
        Ok(response
            .body_mut()
            .with_config()
            .limit(MAX_BYTES)
            .read_to_vec()?)
    }

    fn download(&self, url: &str, dest: &Path) -> Result<()> {
        let mut response = self
            .agent
            .get(url)
            .call()
            .with_context(|| format!("downloading {url}"))?;
        let parent = dest
            .parent()
            .context("download destination has no parent")?;
        fs::create_dir_all(parent)?;

        let mut file = tempfile::NamedTempFile::new_in(parent)?;
        let mut reader = response.body_mut().as_reader();
        let mut buffer = vec![0u8; 64 * 1024];
        let mut total = 0u64;
        loop {
            let read = reader.read(&mut buffer)?;
            if read == 0 {
                break;
            }
            total += read as u64;
            if total > MAX_BYTES {
                bail!("file too large");
            }
            file.write_all(&buffer[..read])?;
        }
        file.persist(dest).map_err(|error| error.error)?;
        Ok(())
    }

    fn load_plugins(&mut self, force: bool) -> Result<Vec<Plugin>> {
        if !force {
            if let Some((at, plugins)) = &self.cache {
                if at.elapsed() < CACHE_TTL {
                    return Ok(plugins.clone());
                }
            }
        }

        let raw: Value = serde_json::from_slice(&self.fetch(INDEX_URL)?)?;
        let mut plugins = Vec::new();
        for entry in raw
            .get("plugins")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
        {
            let (Some(id), Some(download)) = (
                entry.get("id").and_then(Value::as_str),
                entry.get("download").and_then(Value::as_str),
            ) else {
                continue;
            };
            let preview = entry
                .get("preview")
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .or_else(|| {
                    entry
                        .get("previews")
                        .and_then(Value::as_array)
                        .and_then(|previews| previews.first())
                        .and_then(Value::as_str)
                })
                .unwrap_or("");
            let name = entry
                .get("name")
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .unwrap_or(id);
            let group = entry
                .get("group")
                .and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .unwrap_or("widgets");

            plugins.push(Plugin {
                id: id.to_string(),
                name: name.to_string(),
                group: group.to_string(),
                description: text(entry, "description"),
                version: text(entry, "version"),
                maintainer: text(entry, "maintainer"),
                icon: text(entry, "icon"),
                preview: preview.to_string(),
                download: download.to_string(),
            });
        }

        self.cache = Some((Instant::now(), plugins.clone()));
        Ok(plugins)
    }

    fn list(&mut self, force: bool) -> Result<Value> {
        let plugins = self.load_plugins(force)?;
        let groups: HashSet<&str> = plugins.iter().map(|plugin| plugin.group.as_str()).collect();
        let installed: HashMap<&str, HashSet<String>> = groups
            .into_iter()
            .map(|group| (group, installed_names(group)))
            .collect();

        let views: Vec<PluginView> = plugins
            .iter()
            .map(|plugin| {
                let names = &installed[plugin.group.as_str()];
                PluginView {
                    installed: names.contains(&plugin.id.to_lowercase())
                        || names.contains(&plugin.name.to_lowercase()),
                    id: &plugin.id,
                    name: &plugin.name,
                    group: &plugin.group,
                    description: &plugin.description,
                    version: &plugin.version,
                    maintainer: &plugin.maintainer,
                    icon: &plugin.icon,
                    preview: &plugin.preview,
                }
            })
            .collect();

        Ok(json!({ "plugins": views }))
    }

    fn install(&mut self, id: &str) -> Result<Value> {
        let plugin = self
            .load_plugins(false)?
            .into_iter()
            .find(|plugin| plugin.id == id)
            .context("unknown plugin")?;

        let safe: String = id
            .chars()
            .map(|c| {
                if c.is_alphanumeric() || c == '-' || c == '_' || c == '.' {
                    c
                } else {
                    '_'
                }
            })
            .collect();
        let archive = cache_dir().join(format!("{safe}.zip"));
        self.download(&plugin.download, &archive)?;
        install_path(&archive, None, false)?;
        Ok(json!({ "id": id, "installed": true }))
    }
}

fn text(value: &Value, key: &str) -> String {
    value
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or_default()
        .to_string()
}

fn home() -> PathBuf {
    dirs::home_dir().unwrap_or_default()
}

fn plugins_dir() -> PathBuf {
    home().join(".noon_plugins")
}

fn cache_dir() -> PathBuf {
    std::env::var_os("XDG_CACHE_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|| home().join(".cache"))
        .join("noon-store")
}

fn expand_home(path: &Path) -> PathBuf {
    let text = path.to_string_lossy();
    if let Some(rest) = text.strip_prefix("~/") {
        return home().join(rest);
    }
    if text == "~" {
        return home();
    }
    path.to_path_buf()
}

fn installed_names(group: &str) -> HashSet<String> {
    let mut names = HashSet::new();
    let Ok(entries) = fs::read_dir(plugins_dir().join(group)) else {
        return names;
    };

    for entry in entries.flatten() {
        if !entry.path().is_dir() {
            continue;
        }
        names.insert(entry.file_name().to_string_lossy().to_lowercase());
        if let Ok(text) = fs::read_to_string(entry.path().join("manifest.json")) {
            if let Ok(manifest) = serde_json::from_str::<Value>(&text) {
                if let Some(name) = manifest.get("name").and_then(Value::as_str) {
                    names.insert(name.to_lowercase());
                }
            }
        }
    }
    names
}

fn install_path(path: &Path, group: Option<&str>, force: bool) -> Result<(String, String)> {
    let path = expand_home(path);
    if !path.exists() {
        bail!("Source '{}' not found", path.display());
    }

    let temp = if path.is_dir() {
        None
    } else {
        let temp = tempfile::tempdir()?;
        extract(&path, temp.path())?;
        Some(temp)
    };
    let root = temp
        .as_ref()
        .map(|temp| temp.path().to_path_buf())
        .unwrap_or_else(|| path.clone());

    let manifest_path = if temp.is_some() {
        find_manifest(&root)?.with_context(|| format!("No manifest.json in {}", path.display()))?
    } else {
        let manifest = root.join("manifest.json");
        if !manifest.is_file() {
            bail!("No manifest.json in '{}'", path.display());
        }
        manifest
    };
    let manifest: Value = serde_json::from_str(&fs::read_to_string(&manifest_path)?)?;

    let name = manifest
        .get("name")
        .and_then(Value::as_str)
        .filter(|name| !name.is_empty())
        .context("manifest has no name")?
        .to_string();
    let group = group
        .map(str::to_string)
        .or_else(|| {
            manifest
                .get("pluginGroup")
                .and_then(Value::as_str)
                .filter(|group| !group.is_empty())
                .map(str::to_string)
        })
        .context("No pluginGroup in manifest, use -g to specify")?;

    let source = manifest_path.parent().context("manifest has no parent")?;
    let destination = plugins_dir().join(&group).join(&name);
    if destination.exists() {
        fs::remove_dir_all(&destination)?;
    }
    fs::create_dir_all(destination.parent().unwrap_or(&destination))?;
    copy_dir(source, &destination)?;

    ensure_python_requirements(&destination)?;
    ensure_qml_setup(&destination, &name, force)?;
    Ok((group, name))
}

fn extract(archive: &Path, target: &Path) -> Result<()> {
    let name = archive.file_name().unwrap_or_default().to_string_lossy();
    let file = || File::open(archive).map_err(anyhow::Error::from);

    if name.ends_with(".zip") {
        ZipArchive::new(file()?)?.extract(target)?;
    } else if name.ends_with(".tar.gz") || name.ends_with(".tgz") {
        tar::Archive::new(GzDecoder::new(file()?)).unpack(target)?;
    } else if name.ends_with(".tar.bz2") || name.ends_with(".tbz2") {
        tar::Archive::new(bzip2::read::BzDecoder::new(file()?)).unpack(target)?;
    } else if name.ends_with(".tar.xz") || name.ends_with(".txz") {
        tar::Archive::new(xz2::read::XzDecoder::new(file()?)).unpack(target)?;
    } else if name.ends_with(".tar") {
        tar::Archive::new(file()?).unpack(target)?;
    } else {
        bail!("Unsupported format. Use a directory, .tar, .tar.gz, or .zip");
    }
    Ok(())
}

fn find_manifest(root: &Path) -> Result<Option<PathBuf>> {
    let mut found: Vec<PathBuf> = WalkDir::new(root)
        .max_depth(2)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_file() && entry.file_name() == "manifest.json")
        .map(|entry| entry.into_path())
        .collect();
    found.sort();
    Ok(found.into_iter().next())
}

fn copy_dir(source: &Path, destination: &Path) -> Result<()> {
    fs::create_dir_all(destination)?;
    for entry in fs::read_dir(source)? {
        let entry = entry?;
        let target = destination.join(entry.file_name());
        let kind = entry.file_type()?;
        if kind.is_dir() {
            copy_dir(&entry.path(), &target)?;
        } else if kind.is_symlink() {
            std::os::unix::fs::symlink(fs::read_link(entry.path())?, target)?;
        } else {
            fs::copy(entry.path(), target)?;
        }
    }
    Ok(())
}

fn ensure_python_requirements(plugin_dir: &Path) -> Result<()> {
    let manifest: Value =
        serde_json::from_str(&fs::read_to_string(plugin_dir.join("manifest.json"))?)?;
    let requirements: Vec<&str> = manifest
        .get("pythonRequirements")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .collect();
    if requirements.is_empty() {
        return Ok(());
    }

    let Some(venv) = std::env::var_os("SHELL_VENV") else {
        return Ok(());
    };
    if !Path::new(&venv).is_dir() {
        return Ok(());
    }

    let output = Command::new("uv")
        .arg("--directory")
        .arg(&venv)
        .args(["pip", "install"])
        .args(&requirements)
        .output()
        .context("running uv")?;
    if !output.status.success() {
        bail!("{}", failure(&output));
    }
    Ok(())
}

fn ensure_qml_setup(plugin_dir: &Path, name: &str, force: bool) -> Result<()> {
    if plugin_dir.join("qmldir").exists() && !force {
        return Ok(());
    }

    let manifest: Value =
        serde_json::from_str(&fs::read_to_string(plugin_dir.join("manifest.json"))?)?;
    let version = manifest
        .get("version")
        .map(value_string)
        .unwrap_or_else(|| "1.0".to_string());
    let singletons: HashSet<String> = manifest
        .get("singletons")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_string)
        .collect();

    let mut directories: Vec<PathBuf> = WalkDir::new(plugin_dir)
        .into_iter()
        .filter_map(Result::ok)
        .filter(|entry| entry.file_type().is_dir())
        .map(|entry| entry.into_path())
        .collect();
    directories.sort();

    for directory in directories {
        let relative = directory.strip_prefix(plugin_dir).unwrap_or(Path::new(""));
        let module = if relative.as_os_str().is_empty() {
            name.to_string()
        } else {
            let suffix: Vec<String> = relative
                .components()
                .map(|part| part.as_os_str().to_string_lossy().into_owned())
                .collect();
            format!("{name}.{}", suffix.join("."))
        };
        write_qmldir(&directory, &module, &version, &singletons, force)?;
    }
    Ok(())
}

fn write_qmldir(
    directory: &Path,
    module: &str,
    version: &str,
    singletons: &HashSet<String>,
    force: bool,
) -> Result<()> {
    let target = directory.join("qmldir");
    if target.exists() && !force {
        return Ok(());
    }

    let mut files: Vec<PathBuf> = fs::read_dir(directory)?
        .filter_map(Result::ok)
        .map(|entry| entry.path())
        .filter(|path| path.extension().is_some_and(|extension| extension == "qml"))
        .collect();
    files.sort();

    let mut text = format!("module {module}\n");
    for file in files {
        let basename = file.file_name().unwrap_or_default().to_string_lossy();
        let component = file.file_stem().unwrap_or_default().to_string_lossy();
        if singletons.contains(basename.as_ref()) {
            text.push_str(&format!("singleton {component} {version} {basename}\n"));
        } else {
            text.push_str(&format!("{component} {version} {basename}\n"));
        }
    }
    fs::write(target, text)?;
    Ok(())
}

fn value_string(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        Value::Null => "1.0".to_string(),
        other => other.to_string(),
    }
}

fn failure(output: &std::process::Output) -> String {
    let stderr = String::from_utf8_lossy(&output.stderr);
    let stdout = String::from_utf8_lossy(&output.stdout);
    let message = if stderr.trim().is_empty() {
        stdout.trim()
    } else {
        stderr.trim()
    };
    if message.is_empty() {
        "install failed".to_string()
    } else {
        message.to_string()
    }
}

fn handle(store: &mut Store, line: &str) -> (Value, Result<Value>) {
    let request: Value = match serde_json::from_str(line) {
        Ok(request) => request,
        Err(error) => return (Value::Null, Err(error.into())),
    };
    let id = request.get("id").cloned().unwrap_or(Value::Null);
    let params = request.get("params").cloned().unwrap_or_else(|| json!({}));

    let result = match request.get("method").and_then(Value::as_str) {
        Some("list") => store.list(
            params
                .get("force")
                .and_then(Value::as_bool)
                .unwrap_or(false),
        ),
        Some("install") => match params.get("id").and_then(Value::as_str) {
            Some(id) => store.install(id),
            None => Err(anyhow!("unknown plugin")),
        },
        Some(method) => Err(anyhow!("unknown method {method}")),
        None => Err(anyhow!("unknown method None")),
    };
    (id, result)
}

fn daemon() -> ExitCode {
    let mut store = Store::new();
    let mut stdout = io::stdout();
    for line in io::stdin().lock().lines() {
        let Ok(line) = line else {
            break;
        };
        let line = line.trim();
        if line.is_empty() {
            continue;
        }

        let (id, result) = handle(&mut store, line);
        let message = match result {
            Ok(result) => json!({ "id": id, "result": result }),
            Err(error) => json!({
                "id": id,
                "error": { "code": "store_error", "message": error.to_string() },
            }),
        };
        if writeln!(stdout, "{message}")
            .and_then(|_| stdout.flush())
            .is_err()
        {
            break;
        }
    }
    ExitCode::SUCCESS
}

fn main() -> ExitCode {
    let args = Args::parse();
    match args.command {
        Some(Action::Install { path, group, force }) => {
            match install_path(&path, group.as_deref(), force) {
                Ok((group, name)) => {
                    println!("Installed {group}/{name}");
                    ExitCode::SUCCESS
                }
                Err(error) => {
                    eprintln!("{error:#}");
                    ExitCode::FAILURE
                }
            }
        }
        None => daemon(),
    }
}
