// Quickshell Ipc interface

use std::cmp::Reverse;
use std::fs;
use std::io::{self, BufReader, BufWriter, Read, Write};
use std::os::unix::fs::MetadataExt;
use std::os::unix::net::UnixStream;
use std::path::{Path, PathBuf};
use std::process::ExitCode;
use std::thread::sleep;
use std::time::{Duration, SystemTime};

use anyhow::{bail, Context, Result};
use clap::{Parser, Subcommand};

const RETRIES: usize = 3;
const RETRY_DELAY: Duration = Duration::from_millis(200);

#[derive(Parser)]
#[command(about = "Call a Quickshell IPC function")]
struct Args {
    #[arg(long, global = true)]
    socket: Option<PathBuf>,
    #[arg(long, global = true)]
    pid: Option<PathBuf>,
    #[arg(long, global = true)]
    id: Option<PathBuf>,
    #[arg(short = 'c', long, global = true)]
    config: Option<PathBuf>,
    #[arg(long, global = true)]
    path: Option<PathBuf>,
    #[arg(long, default_value_t = 2000, global = true)]
    timeout: u64,

    #[command(subcommand)]
    command: Verb,
}

#[derive(Subcommand)]
enum Verb {
    Call {
        target: String,
        function: String,
        args: Vec<String>,
    },
}

fn write_qstring(writer: &mut impl Write, text: &str) -> io::Result<()> {
    let bytes: Vec<u8> = text.encode_utf16().flat_map(u16::to_be_bytes).collect();
    writer.write_all(&(bytes.len() as u32).to_be_bytes())?;
    writer.write_all(&bytes)
}

fn read_qstring(reader: &mut impl Read) -> io::Result<String> {
    let mut length = [0; 4];
    reader.read_exact(&mut length)?;
    let length = u32::from_be_bytes(length);
    if length == u32::MAX {
        return Ok(String::new());
    }
    if length > 1 << 20 || length % 2 != 0 {
        return Err(io::Error::other(format!("bad QString length {length}")));
    }
    let mut bytes = vec![0; length as usize];
    reader.read_exact(&mut bytes)?;
    Ok(String::from_utf16_lossy(
        &bytes
            .chunks_exact(2)
            .map(|pair| u16::from_be_bytes([pair[0], pair[1]]))
            .collect::<Vec<_>>(),
    ))
}

#[derive(Debug)]
enum Response {
    Completed(Option<String>),
    NotReady,
    TargetNotFound,
    FunctionNotFound,
    ArgumentMismatch,
    Unknown(u8),
}

impl Response {
    fn from_byte(index: u8, reader: &mut impl Read) -> Result<Self> {
        Ok(match index {
            5 => {
                let mut void = [0; 1];
                reader.read_exact(&mut void)?;
                Self::Completed((void[0] == 0).then(|| read_qstring(reader)).transpose()?)
            }
            1 => Self::NotReady,
            2 => Self::TargetNotFound,
            3 => Self::FunctionNotFound,
            4 => Self::ArgumentMismatch,
            other => Self::Unknown(other),
        })
    }

    fn code(&self) -> u8 {
        match self {
            Self::Completed(_) => 0,
            Self::NotReady => 1,
            Self::TargetNotFound => 2,
            Self::FunctionNotFound => 3,
            Self::ArgumentMismatch => 4,
            Self::Unknown(_) => 1,
        }
    }

    fn message(&self, target: &str, function: &str) -> String {
        match self {
            Self::NotReady => "IPC not ready".into(),
            Self::TargetNotFound => format!("Target not found: {target}"),
            Self::FunctionNotFound => format!("Function not found: {target} {function}"),
            Self::ArgumentMismatch => format!("Argument mismatch calling {target} {function}"),
            Self::Unknown(n) => format!("unexpected response index {n}"),
            Self::Completed(_) => String::new(),
        }
    }
}

struct Client {
    reader: BufReader<UnixStream>,
    writer: BufWriter<UnixStream>,
}

