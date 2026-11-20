use anyhow::{bail, Context, Result};
use smol::future::FutureExt;
use regex::Regex;
use serde_json::{Map, Value};
use std::collections::{BTreeSet, HashMap, HashSet};
use std::fs;
use std::io::Write;
use std::os::unix::fs::{symlink, OpenOptionsExt};
use std::path::{Path, PathBuf};
use std::time::Duration;

const SHELL_IPC_HELPER: &str = r#"async function shellIpc(target: string, fn: string, params: string[], values: Record<string, unknown>): Promise<string> {
  const argv: string[] = ["qs", "-p", SHELL_ROOT, "ipc", "call", target, fn];
  for (const p of params) {
    const v = values[p];
    argv.push(v === undefined || v === null ? "" : String(v));
  }
  const proc = Bun.spawn(argv, { stdout: "pipe", stderr: "pipe" });
  const [out, err, code] = await Promise.all([
    new Response(proc.stdout).text(),
    new Response(proc.stderr).text(),
    proc.exited,
  ]);
  const text = (out + err).trim();
  if (code !== 0)
    throw new Error(text === "" ? fn + " exited " + code : text);
  return text;
}

"#;

#[derive(Clone)]
struct Tool {
    target: String,
    function: String,
    params: Vec<String>,
    desc: String,
}

impl Tool {
    fn ipc_name(&self) -> String {
        format!("{}_{}", self.target, self.function)
    }
}

fn fallback_tools() -> Vec<Tool> {
    vec![
        Tool {
            target: "global".into(),
            function: "toast".into(),
            params: vec!["info".into(), "state".into()],
            desc: String::new(),
        },
        Tool {
            target: "noon".into(),
            function: "translate".into(),
            params: vec!["query".into()],
            desc: String::new(),
        },
        Tool {
            target: "global".into(),
            function: "say".into(),
            params: vec!["text".into()],
            desc: String::new(),
        },
    ]
}

/// Go's `strconv.Quote`. For the ASCII identifiers/descriptions used here,
/// serde_json's string quoting is byte-for-byte equivalent.
fn quote(s: &str) -> String {
    serde_json::to_string(s).expect("string quoting cannot fail")
}

/// skills: emit the sorted names of skill directories containing a valid SKILL.md.
pub fn cmd_skills() -> Result<()> {
    let home = std::env::var("HOME").unwrap_or_default();
    let root = Path::new(&home).join(".config").join("opencode").join("skills");

    let mut set = BTreeSet::new();
    for entry in walkdir::WalkDir::new(&root) {
        let entry = match entry {
            Ok(e) => e,
            Err(_) => continue,
        };
        if entry.file_type().is_dir() || entry.file_name().to_string_lossy() != "SKILL.md" {
            continue;
        }
        let data = match fs::read_to_string(entry.path()) {
            Ok(d) => d,
            Err(_) => continue,
        };
        for line in data.split('\n') {
            if let Some(rest) = line.strip_prefix("name:") {
                if !rest.trim().is_empty() {
                    if let Some(name) = entry.path().parent().and_then(Path::file_name) {
                        set.insert(name.to_string_lossy().into_owned());
                    }
                    break;
                }
            }
        }
    }

    let out: Vec<String> = set.into_iter().collect();
    crate::events::emit(&out)
}

fn parse_tools(out: &str) -> Vec<Tool> {
    let target_re = Regex::new(r"^target (\S+)\s*$").expect("static regex");
    let fn_re = Regex::new(r"^\s*function (\w+)\(([^)]*)\)").expect("static regex");

    let mut tools = Vec::new();
    let mut seen = HashSet::new();
    let mut target = String::new();
    for line in out.split('\n') {
        if let Some(caps) = target_re.captures(line) {
            target = caps[1].to_string();
            continue;
        }
        if target.is_empty() {
            continue;
        }
        if let Some(caps) = fn_re.captures(line) {
            let name = caps[1].to_string();
            let mut params = Vec::new();
            for p in caps[2].split(',') {
                let mut p = p.trim();
                if let Some(i) = p.find(':') {
                    p = p[..i].trim();
                }
                if !p.is_empty() {
                    params.push(p.to_string());
                }
            }
            let key = format!("{}_{}", target, name);
            if seen.insert(key) {
                tools.push(Tool {
                    target: target.clone(),
                    function: name,
                    params,
                    desc: String::new(),
                });
            }
        }
    }
    tools
}

