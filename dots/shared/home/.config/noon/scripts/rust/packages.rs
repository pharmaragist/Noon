//! Install or check Noon package groups.

use std::collections::{BTreeMap, HashSet};
use std::fs::{self, File};
use std::io::{self, Read, Write};
use std::os::unix::fs::PermissionsExt;
use std::path::{Path, PathBuf};
use std::process::{Command, ExitCode, Stdio};
use std::time::Duration;

use anyhow::{bail, Context, Result};
use clap::Parser;
use flate2::read::GzDecoder;
use serde::{Deserialize, Serialize};
use tar::Archive;
use ureq::Agent;

const PY_METADATA: &str = r#"
import importlib.metadata as metadata, sys
for name in sys.argv[1:]:
    try:
        metadata.version(name)
    except metadata.PackageNotFoundError:
        print(name)
"#;
const RETRIES: usize = 3;
const RETRY_DELAY: Duration = Duration::from_secs(1);

#[derive(Parser)]
#[command(
    about = "Install or check Noon package groups",
    arg_required_else_help = true
)]
struct Args {
    #[arg(long)]
    install: Option<String>,
    #[arg(long)]
    check: Option<String>,
    #[arg(long)]
    groups: bool,
    #[arg(long)]
    status: bool,
}

#[derive(Deserialize)]
struct PackagesFile {
    list: Vec<Group>,
}

#[derive(Deserialize)]
struct Group {
    name: String,
    #[serde(rename = "type")]
    kind: Option<String>,
    #[serde(default)]
    mirrors: BTreeMap<String, String>,
    #[serde(default)]
    dependencies: Vec<String>,
    #[serde(default)]
    commands: Vec<Vec<String>>,
    #[serde(default, rename = "postInstallCommands")]
    post_install: Vec<Vec<String>>,
}

#[derive(Serialize)]
struct GroupStatus {
    installed: bool,
    missing: Vec<String>,
}

enum Step {
    Fetch {
        url: String,
        dest: String,
        label: String,
    },
    Command {
        argv: Vec<String>,
        label: String,
    },
    Pip {
        dependency: String,
        label: String,
    },
}

impl Step {
    fn label(&self) -> &str {
        match self {
            Self::Fetch { label, .. } | Self::Command { label, .. } | Self::Pip { label, .. } => {
                label
            }
        }
    }
}

#[derive(Serialize)]
#[serde(tag = "event", rename_all = "lowercase")]
enum Event<'a> {
    Progress {
        group: &'a str,
        percent: u32,
        message: &'a str,
    },
    Error {
        group: &'a str,
        message: &'a str,
    },
}

struct Packages {
    groups: Vec<Group>,
}

impl Packages {
    fn load() -> Result<Self> {
        let path = std::env::var_os("NOON_PACKAGES_JSON")
            .map(PathBuf::from)
            .unwrap_or_else(|| home().join(".noon/user/packages.json"));
        let text =
            fs::read_to_string(&path).with_context(|| format!("reading {}", path.display()))?;
        let file: PackagesFile = serde_json::from_str(&text)?;
        Ok(Self { groups: file.list })
    }

    fn group(&self, name: &str) -> Option<&Group> {
        let wanted = name.trim().to_lowercase();
        self.groups
            .iter()
            .find(|group| group.name.trim().to_lowercase() == wanted)
    }

    fn missing(&self, group: &Group) -> Result<Vec<String>> {
        if group.kind.as_deref() == Some("fetch") {
            return Ok(group
                .mirrors
                .values()
                .filter(|dest| !expand_home(dest).exists())
                .cloned()
                .collect());
        }
        let missing = python_missing(&group.dependencies)?;
        Ok(group
            .dependencies
            .iter()
            .filter(|dependency| missing.contains(dependency.as_str()))
            .cloned()
            .collect())
    }

    fn missing_group(&self, name: &str) -> Result<Vec<String>> {
        let group = self
            .group(name)
            .with_context(|| format!("no package group named '{name}'"))?;
        self.missing(group)
    }

