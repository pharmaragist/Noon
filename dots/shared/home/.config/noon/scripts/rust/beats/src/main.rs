//! Beats music daemon and CLI.

mod clean;
mod config;
mod covers;
mod daemon;
mod hits;
mod library;
mod lyrics;
mod models;
mod mpris;
mod player;
mod store;

use anyhow::Result;
use clap::{Parser, Subcommand};
use std::io::Write;

const USAGE: &str = "Usage: beats [-d|--directory DIR] <command> [options]\n\n\
Lifecycle:\n  serve                          run daemon in foreground\n  init                           start daemon detached\n  kill                           stop daemon\n\n\
Playback (starts daemon if needed):\n  play-file --file PATH\n  play-url --url URL\n  play-by-name --name NAME\n  play-pause\n  next\n  prev\n  stop\n  seek [--seconds SECONDS]\n  volume [--volume N]\n  build-playlist --list TITLES\n  refresh-config\n  lyrics-refetch\n  preview --url URL\n  preview-stop\n\n\
Reads:\n  library\n  list-artists\n  list-albums\n  list-genres\n\n\
Maintenance:\n  fetch\n  fetch-all-lyrics [--limit N] [--workers N]\n\n\
Hits:\n  search --query Q [--limit N]\n  recommend [--limit N]\n  discover [--limit N]\n\n\
Global:\n  -d, --directory DIR  override music directory (persisted)\n  -h, --help           show this help";

#[derive(Parser)]
#[command(
    name = "beats",
    disable_help_subcommand = true,
    disable_version_flag = true
)]
struct Cli {
    #[arg(short = 'd', long = "directory", global = true)]
    directory: Option<String>,
    #[command(subcommand)]
    command: Option<Cmd>,
}

#[derive(Subcommand)]
enum Cmd {
    Serve,
    Init,
    Kill,
    #[command(name = "play-file")]
    PlayFile {
        #[arg(long)]
        file: String,
    },
    #[command(name = "play-url")]
    PlayUrl {
        #[arg(long)]
        url: String,
    },
    #[command(name = "play-by-name")]
    PlayByName {
        #[arg(long)]
        name: String,
    },
    #[command(name = "play-pause")]
    PlayPause,
    Next,
    Prev,
    Stop,
    Seek {
        #[arg(long, default_value_t = 5.0)]
        seconds: f64,
    },
    Volume {
        #[arg(long, default_value_t = 50)]
        volume: i64,
    },
    #[command(name = "build-playlist")]
    BuildPlaylist {
        #[arg(long)]
        list: String,
    },
    #[command(name = "refresh-config")]
    RefreshConfig,
    #[command(name = "lyrics-refetch")]
    LyricsRefetch,
    Preview {
        #[arg(long)]
        url: String,
    },
    #[command(name = "preview-stop")]
    PreviewStop,
    Library,
    #[command(name = "list-artists")]
    ListArtists,
    #[command(name = "list-albums")]
    ListAlbums,
    #[command(name = "list-genres")]
    ListGenres,
    Fetch,
    #[command(name = "fetch-all-lyrics")]
    FetchAllLyrics {
        #[arg(long)]
        limit: Option<usize>,
        #[arg(long, default_value_t = 5)]
        workers: usize,
    },
    Search {
        #[arg(long)]
        query: String,
        #[arg(long, default_value_t = 18)]
        limit: usize,
    },
    Recommend {
        #[arg(long, default_value_t = 18)]
        limit: usize,
    },
    Discover {
        #[arg(long, default_value_t = 18)]
        limit: usize,
    },
}

fn print_json<T: serde::Serialize>(value: &T) {
    match serde_json::to_string(value) {
        Ok(json) => println!("{json}"),
        Err(e) => eprintln!("beats: {e}"),
    }
}

fn send_cmd(name: &str, a: Option<serde_json::Value>) -> Result<()> {
    let dir = config::music_dir_or_fail();
    if daemon::live_pid().is_none() {
        daemon::init()?;
    }
    let cmd = models::Command {
        command: name.into(),
        a,
        b: None,
    };
    store::write_json(&store::cmd_path(&dir), &cmd)
}

fn run() -> Result<()> {
    let cli = Cli::parse();
    if let Some(dir) = cli.directory.as_deref() {
        config::set_directory(dir)?;
    }
    let cmd = match cli.command {
        Some(cmd) => cmd,
        None => {
            eprintln!("{USAGE}");
            std::process::exit(2);
        }
    };

    match cmd {
        Cmd::Serve => daemon::serve(),
        Cmd::Init => daemon::init(),
        Cmd::Kill => daemon::kill(),
        Cmd::PlayFile { file } => send_cmd("playFile", Some(serde_json::json!(file))),
        Cmd::PlayUrl { url } => send_cmd("playUrl", Some(serde_json::json!(url))),
        Cmd::PlayByName { name } => send_cmd("playByName", Some(serde_json::json!(name))),
        Cmd::PlayPause => send_cmd("playPause", None),
        Cmd::Next => send_cmd("next", None),
        Cmd::Prev => send_cmd("prev", None),
        Cmd::Stop => send_cmd("stop", None),
        Cmd::Seek { seconds } => send_cmd("seekBy", Some(serde_json::json!(seconds))),
        Cmd::Volume { volume } => send_cmd("setVolume", Some(serde_json::json!(volume))),
        Cmd::BuildPlaylist { list } => send_cmd("buildPlaylist", Some(serde_json::json!(list))),
        Cmd::RefreshConfig => send_cmd("refreshConfig", None),
        Cmd::LyricsRefetch => send_cmd("lyricsRefetch", None),
        Cmd::Preview { url } => send_cmd("preview", Some(serde_json::json!(url))),
        Cmd::PreviewStop => send_cmd("previewStop", None),
        Cmd::Library => {
            let dir = config::music_dir_or_fail();
            let tracks = library::get_library(&dir).unwrap_or_default();
            print_json(&tracks);
            Ok(())
        }
        Cmd::ListArtists => list_field("artist"),
        Cmd::ListAlbums => list_field("album"),
        Cmd::ListGenres => list_field("genre"),
        Cmd::Fetch => {
            let dir = config::music_dir_or_fail();
            let _ = library::get_library(&dir)?;
            covers::build_covers(&dir)?;
            eprintln!("Fetch complete.");
            Ok(())
        }
        Cmd::FetchAllLyrics { limit, workers } => {
            let dir = config::music_dir_or_fail();
            lyrics::fetch_all(&dir, limit, workers.max(1));
            Ok(())
        }
        Cmd::Search { query, limit } => {
            let results = hits::search(&query, limit as i64);
            print_json(&results);
            Ok(())
        }
        Cmd::Recommend { limit } => {
            let dir = config::music_dir_or_fail();
            let results = hits::recommend(&dir, limit as i64);
            print_json(&results);
            Ok(())
        }
        Cmd::Discover { limit } => {
            let results = hits::discover(limit as i64);
            print_json(&results);
            Ok(())
        }
    }
}

fn list_field(field: &str) -> Result<()> {
    let dir = config::music_dir_or_fail();
    let tracks = library::get_library(&dir).unwrap_or_default();
    let mut values: Vec<String> = tracks
        .into_iter()
        .map(|t| match field {
            "artist" => t.artist,
            "album" => t.album,
            _ => t.genre,
        })
        .filter(|s| !s.is_empty())
        .collect();
    values.sort();
    values.dedup();
    print_json(&values);
    Ok(())
}

fn main() {
    if let Err(e) = run() {
        eprintln!("beats: {e:#}");
        std::process::exit(1);
    }
    let _ = std::io::stdout().flush();
}
