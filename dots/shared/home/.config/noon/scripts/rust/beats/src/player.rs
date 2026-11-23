//! libmpv-backed playback engine for beats.

use anyhow::{anyhow, Result};
use libmpv::events::{Event, EventContext, PropertyData};
use libmpv::{mpv_end_file_reason, Format, Mpv};
use std::collections::HashMap;
use std::ffi::CString;
use std::path::Path;
use std::ptr;
use std::sync::atomic::{AtomicBool, Ordering};
use std::sync::{mpsc, Arc, Condvar, Mutex, RwLock};
use std::thread;

const OBS_PLAYLIST: u64 = 1;
const OBS_POS: u64 = 2;
const OBS_IDLE: u64 = 3;
const OBS_PAUSE: u64 = 4;
const OBS_META: u64 = 5;
const OBS_TIME: u64 = 6;
const OBS_VOLUME: u64 = 7;
const OBS_SPEED: u64 = 8;
const OBS_LOOP_PLAYLIST: u64 = 9;
const OBS_LOOP_FILE: u64 = 10;
const OBS_DURATION: u64 = 11;

pub struct ChangeSignal {
    gen: Mutex<u64>,
    cv: Condvar,
}

impl ChangeSignal {
    pub fn wait(&self, seen: u64) -> u64 {
        let mut gen = self.gen.lock().unwrap();
        while *gen == seen {
            gen = self.cv.wait(gen).unwrap();
        }
        *gen
    }

    pub fn notify(&self) {
        let mut gen = self.gen.lock().unwrap();
        *gen += 1;
        self.cv.notify_all();
    }
}

#[derive(Default)]
struct State {
    playlist: Vec<String>,
    pos: i64,
    idle: bool,
    paused: bool,
    meta: HashMap<String, String>,
    time_pos: f64,
    volume: f64,
    speed: f64,
    loop_playlist: bool,
    loop_file: bool,
    duration: f64,
}

pub struct Player {
    mp: Arc<Mpv>,
    st: RwLock<State>,
    music_dir: RwLock<String>,
    shuffle: AtomicBool,
    hist: Mutex<Vec<usize>>,
    closed: AtomicBool,
    change: Arc<ChangeSignal>,
}

fn new_handle(null_audio: bool) -> Result<Arc<Mpv>> {
    let mp = Mpv::with_initializer(|init| {
        init.set_property("ytdl", "yes")?;
        init.set_property("vo", "null")?;
        init.set_property("input-default-bindings", "no")?;
        init.set_property("input-vo-keyboard", "no")?;
        init.set_property("keep-open", "always")?;
        if null_audio {
            init.set_property("ao", "null")?;
        }
        Ok(())
    })
    .map_err(|e| anyhow!("mpv init: {e}"))?;
    Ok(Arc::new(mp))
}

fn is_remote(s: &str) -> bool {
    s.starts_with("http://") || s.starts_with("https://") || s.starts_with("ytdl://")
}

fn rel_path(dir: &str, abs: &str) -> String {
    let base = Path::new(dir);
    let target = Path::new(abs);
    if let Ok(rest) = target.strip_prefix(base) {
        return rest.to_string_lossy().replace('\\', "/");
    }
    let b: Vec<_> = base.components().collect();
    let t: Vec<_> = target.components().collect();
    let mut common = 0;
    while common < b.len() && common < t.len() && b[common] == t[common] {
        common += 1;
    }
    let mut parts: Vec<String> = Vec::new();
    for _ in common..b.len() {
        parts.push("..".into());
    }
    for c in &t[common..] {
        parts.push(c.as_os_str().to_string_lossy().into_owned());
    }
    parts.join("/")
}

fn node_value(n: &libmpv::MpvNode) -> libmpv::MpvNodeValue<'_> {
    n.value().unwrap_or(libmpv::MpvNodeValue::None)
}

fn node_f64(n: &libmpv::MpvNode) -> f64 {
    match node_value(n) {
        libmpv::MpvNodeValue::Double(f) => f,
        libmpv::MpvNodeValue::Int64(i) => i as f64,
        libmpv::MpvNodeValue::Flag(b) => u8::from(b) as f64,
        libmpv::MpvNodeValue::String(s) => s.trim().parse().unwrap_or(0.0),
        _ => 0.0,
    }
}

fn node_i64(n: &libmpv::MpvNode) -> i64 {
    match node_value(n) {
        libmpv::MpvNodeValue::Int64(i) => i,
        libmpv::MpvNodeValue::Double(f) => f as i64,
        libmpv::MpvNodeValue::String(s) => s.trim().parse().unwrap_or(-1),
        _ => -1,
    }
}

