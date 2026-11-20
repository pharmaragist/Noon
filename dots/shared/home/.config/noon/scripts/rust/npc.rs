use std::{
    cmp::Reverse,
    collections::HashMap,
    env, fs,
    io::{self, BufReader, Read, Write},
    os::unix::{fs::MetadataExt, net::UnixStream, process::CommandExt},
    path::{Path, PathBuf},
    process::{exit, Command},
    thread::sleep,
    time::Duration,
};

fn put(buf: &mut Vec<u8>, s: &str) {
    let bytes: Vec<u8> = s.encode_utf16().flat_map(u16::to_be_bytes).collect();
    buf.extend((bytes.len() as u32).to_be_bytes());
    buf.extend(bytes);
}

fn read<const N: usize>(r: &mut impl Read) -> io::Result<[u8; N]> {
    let mut buf = [0; N];
    r.read_exact(&mut buf)?;
    Ok(buf)
}

fn read_string(r: &mut impl Read) -> io::Result<String> {
    let len = u32::from_be_bytes(read(r)?);
    if len == u32::MAX {
        return Ok(String::new());
    }
    if len > 1 << 20 || len % 2 != 0 {
        return Err(io::Error::other(format!("bad QString length {len}")));
    }
    let mut bytes = vec![0; len as usize];
    r.read_exact(&mut bytes)?;
    let units: Vec<u16> = bytes.chunks_exact(2).map(|c| u16::from_be_bytes([c[0], c[1]])).collect();
    Ok(String::from_utf16_lossy(&units))
}

fn call(sock: &Path, target: &str, function: &str, args: &[String], timeout: Duration) -> io::Result<(String, i32)> {
    let mut conn = UnixStream::connect(sock)?;
    conn.set_read_timeout(Some(timeout))?;
    let mut req = vec![3];
    put(&mut req, target);
    put(&mut req, function);
    req.extend((args.len() as u32).to_be_bytes());
    args.iter().for_each(|a| put(&mut req, a));
    conn.write_all(&req)?;
    let mut r = BufReader::new(conn);
    Ok(match read::<1>(&mut r)?[0] {
        5 => (if read::<1>(&mut r)?[0] != 0 { String::new() } else { read_string(&mut r)? }, 0),
        1 => ("IPC not ready".into(), 1),
        2 => (format!("Target not found: {target}"), 2),
        3 => (format!("Function not found: {target} {function}"), 3),
        4 => (format!("Argument mismatch calling {target} {function}"), 4),
        n => (format!("unexpected response index {n}"), 1),
    })
}

fn candidates(sock: Option<&Path>, pid: Option<&str>, id: Option<&str>) -> Vec<PathBuf> {
    if let Some(sock) = sock {
        return vec![sock.into()];
    }
    let root = env::var_os("XDG_RUNTIME_DIR")
        .filter(|d| !d.is_empty())
        .map(PathBuf::from)
        .unwrap_or_else(|| format!("/run/user/{}", fs::metadata("/proc/self").map_or(0, |m| m.uid())).into())
        .join("quickshell");
    if let Some(pid) = pid {
        return vec![root.join("by-pid").join(pid).join("ipc.sock")];
    }
    let by_id = root.join("by-id");
    let Ok(entries) = fs::read_dir(&by_id) else { return vec![] };
    let names = entries.flatten().filter_map(|e| e.file_name().into_string().ok());
    if let Some(id) = id {
        let matched: Vec<_> = names.filter(|n| n.contains(id)).collect();
        return match matched.as_slice() {
            [only] => vec![by_id.join(only).join("ipc.sock")],
            _ => vec![],
        };
    }
    let mut socks: Vec<_> = names
        .filter_map(|n| {
            let path = by_id.join(n).join("ipc.sock");
            Some((fs::metadata(&path).ok()?.modified().ok()?, path))
        })
        .collect();
    socks.sort_by_key(|(modified, _)| Reverse(*modified));
    socks.into_iter().map(|(_, path)| path).collect()
}

fn usage() -> ! {
    eprintln!("usage: npc [--socket P] [--pid N] [--id S] [--config C] [--path P] [--timeout MS] call <target> <function> [args...]");
    exit(1)
}

fn main() {
    let mut flags: HashMap<String, String> = HashMap::new();
    let mut argv = env::args().skip(1);
    let mut rest = vec![];
    while let Some(a) = argv.next() {
        let name = a.trim_start_matches('-').to_owned();
        if a.starts_with('-') && ["socket", "pid", "id", "config", "c", "path", "timeout"].contains(&name.as_str()) {
            let Some(value) = argv.next() else { usage() };
            flags.insert(if name == "c" { "config".into() } else { name }, value);
        } else {
            rest.push(a);
            rest.extend(argv.by_ref());
        }
    }
    let [verb, target, function, args @ ..] = rest.as_slice() else { usage() };
    if verb != "call" || target.is_empty() || function.is_empty() {
        usage();
    }

    let get = |key: &str| flags.get(key).map(String::as_str);
    let (sock, pid, id) = (get("socket").map(Path::new), get("pid"), get("id"));
    let pinned = sock.is_some() || pid.is_some() || id.is_some();
    let timeout = Duration::from_millis(get("timeout").and_then(|t| t.parse().ok()).unwrap_or(2000));

    let mut answered = false;
    for attempt in 0..3 {
        if attempt > 0 {
            sleep(Duration::from_millis(200));
        }
        let socks = candidates(sock, pid, id);
        for s in &socks {
            let Ok((out, code)) = call(s, target, function, args, timeout) else { continue };
            answered = true;
            if code == 2 && !pinned {
                continue;
            }
            if !out.is_empty() {
                if code == 0 {
                    println!("{out}");
                } else {
                    eprintln!("ipc: {out}");
                }
            }
            exit(code);
        }
        if answered || socks.is_empty() {
            break;
        }
    }
    if answered {
        eprintln!("ipc: target not found: {target}");
        exit(2);
    }

    let mut qs = Command::new("qs");
    for (flag, key) in [("-c", "config"), ("-p", "path"), ("--pid", "pid"), ("--id", "id")] {
        if let Some(value) = get(key) {
            qs.arg(flag).arg(value);
        }
    }
    let err = qs.args(["ipc", "call"]).arg(target).arg(function).args(args).exec();
    eprintln!("ipc: no running instance and qs failed to start: {err}");
    exit(1);
}