    fn status(&self) -> Result<BTreeMap<String, GroupStatus>> {
        let dependencies: Vec<String> = self
            .groups
            .iter()
            .flat_map(|group| group.dependencies.iter().cloned())
            .collect();
        let missing = python_missing(&dependencies)?;

        let mut status = BTreeMap::new();
        for group in &self.groups {
            let absent: Vec<String> = if group.kind.as_deref() == Some("fetch") {
                group
                    .mirrors
                    .values()
                    .filter(|dest| !expand_home(dest).exists())
                    .cloned()
                    .collect()
            } else {
                group
                    .dependencies
                    .iter()
                    .filter(|dependency| missing.contains(dependency.as_str()))
                    .cloned()
                    .collect()
            };
            status.insert(
                group.name.clone(),
                GroupStatus {
                    installed: absent.is_empty(),
                    missing: absent,
                },
            );
        }
        Ok(status)
    }

    fn install(&self, name: &str) -> Result<()> {
        let group = self
            .group(name)
            .with_context(|| format!("no package group named '{name}'"))?;
        let steps = group.steps();
        let total = steps.len().max(1);

        for (index, step) in steps.iter().enumerate() {
            let label = step.label();
            let start = index as f64 / total as f64;
            let width = 1.0 / total as f64;
            emit(&Event::Progress {
                group: name,
                percent: (start * 100.0).round() as u32,
                message: label,
            })?;

            let outcome = match step {
                Step::Fetch { url, dest, .. } => fetch(url, dest, &mut |fraction| {
                    let percent = ((start + fraction * width) * 100.0).round() as u32;
                    let _ = emit(&Event::Progress {
                        group: name,
                        percent,
                        message: label,
                    });
                }),
                Step::Command { argv, .. } => run(argv),
                Step::Pip { dependency, .. } => {
                    run(&["pip".to_string(), "install".to_string(), dependency.clone()])
                }
            };

            if let Err(error) = outcome {
                eprintln!("packages: {error:#}");
                emit(&Event::Error {
                    group: name,
                    message: label,
                })?;
                return Err(error);
            }
        }

        emit(&Event::Progress {
            group: name,
            percent: 100,
            message: "done",
        })
    }
}

impl Group {
    fn steps(&self) -> Vec<Step> {
        let mut steps = Vec::new();
        if self.kind.as_deref() == Some("fetch") {
            for (url, dest) in &self.mirrors {
                steps.push(Step::Fetch {
                    url: url.clone(),
                    dest: dest.clone(),
                    label: format!("fetch {}", basename(dest)),
                });
            }
        }
        for argv in &self.commands {
            if argv.is_empty() {
                continue;
            }
            steps.push(Step::Command {
                label: format!("running {}", argv.join(" ")),
                argv: argv.clone(),
            });
        }
        if self.kind.as_deref() == Some("python") {
            for dependency in &self.dependencies {
                steps.push(Step::Pip {
                    label: format!("pip install {dependency}"),
                    dependency: dependency.clone(),
                });
            }
        }
        for argv in &self.post_install {
            if argv.is_empty() {
                continue;
            }
            steps.push(Step::Command {
                label: format!("running {}", argv.join(" ")),
                argv: argv.clone(),
            });
        }
        steps
    }
}

fn emit(event: &Event<'_>) -> Result<()> {
    let mut stdout = io::stdout().lock();
    serde_json::to_writer(&mut stdout, event)?;
    stdout.write_all(b"\n")?;
    stdout.flush()?;
    Ok(())
}

fn python_missing(dependencies: &[String]) -> Result<HashSet<String>> {
    let mut seen = HashSet::new();
    let unique: Vec<&str> = dependencies
        .iter()
        .map(String::as_str)
        .filter(|dependency| seen.insert(*dependency))
        .collect();
    if unique.is_empty() {
        return Ok(HashSet::new());
    }

    let output = Command::new("python3")
        .arg("-c")
        .arg(PY_METADATA)
        .args(&unique)
        .output()
        .context("running python3")?;
    if !output.status.success() {
        bail!(
            "python3 metadata check failed: {}",
            String::from_utf8_lossy(&output.stderr).trim()
        );
    }
    Ok(String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(str::to_string)
        .collect())
}

