//! MPRIS D-Bus service for beats (root, player and properties interfaces).

use anyhow::Result;
use sha1::{Digest, Sha1};
use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::{AtomicBool, AtomicU64, Ordering};
use std::sync::Arc;
use std::thread;
use std::time::{Duration, Instant};

use zbus::fdo::{DBusProxy, RequestNameFlags, RequestNameReply};
use zbus::interface;
use zbus::object_server::SignalEmitter;
use zbus::wire::{ObjectPath, OwnedObjectPath, OwnedVariant, Variant};

use super::player::{clean, Player};

const BUS_NAME: &str = "org.mpris.MediaPlayer2.noon";
const PATH: &str = "/org/mpris/MediaPlayer2";
const PLAYER_IFACE: &str = "org.mpris.MediaPlayer2.Player";
const TRACK_PREFIX: &str = "/org/mpris/MediaPlayer2/Track/";
const TAKEN_NOTICE: &str = "MPRIS name org.mpris.MediaPlayer2.noon already taken; continuing.";
const MICROS: f64 = 1_000_000.0;
const POSITION_INTERVAL: Duration = Duration::from_millis(500);

fn bits(f: f64) -> u64 {
    f.to_bits()
}

fn from_bits(b: u64) -> f64 {
    f64::from_bits(b)
}

fn round3(f: f64) -> f64 {
    (f * 1000.0).round() / 1000.0
}

#[derive(Clone)]
struct Shared {
    player: Arc<Player>,
    music_dir: String,
    rate: Arc<AtomicU64>,
}

pub struct Mpris {
    _conn: zbus::Connection,
    closed: Arc<AtomicBool>,
    signal: Arc<crate::player::ChangeSignal>,
}

struct Root;

#[interface(name = "org.mpris.MediaPlayer2")]
impl Root {
    #[zbus(property)]
    fn identity(&self) -> &'static str {
        "beats"
    }
    #[zbus(property)]
    fn desktop_entry(&self) -> &'static str {
        "beats"
    }
    #[zbus(property)]
    fn supported_uri_schemes(&self) -> Vec<&'static str> {
        vec!["file", "http", "https"]
    }
    #[zbus(property)]
    fn supported_mime_types(&self) -> Vec<&'static str> {
        vec![]
    }
    #[zbus(property)]
    fn can_quit(&self) -> bool {
        false
    }
    #[zbus(property)]
    fn can_raise(&self) -> bool {
        false
    }
    #[zbus(property)]
    fn has_track_list(&self) -> bool {
        false
    }
    fn quit(&self) {}
    fn raise(&self) {}
}

struct MprisPlayer {
    shared: Shared,
}

fn variant<T: Into<Variant<'static>>>(v: T) -> OwnedVariant {
    OwnedVariant::try_from(v.into()).expect("variant value must be owned")
}

fn str_variant(s: &str) -> OwnedVariant {
    variant(s.to_owned())
}

fn obj_variant(s: &str) -> OwnedVariant {
    let path = ObjectPath::try_from(s.to_owned()).unwrap_or_else(|_| {
        ObjectPath::try_from("/org/mpris/MediaPlayer2/Track/0".to_owned())
            .expect("valid fallback path")
    });
    variant(path)
}

fn is_remote(file: &str) -> bool {
    file.starts_with("http://") || file.starts_with("https://") || file.starts_with("ytdl://")
}

fn cover_url(dir: &str, rel: &str) -> String {
    if rel.is_empty() {
        return String::new();
    }
    let Ok(index) = crate::library::track_index(dir) else {
        return String::new();
    };
    let Some(track) = index.get(rel) else {
        return String::new();
    };
    if track.cover.is_empty() {
        return String::new();
    }
    let full = if Path::new(&track.cover).is_absolute() {
        clean(Path::new(&track.cover))
    } else {
        clean(&Path::new(dir).join(&track.cover))
    };
    let base = clean(Path::new(dir));
    let Ok(rel_path) = full.strip_prefix(&base) else {
        return String::new();
    };
    if rel_path == Path::new("..") || rel_path.starts_with("..") {
        return String::new();
    }
    if !full.is_file() {
        return String::new();
    }
    format!("file://{}", full.to_string_lossy())
}