impl Client {
    fn connect(socket: &Path, timeout: Duration) -> Result<Self> {
        let stream = UnixStream::connect(socket)
            .with_context(|| format!("connecting to {}", socket.display()))?;
        stream.set_read_timeout(Some(timeout))?;
        stream.set_write_timeout(Some(timeout))?;
        Ok(Self {
            reader: BufReader::new(stream.try_clone()?),
            writer: BufWriter::new(stream),
        })
    }

    fn call(&mut self, target: &str, function: &str, args: &[String]) -> Result<Response> {
        self.writer.write_all(&[3])?;
        write_qstring(&mut self.writer, target)?;
        write_qstring(&mut self.writer, function)?;
        self.writer.write_all(&(args.len() as u32).to_be_bytes())?;
        for arg in args {
            write_qstring(&mut self.writer, arg)?;
        }
        self.writer.flush()?;

        let mut index = [0; 1];
        self.reader.read_exact(&mut index)?;
        Response::from_byte(index[0], &mut self.reader)
    }
}

fn runtime_dir() -> PathBuf {
    if let Some(dir) = dirs::runtime_dir() {
        return dir.join("quickshell");
    }
    let uid = fs::metadata("/proc/self").map(|m| m.uid()).unwrap_or(0);
    PathBuf::from(format!("/run/user/{uid}/quickshell"))
}

fn candidates(args: &Args) -> Vec<PathBuf> {
    if let Some(socket) = &args.socket {
        return vec![socket.clone()];
    }
    let root = runtime_dir();
    if let Some(pid) = &args.pid {
        return vec![root.join("by-pid").join(pid).join("ipc.sock")];
    }

    let by_id = root.join("by-id");
    let Ok(entries) = fs::read_dir(&by_id) else {
        return vec![];
    };
    let names: Vec<_> = entries
        .flatten()
        .filter_map(|entry| entry.file_name().into_string().ok())
        .collect();

    if let Some(id) = &args.id {
        let id = id.to_string_lossy();
        return names
            .into_iter()
            .filter(|name| name.contains(id.as_ref()))
            .map(|name| by_id.join(name).join("ipc.sock"))
            .collect();
    }

    let mut sockets: Vec<(SystemTime, PathBuf)> = names
        .into_iter()
        .filter_map(|name| {
            let socket = by_id.join(name).join("ipc.sock");
            Some((fs::metadata(&socket).ok()?.modified().ok()?, socket))
        })
        .collect();
    sockets.sort_by_key(|(modified, _)| Reverse(*modified));
    sockets.into_iter().map(|(_, socket)| socket).collect()
}

fn run(args: Args) -> Result<u8> {
    let Verb::Call {
        target,
        function,
        args: call_args,
    } = &args.command;
    let timeout = Duration::from_millis(args.timeout);
    let pinned = args.socket.is_some() || args.pid.is_some() || args.id.is_some();
    let mut answered = false;

    for attempt in 0..RETRIES {
        if attempt > 0 {
            sleep(RETRY_DELAY);
        }
        for socket in candidates(&args) {
            let Ok(mut client) = Client::connect(&socket, timeout) else {
                continue;
            };
            let Ok(response) = client.call(target, function, call_args) else {
                continue;
            };
            answered = true;
            let code = response.code();
            if code == 2 && !pinned {
                continue;
            }
            match response {
                Response::Completed(Some(value)) => println!("{value}"),
                Response::Completed(None) => {}
                other => eprintln!("ipc: {}", other.message(target, function)),
            }
            return Ok(code);
        }
        if answered {
            break;
        }
    }
    if answered {
        bail!("target not found: {target}");
    }

    bail!("no running Quickshell IPC instance found")
}

fn main() -> ExitCode {
    match run(Args::parse()) {
        Ok(code) => ExitCode::from(code),
        Err(error) => {
            eprintln!("ipc: {error:#}");
            ExitCode::from(1)
        }
    }
}