fn enrich_descriptions(shell_root: &str, tools: &mut [Tool]) {
    let desc_re = Regex::new(r"^\s*//\*\s*(.+?)\s*$").expect("static regex");
    let fn_re = Regex::new(r"^\s*function (\w+)\(([^)]*)\)").expect("static regex");

    let mut descs: HashMap<String, String> = HashMap::new();
    let files = [
        Path::new(shell_root).join("GlobalIPC.qml"),
        Path::new(shell_root)
            .join("modules")
            .join("main")
            .join("NIPC.qml"),
    ];
    for path in &files {
        let data = match fs::read_to_string(path) {
            Ok(d) => d,
            Err(_) => continue,
        };
        let mut pending = String::new();
        for line in data.split('\n') {
            if let Some(caps) = desc_re.captures(line) {
                pending = caps[1].trim().to_string();
                continue;
            }
            if let Some(caps) = fn_re.captures(line) {
                if !pending.is_empty() {
                    descs
                        .entry(caps[1].to_string())
                        .or_insert_with(|| pending.clone());
                    pending.clear();
                }
                continue;
            }
            let trimmed = line.trim();
            if !trimmed.is_empty() && !trimmed.starts_with("//") {
                pending.clear();
            }
        }
    }

    for tool in tools.iter_mut() {
        tool.desc = descs.get(&tool.function).cloned().unwrap_or_else(|| {
            format!("Noon shell: {} {}", tool.target, tool.function)
        });
    }
}

/// gen-tools: emit the generated TypeScript tool definitions to stdout.
pub fn cmd_gen_tools(shell_root: &str) -> Result<()> {
    let timeout = async {
        smol::Timer::after(Duration::from_secs(15)).await;
        None
    };
    let run = async {
        let mut cmd = smol::process::Command::new("qs");
        cmd.args(["-p", shell_root, "ipc", "show"]);
        // exec.CommandContext kills the child when the context deadline fires.
        cmd.kill_on_drop(true);
        cmd.output()
            .await
            .ok()
            .filter(|out| out.status.success())
    };
    let output = smol::block_on(timeout.race(run));

    let mut tools = match output {
        Some(out) => {
            let parsed = parse_tools(&String::from_utf8_lossy(&out.stdout));
            if parsed.is_empty() {
                fallback_tools()
            } else {
                parsed
            }
        }
        None => fallback_tools(),
    };
    enrich_descriptions(shell_root, &mut tools);

    let mut sb = String::new();
    sb.push_str("// Generated by Noon shell (harness gen-tools). Do not edit by hand.\n");
    sb.push_str("import { tool } from \"@opencode-ai/plugin\";\n\n");
    sb.push_str(&format!("const SHELL_ROOT = {};\n\n", quote(shell_root)));
    sb.push_str(SHELL_IPC_HELPER);

    for tool in &tools {
        sb.push_str(&format!("export const {} = tool({{\n", tool.ipc_name()));
        sb.push_str(&format!("  description: {},\n", quote(&tool.desc)));
        sb.push_str("  args: {\n");
        for p in &tool.params {
            sb.push_str(&format!(
                "    {}: tool.schema.string().describe({}),\n",
                p,
                quote(p)
            ));
        }
        sb.push_str("  },\n");
        sb.push_str("  async execute(args) {\n");
        sb.push_str(&format!(
            "    return await shellIpc({}, {}, [",
            quote(&tool.target),
            quote(&tool.function)
        ));
        for (i, p) in tool.params.iter().enumerate() {
            if i > 0 {
                sb.push_str(", ");
            }
            sb.push_str(&quote(p));
        }
        sb.push_str("], args);\n  },\n});\n\n");
    }
    print!("{}", sb);
    Ok(())
}