fn metadata(shared: &Shared) -> HashMap<String, OwnedVariant> {
    let snap = shared.player.snapshot();
    let mut map = HashMap::new();
    if snap.state == crate::models::STATE_STOP {
        return map;
    }
    let file = shared.player.current_file();
    if !snap.title.is_empty() {
        map.insert("xesam:title".into(), str_variant(&snap.title));
    }
    if !snap.artist.is_empty() {
        map.insert("xesam:artist".into(), variant(vec![snap.artist.clone()]));
    }
    if !snap.album.is_empty() {
        map.insert("xesam:album".into(), str_variant(&snap.album));
    }
    if snap.duration != 0.0 {
        map.insert(
            "mpris:length".into(),
            variant((snap.duration * MICROS) as i64),
        );
    }
    let src = if file.is_empty() {
        format!("{}\0{}\0{}", snap.title, snap.artist, snap.album)
    } else {
        file.clone()
    };
    let mut hash = Sha1::new();
    hash.update(src.as_bytes());
    let digest = hash.finalize();
    let hex: String = digest.iter().map(|b| format!("{b:02x}")).collect();
    map.insert(
        "mpris:trackid".into(),
        obj_variant(&format!("{TRACK_PREFIX}{hex}")),
    );
    if !file.is_empty() && !is_remote(&file) {
        if let Some(art) =
            Option::from(cover_url(&shared.music_dir, &file)).filter(|s| !s.is_empty())
        {
            map.insert("mpris:artUrl".into(), str_variant(&art));
        }
    }
    map
}

fn playback_status(shared: &Shared) -> &'static str {
    match shared.player.snapshot().state.as_str() {
        crate::models::STATE_PLAY => "Playing",
        crate::models::STATE_PAUSE => "Paused",
        _ => "Stopped",
    }
}

fn loop_status(snap: &crate::models::QueueState) -> &'static str {
    if snap.loop_track {
        "Track"
    } else if snap.repeat {
        "Playlist"
    } else {
        "None"
    }
}

fn changed_props(
    shared: &Shared,
    last_meta: &mut Option<HashMap<String, OwnedVariant>>,
) -> HashMap<&'static str, OwnedVariant> {
    let snap = shared.player.snapshot();
    let mut map = HashMap::new();
    map.insert("PlaybackStatus", str_variant(playback_status(shared)));
    map.insert("LoopStatus", str_variant(loop_status(&snap)));
    map.insert("Shuffle", variant(shared.player.shuffle()));
    map.insert(
        "Rate",
        variant(round3(from_bits(shared.rate.load(Ordering::Relaxed)))),
    );
    let meta = metadata(shared);
    if last_meta.as_ref() != Some(&meta) {
        map.insert("Metadata", variant(meta.clone()));
        *last_meta = Some(meta);
    }
    map.insert("Volume", variant(round3(snap.volume as f64 / 100.0)));
    map
}

#[interface(name = "org.mpris.MediaPlayer2.Player")]
impl MprisPlayer {
    fn next(&self) {
        self.shared.player.next();
    }
    fn previous(&self) {
        self.shared.player.prev();
    }
    fn pause(&self) {
        self.shared.player.pause(true);
    }
    fn play_pause(&self) {
        self.shared.player.play_pause();
    }
    fn stop(&self) {
        self.shared.player.stop();
    }
    fn play(&self) {
        self.shared.player.play();
    }
    async fn seek(
        &self,
        offset: i64,
        _track_id: OwnedObjectPath,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) {
        self.shared.player.seek(offset as f64 / MICROS, true);
        let pos = (self.shared.player.snapshot().position * MICROS) as i64;
        let _ = Self::seeked(&emitter, pos).await;
    }
    async fn set_position(
        &self,
        _track_id: OwnedObjectPath,
        position: i64,
        #[zbus(signal_emitter)] emitter: SignalEmitter<'_>,
    ) {
        self.shared.player.seek(position as f64 / MICROS, false);
        let pos = (self.shared.player.snapshot().position * MICROS) as i64;
        let _ = Self::seeked(&emitter, pos).await;
    }
    fn open_uri(&self, uri: &str) {
        if let Some(path) = uri.strip_prefix("file://") {
            let decoded = url::Url::parse(uri)
                .ok()
                .and_then(|u| u.to_file_path().ok())
                .unwrap_or_else(|| Path::new(path).to_path_buf());
            self.shared.player.play_file(&decoded.to_string_lossy());
        } else {
            self.shared.player.play_url(uri);
        }
    }