fn node_bool(n: &libmpv::MpvNode) -> bool {
    match node_value(n) {
        libmpv::MpvNodeValue::Flag(b) => b,
        libmpv::MpvNodeValue::Int64(i) => i != 0,
        libmpv::MpvNodeValue::Double(f) => f != 0.0,
        libmpv::MpvNodeValue::String(s) => {
            matches!(s.trim().to_ascii_lowercase().as_str(), "yes" | "true" | "1")
        }
        _ => false,
    }
}

fn p_f64(v: &PropertyData<'_>) -> f64 {
    match v {
        PropertyData::Double(f) => *f,
        PropertyData::Int64(i) => *i as f64,
        PropertyData::Flag(b) => u8::from(*b) as f64,
        PropertyData::Str(s) | PropertyData::OsdStr(s) => s.trim().parse().unwrap_or(0.0),
        PropertyData::Node(n) => node_f64(n),
    }
}

fn p_i64(v: &PropertyData<'_>) -> i64 {
    match v {
        PropertyData::Int64(i) => *i,
        PropertyData::Double(f) => *f as i64,
        PropertyData::Node(n) => node_i64(n),
        _ => -1,
    }
}

fn p_bool(v: &PropertyData<'_>) -> bool {
    match v {
        PropertyData::Flag(b) => *b,
        PropertyData::Int64(i) => *i != 0,
        PropertyData::Double(f) => *f != 0.0,
        PropertyData::Str(s) | PropertyData::OsdStr(s) => {
            matches!(s.trim().to_ascii_lowercase().as_str(), "yes" | "true" | "1")
        }
        PropertyData::Node(n) => node_bool(n),
    }
}

fn p_loop(v: &PropertyData<'_>) -> bool {
    match v {
        PropertyData::Str(s) | PropertyData::OsdStr(s) => !matches!(
            s.trim().to_ascii_lowercase().as_str(),
            "" | "no" | "0" | "false" | "off"
        ),
        PropertyData::Node(n) => match n.value() {
            Ok(libmpv::MpvNodeValue::String(s)) => !matches!(
                s.trim().to_ascii_lowercase().as_str(),
                "" | "no" | "0" | "false" | "off"
            ),
            Ok(libmpv::MpvNodeValue::Flag(b)) => b,
            Ok(libmpv::MpvNodeValue::Int64(i)) => i != 0,
            Ok(libmpv::MpvNodeValue::Double(f)) => f != 0.0,
            _ => false,
        },
        _ => p_bool(v),
    }
}

fn node_string(node: &libmpv::MpvNode) -> Option<String> {
    match node.value().ok()? {
        libmpv::MpvNodeValue::String(s) => Some(s.to_owned()),
        libmpv::MpvNodeValue::Flag(b) => Some(b.to_string()),
        libmpv::MpvNodeValue::Int64(i) => Some(i.to_string()),
        libmpv::MpvNodeValue::Double(f) => Some(f.to_string()),
        _ => None,
    }
}

fn p_playlist(v: &PropertyData<'_>) -> Vec<String> {
    let PropertyData::Node(node) = v else {
        return Vec::new();
    };
    let Some(items) = node.to_array() else {
        return Vec::new();
    };
    items
        .filter_map(|item| {
            let mut map = item.to_map()?;
            map.find(|(k, _)| *k == "filename")
                .and_then(|(_, val)| val.to_str().map(str::to_owned))
        })
        .collect()
}

fn p_meta(v: &PropertyData<'_>) -> HashMap<String, String> {
    let PropertyData::Node(node) = v else {
        return HashMap::new();
    };
    let Some(map) = node.to_map() else {
        return HashMap::new();
    };
    map.map(|(k, v)| (k.to_owned(), node_string(&v).unwrap_or_default()))
        .collect()
}

impl Player {
    pub fn new(dir: &str) -> Result<Arc<Self>> {
        let mp = new_handle(false).or_else(|_| new_handle(true))?;
        let mut st = State::default();
        st.pos = -1;
        st.idle = true;
        st.speed = 1.0;
        let player = Arc::new(Self {
            mp,
            st: RwLock::new(st),
            music_dir: RwLock::new(expand_home(dir)),
            shuffle: AtomicBool::new(false),
            hist: Mutex::new(Vec::new()),
            closed: AtomicBool::new(false),
            change: Arc::new(ChangeSignal {
                gen: Mutex::new(0),
                cv: Condvar::new(),
            }),
        });
        let (tx, rx) = mpsc::sync_channel(1);
        let p = Arc::clone(&player);
        thread::Builder::new()
            .name("beats-mpv-events".into())
            .spawn(move || {
                let mut ctx = p.mp.create_event_context();
                let observed = observe_all(&mut ctx);
                let ok = observed.is_ok();
                let _ = tx.send(observed);
                if ok {
                    p.event_loop(ctx);
                }
            })?;
        rx.recv()
            .map_err(|_| anyhow!("mpv event thread failed"))??;
        Ok(player)
    }