/// Port of Go's cleanJSONC: strips // and /* */ comments and trailing commas,
/// respecting string contents and backslash escapes.
fn clean_jsonc(src: &str) -> String {
    let b = src.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(b.len());
    let (mut in_str, mut esc) = (false, false);
    let (mut i, n) = (0usize, b.len());

    let is_ws = |c: u8| c == b' ' || c == b'\t' || c == b'\n' || c == b'\r';

    while i < n {
        let c = b[i];
        if in_str {
            out.push(c);
            if esc {
                esc = false;
            } else if c == b'\\' {
                esc = true;
            } else if c == b'"' {
                in_str = false;
            }
            i += 1;
            continue;
        }
        if c == b'"' {
            in_str = true;
            out.push(c);
            i += 1;
        } else if c == b'/' && i + 1 < n && b[i + 1] == b'/' {
            while i < n && b[i] != b'\n' {
                i += 1;
            }
        } else if c == b'/' && i + 1 < n && b[i + 1] == b'*' {
            i += 2;
            while i + 1 < n && !(b[i] == b'*' && b[i + 1] == b'/') {
                i += 1;
            }
            i += 2;
            if i > n {
                i = n;
            }
        } else if c == b',' {
            let mut j = i + 1;
            while j < n && is_ws(b[j]) {
                j += 1;
            }
            if j < n && (b[j] == b'}' || b[j] == b']') {
                i += 1;
                continue;
            }
            out.push(c);
            i += 1;
        } else {
            out.push(c);
            i += 1;
        }
    }
    String::from_utf8(out).unwrap_or_else(|_| src.to_string())
}

fn perm_fill(m: &mut Map<String, Value>) {
    let p = m
        .entry("permission".to_string())
        .or_insert_with(|| Value::Object(Map::new()));
    if !p.is_object() {
        *p = Value::Object(Map::new());
    }
    let p = p.as_object_mut().expect("permission is an object");
    p.entry("*".to_string())
        .or_insert_with(|| Value::String("ask".into()));
    p.entry("read".to_string())
        .or_insert_with(|| Value::String("allow".into()));
    // Question forms must never be gated behind a permission prompt.
    p.entry("question".to_string())
        .or_insert_with(|| Value::String("allow".into()));
}

/// encoding/json's Marshal escapes HTML by default; serde_json does not.
fn go_escape_html(s: &mut String) {
    let escaped = s
        .replace('<', "\\u003c")
        .replace('>', "\\u003e")
        .replace('&', "\\u0026")
        .replace('\u{2028}', "\\u2028")
        .replace('\u{2029}', "\\u2029");
    *s = escaped;
}

fn write_json(path: &Path, v: &Value) -> Result<()> {
    let mut data = serde_json::to_string_pretty(v).context("marshal JSON")?;
    go_escape_html(&mut data);
    data.push('\n');
    let mut file = fs::OpenOptions::new()
        .write(true)
        .create(true)
        .truncate(true)
        .mode(0o644)
        .open(path)
        .with_context(|| format!("open {}", path.display()))?;
    file.write_all(data.as_bytes())
        .with_context(|| format!("write {}", path.display()))?;
    Ok(())
}

/// filepath.Dir, including the "." result for bare filenames.
fn go_dir(path: &str) -> PathBuf {
    let parent = Path::new(path).parent().unwrap_or_else(|| Path::new(""));
    if parent.as_os_str().is_empty() {
        PathBuf::from(".")
    } else {
        parent.to_path_buf()
    }
}

