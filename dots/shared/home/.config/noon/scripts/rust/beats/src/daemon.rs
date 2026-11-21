//! Beats daemon lifecycle, command dispatch and lyrics maintenance.

use anyhow::{anyhow, Result};
use std::fs::{self, OpenOptions};
use std::os::unix::process::CommandExt;
use std::panic::{catch_unwind, AssertUnwindSafe};
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};

use super::{config, lyrics, models, player::Player, store};

static SHUTDOWN: AtomicBool = AtomicBool::new(false);

extern "C" fn on_signal(_: libc::c_int) {
    SHUTDOWN.store(true, Ordering::SeqCst);
}

struct LyricsState {
    file: String,
    title: String,
    gen: u64,
}

struct PreviewState {
    child: Option<(u32, Child)>,
    paused_main: bool,
}

struct Daemon {
    player: Arc<Player>,
    music_dir: String,
    lyrics: Mutex<LyricsState>,
    preview: Mutex<PreviewState>,
}

pub fn live_pid() -> Option<i32> {
    let path = store::pid_path();
    let text = fs::read_to_string(&path).ok()?;
    for field in text.split_whitespace() {
        if let Ok(pid) = field.parse::<i32>() {
            if pid > 0 && pid_alive(pid) {
                return Some(pid);
            }
        }
    }
    let _ = fs::remove_file(&path);
    None
}

fn pid_alive(pid: i32) -> bool {
    let ret = unsafe { libc::kill(pid, 0) };
    ret == 0 || (ret < 0 && std::io::Error::last_os_error().raw_os_error() == Some(libc::EPERM))
}

pub fn serve() -> Result<()> {
    let music_dir = config::music_dir_or_fail();
    let player = Player::new(&music_dir)?;
    let prune_dir = music_dir.clone();
    thread::spawn(move || {
        if let Err(e) = lyrics::prune_orphans(&prune_dir) {
            eprintln!("beats: prune: {e}");
        }
    });
    let mpris = match super::mpris::Mpris::start(Arc::clone(&player), music_dir.clone()) {
        Ok(m) => {
            println!("beats → mpris");
            Some(m)
        }
        Err(e) => {
            eprintln!("beats: mpris: {e}");
            None
        }
    };
    let pid_path = store::pid_path();
    if let Some(parent) = pid_path.parent() {
        fs::create_dir_all(parent)?;
    }
    fs::write(&pid_path, format!("{}\n", std::process::id()))?;

    unsafe {
        libc::signal(libc::SIGINT, on_signal as *const () as usize);
        libc::signal(libc::SIGTERM, on_signal as *const () as usize);
    }

    let d = Arc::new(Daemon {
        player,
        music_dir,
        lyrics: Mutex::new(LyricsState {
            file: String::new(),
            title: String::new(),
            gen: 0,
        }),
        preview: Mutex::new(PreviewState {
            child: None,
            paused_main: false,
        }),
    });

    let cmd_thread = {
        let d = Arc::clone(&d);
        thread::Builder::new()
            .name("beats-cmds".into())
            .spawn(move || cmd_loop(d))?
    };
    let lyr_thread = {
        let d = Arc::clone(&d);
        thread::Builder::new()
            .name("beats-lyrics".into())
            .spawn(move || lyrics_loop(d))?
    };

    while !SHUTDOWN.load(Ordering::SeqCst) {
        thread::sleep(Duration::from_millis(100));
    }
    let _ = cmd_thread.join();
    let _ = lyr_thread.join();

    d.stop_preview(false);
    if let Some(m) = mpris {
        m.close();
    }
    d.player.terminate();
    let _ = fs::remove_file(&pid_path);
    Ok(())
}

pub fn init() -> Result<()> {
    if live_pid().is_some() {
        eprintln!("beats daemon already running.");
        return Ok(());
    }
    eprintln!("Starting beats daemon...");
    let log_path = store::log_path();
    if let Some(parent) = log_path.parent() {
        fs::create_dir_all(parent)?;
    }
    let log = OpenOptions::new()
        .append(true)
        .create(true)
        .write(true)
        .open(&log_path)?;
    let err_log = log.try_clone()?;
    let exe = std::env::current_exe()?;
    let mut child = unsafe {
        Command::new(exe)
            .arg("serve")
            .stdin(Stdio::null())
            .stdout(Stdio::from(log))
            .stderr(Stdio::from(err_log))
            .pre_exec(|| {
                libc::setsid();
                Ok(())
            })
            .spawn()?
    };
    // why: the detached child outlives its parent, so do not wait for it here.
    let _ = child.try_wait();

    let deadline = Instant::now() + Duration::from_secs(5);
    while Instant::now() < deadline {
        if live_pid().is_some() {
            eprintln!("daemon ready.");
            return Ok(());
        }
        thread::sleep(Duration::from_millis(100));
    }
    Err(anyhow!("failed to start daemon."))
}