    // mpv_command_string tokenizes on whitespace, which breaks paths with spaces.
    fn cmd(&self, name: &str, args: &[&str]) {
        let name_c = CString::new(name).unwrap_or_default();
        let arg_cs: Vec<CString> = args
            .iter()
            .map(|a| CString::new(*a).unwrap_or_default())
            .collect();
        let mut parts: Vec<*const std::os::raw::c_char> = Vec::with_capacity(arg_cs.len() + 2);
        parts.push(name_c.as_ptr());
        parts.extend(arg_cs.iter().map(|c| c.as_ptr()));
        parts.push(ptr::null());
        let rc = unsafe { libmpv_sys::mpv_command(self.mp.ctx.as_ptr(), parts.as_mut_ptr()) };
        if rc < 0 {
            eprintln!("beats: mpv {name}: error {rc}");
        }
    }

    fn play_pos(&self, pos: usize) {
        self.cmd("playlist-play-index", &[&pos.to_string()]);
    }

    fn event_loop(&self, mut ctx: EventContext<'_>) {
        loop {
            if self.closed.load(Ordering::Relaxed) {
                return;
            }
            match ctx.wait_event(0.1) {
                Some(Ok(Event::Shutdown)) => return,
                Some(Ok(Event::PropertyChange {
                    reply_userdata,
                    change,
                    ..
                })) => {
                    self.apply_prop(reply_userdata, &change);
                }
                Some(Ok(Event::EndFile(reason))) => {
                    if reason == mpv_end_file_reason::Eof {
                        self.on_eof();
                    }
                }
                _ => {}
            }
        }
    }

    pub fn apply_prop(&self, id: u64, change: &PropertyData<'_>) {
        let mut st = self.st.write().unwrap();
        match id {
            OBS_PLAYLIST => st.playlist = p_playlist(change),
            OBS_POS => st.pos = p_i64(change),
            OBS_IDLE => st.idle = p_bool(change),
            OBS_PAUSE => st.paused = p_bool(change),
            OBS_META => st.meta = p_meta(change),
            OBS_TIME => st.time_pos = p_f64(change),
            OBS_VOLUME => st.volume = p_f64(change),
            OBS_SPEED => {
                st.speed = p_f64(change);
                if st.speed == 0.0 {
                    st.speed = 1.0;
                }
            }
            OBS_LOOP_PLAYLIST => st.loop_playlist = p_loop(change),
            OBS_LOOP_FILE => st.loop_file = p_loop(change),
            OBS_DURATION => st.duration = p_f64(change),
            _ => return,
        }
        drop(st);
        self.change.notify();
    }

    pub fn change_signal(&self) -> Arc<ChangeSignal> {
        Arc::clone(&self.change)
    }

    pub fn on_eof(&self) {
        let loop_file = self.st.read().unwrap().loop_file;
        if !loop_file {
            self.next();
        }
    }

    pub fn snapshot(&self) -> crate::models::QueueState {
        let st = self.st.read().unwrap();
        let file = if !st.idle && st.pos >= 0 && (st.pos as usize) < st.playlist.len() {
            st.playlist[st.pos as usize].clone()
        } else {
            String::new()
        };
        let state = if file.is_empty() {
            crate::models::STATE_STOP
        } else if st.paused {
            crate::models::STATE_PAUSE
        } else {
            crate::models::STATE_PLAY
        };
        let title = st
            .meta
            .get("title")
            .filter(|s| !s.is_empty())
            .cloned()
            .unwrap_or_else(|| {
                if file.is_empty() {
                    String::new()
                } else {
                    Path::new(&file)
                        .file_name()
                        .map(|n| n.to_string_lossy().into_owned())
                        .unwrap_or_else(|| file.clone())
                }
            });
        crate::models::QueueState {
            pos: st.pos,
            state: state.into(),
            volume: st.volume.round() as i64,
            title,
            artist: st.meta.get("artist").cloned().unwrap_or_default(),
            album: st.meta.get("album").cloned().unwrap_or_default(),
            position: st.time_pos,
            duration: st.duration,
            repeat: st.loop_playlist,
            loop_track: st.loop_file,
        }
    }