/// sync-config: normalize the global config, write the scoped config, and
/// symlink neighbouring files into the side directory.
pub fn cmd_sync_config(global_cfg: &str, side_dir: &str) -> Result<()> {
    if global_cfg.is_empty() || side_dir.is_empty() {
        bail!("sync-config needs <globalCfg> <sideDir>");
    }

    // Go's os.ReadFile succeeds on arbitrary bytes and only substitutes `{}`
    // on a real I/O error; encoding/json replaces invalid UTF-8 with U+FFFD.
    // read_to_string would instead turn bad bytes into an I/O-style error and
    // then overwrite the real config with `{}`.
    let bytes = fs::read(global_cfg).unwrap_or_else(|_| b"{}".to_vec());
    let raw = String::from_utf8_lossy(&bytes);
    let cleaned = clean_jsonc(&raw);
    let parsed: Value = serde_json::from_str(&cleaned)
        .with_context(|| format!("parse {global_cfg}"))?;
    let mut global = match parsed {
        Value::Object(m) => m,
        Value::Null => Map::new(),
        _ => bail!("parse {global_cfg}: cannot unmarshal value into object"),
    };

    if let Some(Value::Array(instructions)) = global.get_mut("instructions") {
        instructions.retain(|entry| {
            !entry
                .as_str()
                .map_or(false, |s| s.contains("harness/main.md"))
        });
    }
    if global.get("default_agent").and_then(Value::as_str) == Some("noon") {
        global.remove("default_agent");
    }
    perm_fill(&mut global);
    write_json(Path::new(global_cfg), &Value::Object(global.clone()))?;

    let mut scoped = global.clone();
    scoped.insert("default_agent".to_string(), Value::String("noon".into()));
    perm_fill(&mut scoped);

    let side = Path::new(side_dir);
    fs::create_dir_all(side.join("agents")).context("create agents dir")?;
    fs::create_dir_all(side.join("tools")).context("create tools dir")?;

    let dir = go_dir(global_cfg);
    let entries = fs::read_dir(&dir)
        .with_context(|| format!("read dir {}", dir.display()))?;
    let skip = ["opencode.jsonc", "opencode.jsonc.tmp", "agents", "tools", "system.md"];
    for entry in entries {
        let entry = match entry {
            Ok(e) => e,
            Err(_) => continue,
        };
        let name = entry.file_name();
        let name_str = name.to_string_lossy();
        if skip.contains(&&*name_str) {
            continue;
        }
        let dst = side.join(&name);
        if fs::symlink_metadata(&dst).is_ok() {
            continue;
        }
        let _ = symlink(dir.join(&name), &dst);
    }

    let _ = fs::remove_file(side.join("opencode.jsonc.tmp"));
    write_json(&side.join("opencode.jsonc"), &Value::Object(scoped))?;

    print!("ok");
    let _ = std::io::stdout().flush();
    Ok(())
}

/// ACP env/headers are arrays of `{name, value}`; OpenCode v2 config stores
/// them as objects (older configs may already use arrays, which pass through).
fn mcp_pairs(v: Option<&Value>) -> Option<Value> {
    let pairs: Vec<Value> = match v? {
        Value::Array(a) => a.clone(),
        Value::Object(m) => m
            .iter()
            .map(|(k, val)| serde_json::json!({ "name": k, "value": val }))
            .collect(),
        _ => return None,
    };
    if pairs.is_empty() {
        None
    } else {
        Some(Value::Array(pairs))
    }
}