pub fn kill() -> Result<()> {
    if let Ok(text) = fs::read_to_string(store::pid_path()) {
        for field in text.split_whitespace() {
            if let Ok(pid) = field.parse::<i32>() {
                if pid > 0 {
                    unsafe {
                        libc::kill(pid, libc::SIGKILL);
                    }
                }
            }
        }
        let _ = fs::remove_file(store::pid_path());
    }
    let _ = Command::new("pkill")
        .args(["-f", "--title=beats-preview"])
        .status();
    thread::sleep(Duration::from_secs(1));
    eprintln!("All stopped.");
    Ok(())
}

fn cmd_loop(d: Arc<Daemon>) {
    loop {
        if SHUTDOWN.load(Ordering::SeqCst) {
            return;
        }
        thread::sleep(Duration::from_millis(100));
        let cmd = match store::consume_cmd(&d.music_dir) {
            Ok(Some(cmd)) => cmd,
            Ok(None) => continue,
            Err(e) => {
                eprintln!("beats: {e}");
                continue;
            }
        };
        if cmd.command == "preview" {
            d.handle_preview(&cmd);
            continue;
        }
        let name = cmd.command.clone();
        let result = catch_unwind(AssertUnwindSafe(|| d.exec(&cmd)));
        if let Err(panic) = result {
            let msg = panic
                .downcast_ref::<String>()
                .map(String::as_str)
                .or_else(|| panic.downcast_ref::<&str>().copied())
                .unwrap_or("unknown panic");
            eprintln!("beats: {name} failed: {msg}");
        }
    }
}

fn s(v: Option<&serde_json::Value>) -> String {
    match v {
        Some(serde_json::Value::String(x)) => x.clone(),
        Some(serde_json::Value::Number(x)) => x.to_string(),
        _ => String::new(),
    }
}

fn strings(v: Option<&serde_json::Value>) -> Vec<String> {
    match v {
        Some(serde_json::Value::Array(items)) => items
            .iter()
            .filter_map(|x| match x {
                serde_json::Value::String(t) => Some(t.clone()),
                serde_json::Value::Number(n) => Some(n.to_string()),
                _ => None,
            })
            .collect(),
        Some(other) => {
            let one = s(Some(other));
            if one.is_empty() {
                Vec::new()
            } else {
                vec![one]
            }
        }
        None => Vec::new(),
    }
}

fn f64_arg(v: Option<&serde_json::Value>) -> f64 {
    match v {
        Some(serde_json::Value::Number(x)) => x.as_f64().unwrap_or(0.0),
        Some(serde_json::Value::String(x)) => x.trim().parse().unwrap_or(0.0),
        _ => 0.0,
    }
}

fn i64_arg(v: Option<&serde_json::Value>) -> i64 {
    match v {
        Some(serde_json::Value::Number(x)) => x
            .as_i64()
            .or_else(|| x.as_f64().map(|f| f as i64))
            .unwrap_or(0),
        Some(serde_json::Value::String(x)) => x
            .trim()
            .parse::<i64>()
            .or_else(|_| x.trim().parse::<f64>().map(|f| f as i64))
            .unwrap_or(0),
        _ => 0,
    }
}

fn bool_arg(v: Option<&serde_json::Value>) -> bool {
    match v {
        Some(serde_json::Value::Bool(b)) => *b,
        Some(serde_json::Value::Number(x)) => x.as_f64().unwrap_or(0.0) != 0.0,
        Some(serde_json::Value::String(x)) => !x.is_empty(),
        _ => false,
    }
}

impl Daemon {
    fn exec(&self, cmd: &models::Command) {
        let a = cmd.a.as_ref();
        let p = &self.player;
        match cmd.command.as_str() {
            "playByName" => {
                self.stop_preview(true);
                p.play_by_name(&s(a));
            }
            "playFile" => {
                self.stop_preview(true);
                p.play_file(&s(a));
            }
            "playFiles" => {
                self.stop_preview(true);
                p.play_files(&strings(a));
            }
            "playUrl" => {
                self.stop_preview(true);
                p.play_url(&s(a));
            }
            "buildPlaylist" => {
                self.stop_preview(true);
                p.build_playlist(&s(a));
            }
            "playPause" => p.play_pause(),
            "pause" => p.pause(true),
            "resume" => p.pause(false),
            "next" => {
                self.stop_preview(true);
                p.next();
            }
            "prev" => {
                self.stop_preview(true);
                p.prev();
            }
            "stop" => p.stop(),
            "previewStop" => self.stop_preview(true),
            "seekBy" => p.seek(f64_arg(a), true),
            "seekTo" => p.seek(f64_arg(a), false),
            "setVolume" => p.set_volume(i64_arg(a)),
            "setRepeat" => p.set_repeat(bool_arg(a)),
            "refreshConfig" => p.refresh_config(),
            "lyricsRefetch" => self.reset_lyrics_key(),
            other => eprintln!("beats: unknown command '{other}'"),
        }
    }