    pub fn current_file(&self) -> String {
        let st = self.st.read().unwrap();
        if st.pos >= 0 && (st.pos as usize) < st.playlist.len() {
            self.rel(&st.playlist[st.pos as usize])
        } else {
            String::new()
        }
    }

    fn rel(&self, abs: &str) -> String {
        if abs.is_empty() || is_remote(abs) {
            return abs.to_owned();
        }
        rel_path(&self.music_dir.read().unwrap(), abs)
    }

    fn resolve(&self, s: &str) -> String {
        if s.is_empty() || is_remote(s) || Path::new(s).is_absolute() {
            return s.to_owned();
        }
        let guard = self.music_dir.read().unwrap();
        Path::new(guard.as_str())
            .join(s)
            .to_string_lossy()
            .into_owned()
    }

    fn replace_and_play(&self, paths: &[String]) {
        self.hist.lock().unwrap().clear();
        let mut first = true;
        for f in paths {
            self.cmd("loadfile", &[f, if first { "replace" } else { "append" }]);
            first = false;
        }
    }

    pub fn play_file(&self, file: &str) {
        self.replace_and_play(&[self.resolve(file)]);
    }

    pub fn play_files(&self, files: &[String]) {
        let resolved: Vec<String> = files.iter().map(|f| self.resolve(f)).collect();
        self.replace_and_play(&resolved);
    }

    pub fn play_url(&self, url: &str) {
        self.replace_and_play(&[url.to_owned()]);
    }

    pub fn play_by_name(&self, name: &str) {
        let lower = name.to_ascii_lowercase();
        let (playlist, dir) = {
            let st = self.st.read().unwrap();
            (st.playlist.clone(), self.music_dir.read().unwrap().clone())
        };
        if let Some(i) = playlist
            .iter()
            .position(|f| self.rel(f).to_ascii_lowercase().contains(&lower))
        {
            self.play_pos(i);
            return;
        }
        let Ok(index) = crate::library::track_index(&dir) else {
            return;
        };
        let mut matches: Vec<String> = if index.contains_key(name) {
            vec![name.to_owned()]
        } else {
            let mut m: Vec<String> = index
                .keys()
                .filter(|f| f.to_ascii_lowercase().contains(&lower))
                .cloned()
                .collect();
            m.sort();
            if m.is_empty() {
                m = index
                    .iter()
                    .filter(|(_, t)| t.title.to_ascii_lowercase().contains(&lower))
                    .map(|(f, _)| f.clone())
                    .collect();
                m.sort();
            }
            m
        };
        let Some(first) = matches.first().cloned() else {
            eprintln!("beats: Track not found: {name}");
            return;
        };
        let mut sorted: Vec<String> = index.keys().cloned().collect();
        sorted.sort();
        let at = sorted.binary_search(&first).unwrap_or(0);
        sorted.rotate_left(at);
        let resolved: Vec<String> = sorted.iter().map(|f| self.resolve(f)).collect();
        self.replace_and_play(&resolved);
        matches.clear();
    }

    pub fn build_playlist(&self, titles: &str) {
        let dir = self.music_dir.read().unwrap().clone();
        let Ok(index) = crate::library::track_index(&dir) else {
            return;
        };
        let mut by_title: HashMap<String, String> = HashMap::new();
        for (f, t) in index.iter() {
            by_title
                .entry(t.title.to_ascii_lowercase())
                .or_insert(f.clone());
        }
        let mut resolved = Vec::new();
        for part in titles.split(',') {
            let title = part.trim();
            if title.is_empty() {
                continue;
            }
            if let Some(f) = by_title.get(&title.to_ascii_lowercase()) {
                resolved.push(self.resolve(f));
            } else {
                eprintln!("beats: Track not found in library: {title}");
            }
        }
        if resolved.is_empty() {
            eprintln!("beats: No tracks resolved, aborting.");
            return;
        }
        self.replace_and_play(&resolved);
    }

    pub fn play_pause(&self) {
        if self.snapshot().state == crate::models::STATE_STOP {
            return;
        }
        let paused = self.st.read().unwrap().paused;
        self.pause(!paused);
    }

    pub fn play(&self) {
        let st = self.st.read().unwrap();
        if !st.idle && st.pos >= 0 && (st.pos as usize) < st.playlist.len() {
            drop(st);
            self.pause(false);
            return;
        }
        if st.playlist.is_empty() {
            return;
        }
        let pos = if st.pos < 0 || (st.pos as usize) >= st.playlist.len() {
            0
        } else {
            st.pos as usize
        };
        drop(st);
        self.play_pos(pos);
    }