fn fetch(url: &str, dest: &str, progress: &mut dyn FnMut(f64)) -> Result<()> {
    let destination = expand_home(dest);
    if let Some(parent) = destination.parent() {
        fs::create_dir_all(parent)?;
    }
    let part = PathBuf::from(format!("{}.part", destination.display()));
    let agent = agent();

    let mut last_error = None;
    for attempt in 0..RETRIES {
        match download(&agent, url, &part, progress) {
            Ok(()) => {
                last_error = None;
                break;
            }
            Err(error) => {
                last_error = Some(error);
                let _ = fs::remove_file(&part);
                if attempt + 1 < RETRIES {
                    std::thread::sleep(RETRY_DELAY);
                }
            }
        }
    }
    if let Some(error) = last_error {
        return Err(error);
    }

    if url.ends_with(".tar.gz") || url.ends_with(".tgz") {
        extract_lib(
            &part,
            destination.parent().unwrap_or_else(|| Path::new(".")),
        )?;
        fs::remove_file(&part)?;
    } else {
        fs::rename(&part, &destination)?;
    }
    Ok(())
}

fn download(agent: &Agent, url: &str, part: &Path, progress: &mut dyn FnMut(f64)) -> Result<()> {
    let mut response = agent
        .get(url)
        .call()
        .with_context(|| format!("downloading {url}"))?;
    let total = response
        .headers()
        .get("content-length")
        .and_then(|value| value.to_str().ok())
        .and_then(|value| value.parse::<u64>().ok());

    let mut reader = response.body_mut().as_reader();
    let mut file = File::create(part)?;
    let mut buffer = vec![0u8; 64 * 1024];
    let mut downloaded = 0u64;
    loop {
        let read = reader.read(&mut buffer)?;
        if read == 0 {
            break;
        }
        file.write_all(&buffer[..read])?;
        downloaded += read as u64;
        progress(total.map_or(0.0, |total| (downloaded as f64 / total as f64).min(1.0)));
    }
    progress(1.0);
    Ok(())
}

fn extract_lib(archive: &Path, parent: &Path) -> Result<()> {
    let mut archive = Archive::new(GzDecoder::new(File::open(archive)?));
    for entry in archive.entries()? {
        let mut entry = entry?;
        let path = entry.path()?.to_path_buf();
        if !path.starts_with("lib") || !entry.header().entry_type().is_file() {
            continue;
        }
        let Some(name) = path.file_name() else {
            continue;
        };
        let target = parent.join(name);
        let mut output = File::create(&target)?;
        io::copy(&mut entry, &mut output)?;
        fs::set_permissions(&target, fs::Permissions::from_mode(0o755))?;
    }
    Ok(())
}

fn run(argv: &[String]) -> Result<()> {
    let (program, args) = argv.split_first().context("empty command")?;
    let status = Command::new(program)
        .args(args)
        .stdout(Stdio::null())
        .status()
        .with_context(|| format!("running {program}"))?;
    if !status.success() {
        bail!("{program} exited with {status}");
    }
    Ok(())
}

fn agent() -> Agent {
    Agent::config_builder()
        .timeout_per_read(Some(Duration::from_secs(30)))
        .timeout_recv_response(Some(Duration::from_secs(30)))
        .user_agent("noon-packages/1.0")
        .build()
        .into()
}

fn home() -> PathBuf {
    dirs::home_dir().unwrap_or_default()
}

fn expand_home(path: &str) -> PathBuf {
    if let Some(rest) = path.strip_prefix("~/") {
        return home().join(rest);
    }
    if path == "~" {
        return home();
    }
    PathBuf::from(path)
}

fn basename(path: &str) -> &str {
    Path::new(path)
        .file_name()
        .and_then(|name| name.to_str())
        .unwrap_or(path)
}

fn main() -> ExitCode {
    match cli() {
        Ok(code) => code,
        Err(error) => {
            eprintln!("error: {error:#}");
            ExitCode::FAILURE
        }
    }
}

fn cli() -> Result<ExitCode> {
    let args = Args::parse();
    let packages = Packages::load()?;

    if args.groups {
        for group in &packages.groups {
            println!("{}", group.name);
        }
        return Ok(ExitCode::SUCCESS);
    }
    if args.status {
        println!("{}", serde_json::to_string_pretty(&packages.status()?)?);
        return Ok(ExitCode::SUCCESS);
    }
    if let Some(name) = args.install {
        packages.install(&name)?;
        return Ok(ExitCode::SUCCESS);
    }
    if let Some(name) = args.check {
        let missing = packages.missing_group(&name)?;
        for dependency in &missing {
            println!("{dependency}");
        }
        return Ok(if missing.is_empty() {
            ExitCode::SUCCESS
        } else {
            ExitCode::FAILURE
        });
    }

    Ok(ExitCode::FAILURE)
}