    #[zbus(property)]
    fn playback_status(&self) -> &'static str {
        playback_status(&self.shared)
    }
    #[zbus(property(emits_changed_signal = "false"))]
    fn loop_status(&self) -> &'static str {
        loop_status(&self.shared.player.snapshot())
    }
    #[zbus(property)]
    fn set_loop_status(&self, value: &str) {
        self.shared.player.set_loop_track(value == "Track");
        self.shared.player.set_repeat(value == "Playlist");
    }
    #[zbus(property(emits_changed_signal = "false"))]
    fn rate(&self) -> f64 {
        round3(from_bits(self.shared.rate.load(Ordering::Relaxed)))
    }
    #[zbus(property)]
    fn set_rate(&self, value: f64) {
        self.shared.player.set_rate(value);
        self.shared.rate.store(bits(value), Ordering::Relaxed);
    }
    #[zbus(property)]
    fn minimum_rate(&self) -> f64 {
        0.5
    }
    #[zbus(property)]
    fn maximum_rate(&self) -> f64 {
        2.0
    }
    #[zbus(property(emits_changed_signal = "false"))]
    fn shuffle(&self) -> bool {
        self.shared.player.shuffle()
    }
    #[zbus(property)]
    fn set_shuffle(&self, value: bool) {
        self.shared.player.set_shuffle(value);
    }
    #[zbus(property(emits_changed_signal = "false"))]
    fn volume(&self) -> f64 {
        round3(self.shared.player.snapshot().volume as f64 / 100.0)
    }
    #[zbus(property)]
    fn set_volume(&self, value: f64) {
        self.shared
            .player
            .set_volume((value * 100.0).round() as i64);
    }
    #[zbus(property)]
    fn position(&self) -> i64 {
        (self.shared.player.snapshot().position * MICROS) as i64
    }
    #[zbus(property)]
    fn metadata(&self) -> HashMap<String, OwnedVariant> {
        metadata(&self.shared)
    }
    #[zbus(property)]
    fn can_go_next(&self) -> bool {
        true
    }
    #[zbus(property)]
    fn can_go_previous(&self) -> bool {
        true
    }
    #[zbus(property)]
    fn can_play(&self) -> bool {
        true
    }
    #[zbus(property)]
    fn can_pause(&self) -> bool {
        true
    }
    #[zbus(property)]
    fn can_seek(&self) -> bool {
        true
    }
    #[zbus(property)]
    fn can_control(&self) -> bool {
        true
    }

    #[zbus(signal)]
    async fn seeked(emitter: &SignalEmitter<'_>, position: i64) -> zbus::Result<()>;
}

impl Mpris {
    pub fn start(player: Arc<Player>, music_dir: String) -> Result<Self> {
        let conn = zbus::block_on(zbus::Connection::session())?;
        let proxy = zbus::block_on(DBusProxy::new(&conn))?;
        let reply = zbus::block_on(proxy.request_name(
            zbus::names::WellKnownName::try_from(BUS_NAME)?,
            RequestNameFlags::DO_NOT_QUEUE,
        ))?;
        if reply != RequestNameReply::PrimaryOwner && reply != RequestNameReply::AlreadyOwner {
            println!("{TAKEN_NOTICE}");
        }

        let shared = Shared {
            player,
            music_dir,
            rate: Arc::new(AtomicU64::new(bits(1.0))),
        };
        let closed = Arc::new(AtomicBool::new(false));

        zbus::block_on(conn.object_server().at(PATH, Root))?;
        zbus::block_on(conn.object_server().at(
            PATH,
            MprisPlayer {
                shared: shared.clone(),
            },
        ))?;

        let emitter = zbus::object_server::SignalEmitter::new(&conn, PATH)?;
        let tick_shared = shared.clone();
        let tick_closed = Arc::clone(&closed);
        let signal = tick_shared.player.change_signal();
        let signal_for_close = Arc::clone(&signal);
        thread::Builder::new()
            .name("beats-mpris-sync".into())
            .spawn(move || {
                let mut last: HashMap<&'static str, OwnedVariant> = HashMap::new();
                let mut last_meta: Option<HashMap<String, OwnedVariant>> = None;
                let mut seen = 0;
                let mut last_pos: Option<Instant> = None;
                loop {
                    seen = signal.wait(seen);
                    if tick_closed.load(Ordering::Relaxed) {
                        return;
                    }
                    let mut next = changed_props(&tick_shared, &mut last_meta);
                    let mut changed = next != last;
                    if changed {
                        last = next.clone();
                    }
                    let snap = tick_shared.player.snapshot();
                    if snap.state != crate::models::STATE_STOP
                        && last_pos.map_or(true, |t| t.elapsed() >= POSITION_INTERVAL)
                    {
                        next.insert("Position", variant((snap.position * MICROS) as i64));
                        last_pos = Some(Instant::now());
                        changed = true;
                    }
                    if changed {
                        let borrowed: HashMap<&str, Variant<'_>> =
                            next.into_iter().map(|(k, v)| (k, v.into())).collect();
                        let _ = zbus::block_on(zbus::fdo::Properties::properties_changed(
                            &emitter,
                            zbus::names::InterfaceName::try_from(PLAYER_IFACE).unwrap(),
                            borrowed,
                            std::borrow::Cow::Borrowed(&[]),
                        ));
                    }
                }
            })?;
        Ok(Self {
            _conn: conn,
            closed,
            signal: signal_for_close,
        })
    }

    pub fn close(&self) {
        self.closed.store(true, Ordering::Relaxed);
        self.signal.notify();
    }
}