/// Translate one OpenCode MCP entry into an ACP `McpServer` object.
fn mcp_server(name: &str, e: &Map<String, Value>) -> Option<Value> {
    if e.get("disabled").and_then(Value::as_bool) == Some(true) { return None; }
    if e.get("enabled").and_then(Value::as_bool) == Some(false) { return None; }

    let ty = e.get("type").and_then(Value::as_str).unwrap_or("");

    // OpenCode v2.3.2 rejects these with "Only stdio and HTTP MCP servers are
    // supported", so filter them out rather than failing the whole session.
    if ty == "sse" || ty == "acp" { return None; }

    // `remote` is OpenCode v2's name for the HTTP transport; ACP calls it http.
    if ty == "http" || ty == "remote" {
        let url = e.get("url").and_then(Value::as_str)?;
        if url.is_empty() { return None; }
        // ACP requires `headers` even when empty.
        let mut out = serde_json::json!({ "name": name, "type": "http", "url": url, "headers": [] });
        if let Some(h) = mcp_pairs(e.get("headers")) {
            out.as_object_mut()?.insert("headers".into(), h);
        }
        return Some(out);
    }

    // stdio: absent type (legacy), "local" (OpenCode schema) or "stdio" (ACP form).
    if !ty.is_empty() && ty != "local" && ty != "stdio" { return None; }
    let (command, args): (String, Vec<Value>) = match e.get("command") {
        Some(Value::String(s)) => (
            s.clone(),
            match e.get("args") {
                Some(Value::Array(a)) => a.clone(),
                _ => Vec::new(),
            },
        ),
        // OpenCode v2 packs the executable and its arguments into one array.
        Some(Value::Array(a)) => (
            a.first().and_then(Value::as_str)?.to_string(),
            a.iter().skip(1).cloned().collect(),
        ),
        _ => return None,
    };
    if command.is_empty() { return None; }
    // ACP requires `args` and `env` even when empty.
    let mut out = serde_json::json!({ "name": name, "command": command, "args": [], "env": [] });
    let obj = out.as_object_mut()?;
    if !args.is_empty() {
        obj.insert("args".into(), Value::Array(args));
    }
    if let Some(env) = mcp_pairs(e.get("env").or_else(|| e.get("environment"))) {
        obj.insert("env".into(), env);
    }
    Some(out)
}

/// Discover the OpenCode MCP config and translate it into ACP `McpServer`
/// objects for the `mcpServers` parameter of session/new, session/resume and
/// session/fork. OpenCode v2.3.2 only accepts stdio and HTTP servers over ACP;
/// `sse`/`acp` entries are skipped so they cannot reject the session.
///
/// Read-only (config files + environment only). Any read/parse failure yields
/// an empty vec, so a broken config can never stop the harness from starting.
pub fn mcp_servers() -> Vec<Value> {
    let home = std::env::var("HOME").unwrap_or_default();
    let xdg = std::env::var("XDG_CONFIG_HOME").unwrap_or_default();
    let session = std::env::var("SESSION_DIR").unwrap_or_default();

    // Harness.qml sets XDG_CONFIG_HOME=$SESSION_DIR/config, so the first two
    // bases are normally the same scoped config; list both so a standalone
    // harness still finds it, then fall back to the global config under HOME.
    let mut bases: Vec<PathBuf> = Vec::new();
    if !xdg.is_empty() { bases.push(PathBuf::from(&xdg)); }
    if !session.is_empty() { bases.push(Path::new(&session).join("config")); }
    if !home.is_empty() { bases.push(Path::new(&home).join(".config")); }

    let mut root = None;
    for base in bases {
        let base = base.join("opencode");
        for name in ["opencode.jsonc", "opencode.json", "config.json"] {
            let path = base.join(name);
            let raw = match fs::read_to_string(&path) {
                Ok(r) => r,
                Err(_) => continue,
            };
            let v: Value = match serde_json::from_str(&clean_jsonc(&raw)) {
                Ok(v) => v,
                Err(_) => continue,
            };
            if v.is_object() {
                root = Some(v);
                break;
            }
        }
        if root.is_some() { break; }
    }
    let root = match root { Some(v) => v, None => return Vec::new() };

    let mcp = match root.get("mcp").and_then(Value::as_object) {
        Some(m) => m,
        None => return Vec::new(),
    };
    // OpenCode v2 uses `mcp.servers.<name>`; the deprecated flat form puts the
    // servers directly under `mcp`.
    let servers = mcp.get("servers").and_then(Value::as_object).unwrap_or(mcp);

    servers
        .iter()
        .filter_map(|(name, entry)| entry.as_object().and_then(|e| mcp_server(name, e)))
        .collect()
}