    fn reset_lyrics_key(&self) {
        let mut state = self.lyrics.lock().unwrap();
        state.file.clear();
        state.title.clear();
        state.gen += 1;
    }

    fn handle_preview(self: &Arc<Self>, cmd: &models::Command) {
        let url = s(cmd.a.as_ref());
        if !url.is_empty() {
            self.start_preview(&url);
        }
    }

    fn start_preview(self: &Arc<Self>, url: &str) {
        if Command::new("sh")
            .args(["-c", "command -v mpv"])
            .stdout(Stdio::null())
            .stderr(Stdio::null())
            .status()
            .map(|st| !st.success())
            .unwrap_or(true)
        {
            eprintln!("beats: preview: mpv not found");
            return;
        }
        let mut preview = self.preview.lock().unwrap();
        self.stop_preview_locked(&mut preview, false);
        self.player.pause(true);
        preview.paused_main = true;
        let Ok(child) = Command::new("mpv")
            .args(["--no-video", "--title=beats-preview", url])
            .spawn()
        else {
            preview.paused_main = false;
            self.player.pause(false);
            return;
        };
        let id = child.id();
        preview.child = Some((id, child));
        drop(preview);

        let d = Arc::clone(self);
        thread::spawn(move || {
            let mut preview = d.preview.lock().unwrap();
            let Some((cid, child)) = preview.child.as_mut() else {
                return;
            };
            if *cid != id {
                return;
            }
            let _ = child.wait();
            preview.child = None;
            if preview.paused_main {
                preview.paused_main = false;
                d.player.pause(false);
            }
        });
    }

    fn stop_preview_locked(&self, preview: &mut PreviewState, resume: bool) {
        if let Some((_, child)) = preview.child.as_mut() {
            let _ = child.kill();
            let _ = child.wait();
            preview.child = None;
        }
        if resume && preview.paused_main {
            preview.paused_main = false;
            self.player.pause(false);
        }
    }

    fn stop_preview(&self, resume: bool) {
        let mut preview = self.preview.lock().unwrap();
        self.stop_preview_locked(&mut preview, resume);
    }
}

fn lyrics_loop(d: Arc<Daemon>) {
    loop {
        if SHUTDOWN.load(Ordering::SeqCst) {
            return;
        }
        thread::sleep(Duration::from_millis(500));
        d.lyrics_tick();
    }
}

fn is_remote(file: &str) -> bool {
    file.starts_with("http://") || file.starts_with("https://") || file.starts_with("ytdl://")
}

impl Daemon {
    fn lyrics_tick(self: &Arc<Self>) {
        let snap = self.player.snapshot();
        let file = self.player.current_file();
        let (gen, title, artist, duration) = {
            let mut state = self.lyrics.lock().unwrap();
            if snap.state == models::STATE_STOP {
                return;
            }
            if file.is_empty() || (file == state.file && snap.title == state.title) {
                return;
            }
            state.file = file.clone();
            state.title = snap.title.clone();
            state.gen += 1;
            (
                state.gen,
                snap.title.clone(),
                snap.artist.clone(),
                snap.duration,
            )
        };
        let blank = models::LyricState {
            title: title.clone(),
            artist: artist.clone(),
            text: String::new(),
        };
        if let Err(e) = store::write_json(&store::lyrics_path(&self.music_dir), &blank) {
            eprintln!("beats: lyrics: {e}");
        }
        if is_remote(&file) {
            return;
        }
        let d = Arc::clone(self);
        let dir = self.music_dir.clone();
        let fetch_file = file.clone();
        thread::spawn(move || {
            let text = lyrics::get_lyrics(&title, &artist, &dir, &fetch_file, duration);
            if text.is_empty() {
                return;
            }
            let state = d.lyrics.lock().unwrap();
            if gen != state.gen {
                return;
            }
            let final_state = models::LyricState {
                title: title.clone(),
                artist: artist.clone(),
                text,
            };
            if let Err(e) = store::write_json(&store::lyrics_path(&dir), &final_state) {
                eprintln!("beats: lyrics: {e}");
                return;
            }
        });
    }
}