    pub fn pause(&self, state: bool) {
        let _ = self.mp.set_property("pause", state);
    }

    pub fn stop(&self) {
        self.cmd("stop", &["keep-playlist"]);
    }

    pub fn seek(&self, seconds: f64, relative: bool) -> f64 {
        let (base, dur) = {
            let st = self.st.read().unwrap();
            (st.time_pos, st.duration)
        };
        let mut target = if relative { base + seconds } else { seconds };
        if dur > 0.0 {
            target = target.min((dur - 1.0).max(0.0));
        }
        if target < 0.0 {
            target = 0.0;
        }
        self.cmd("seek", &[&target.to_string(), "absolute", "keyframes"]);
        target
    }

    pub fn set_volume(&self, volume: i64) {
        let v = (volume.clamp(0, 100)) as f64;
        let _ = self.mp.set_property("volume", v);
    }

    pub fn set_rate(&self, rate: f64) {
        let _ = self.mp.set_property("speed", rate.clamp(0.01, 100.0));
    }

    pub fn set_repeat(&self, enabled: bool) {
        let _ = self.mp.set_property("loop-playlist", enabled);
    }

    pub fn set_loop_track(&self, enabled: bool) {
        let _ = self.mp.set_property("loop-file", enabled);
    }

    pub fn set_shuffle(&self, enabled: bool) {
        self.shuffle.store(enabled, Ordering::Relaxed);
        self.change.notify();
    }

    pub fn shuffle(&self) -> bool {
        self.shuffle.load(Ordering::Relaxed)
    }

    pub fn music_dir(&self) -> String {
        self.music_dir.read().unwrap().clone()
    }

    pub fn next(&self) {
        let st = self.st.read().unwrap();
        let len = st.playlist.len();
        if len == 0 {
            return;
        }
        if self.shuffle() {
            if st.pos >= 0 && (st.pos as usize) < len {
                let mut hist = self.hist.lock().unwrap();
                hist.push(st.pos as usize);
                if hist.len() > 128 {
                    hist.remove(0);
                }
            }
            drop(st);
            self.play_pos(rand::random_range(0..len));
            return;
        }
        let pos = st.pos;
        let wrap = pos >= len as i64 - 1 && !st.loop_playlist;
        drop(st);
        if wrap {
            self.play_pos(0);
        } else {
            self.cmd("playlist_next", &["weak"]);
        }
    }

    pub fn prev(&self) {
        if self.shuffle() {
            let pos = self.hist.lock().unwrap().pop();
            if let Some(pos) = pos {
                if pos < self.st.read().unwrap().playlist.len() {
                    self.play_pos(pos);
                    return;
                }
            }
        }
        self.cmd("playlist_prev", &["weak"]);
    }

    pub fn refresh_config(&self) {
        if let Ok(dir) = crate::config::music_dir() {
            if !dir.trim().is_empty() {
                *self.music_dir.write().unwrap() = dir;
            }
        }
    }

    pub fn terminate(&self) {
        if self.closed.swap(true, Ordering::Relaxed) {
            return;
        }
        let _ = self.mp.command("quit", &[]);
    }
}

fn expand_home(s: &str) -> String {
    if let Some(home) = std::env::var_os("HOME") {
        if s == "~" {
            return home.to_string_lossy().into_owned();
        }
        if let Some(rest) = s.strip_prefix("~/") {
            return Path::new(&home).join(rest).to_string_lossy().into_owned();
        }
    }
    s.to_owned()
}

fn observe_all(ctx: &mut EventContext<'_>) -> Result<()> {
    let props: [(u64, &str, Format); 11] = [
        (OBS_PLAYLIST, "playlist", Format::Node),
        (OBS_POS, "playlist-pos", Format::Node),
        (OBS_IDLE, "idle-active", Format::Node),
        (OBS_PAUSE, "pause", Format::Node),
        (OBS_META, "metadata", Format::Node),
        (OBS_TIME, "time-pos", Format::Node),
        (OBS_VOLUME, "volume", Format::Node),
        (OBS_SPEED, "speed", Format::Node),
        (OBS_LOOP_PLAYLIST, "loop-playlist", Format::Node),
        (OBS_LOOP_FILE, "loop-file", Format::Node),
        (OBS_DURATION, "duration", Format::Node),
    ];
    for (id, name, format) in props {
        ctx.observe_property(name, format, id)
            .map_err(|e| anyhow!("observe {name}: {e}"))?;
    }
    ctx.enable_event(libmpv::events::mpv_event_id::EndFile)
        .map_err(|e| anyhow!("enable EndFile event: {e}"))?;
    Ok(())
}
