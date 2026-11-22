//! Hits search and recommendations via ytmusicapi.

use super::models::Item;
use crate::store;
use serde_json::{json, Value};
use std::collections::HashSet;
use std::fs;
use std::sync::OnceLock;
use std::time::Duration;
use ytmusicapi::YTMusicClient;

static ART_AGENT: OnceLock<ureq::Agent> = OnceLock::new();

fn art_agent() -> &'static ureq::Agent {
    ART_AGENT.get_or_init(|| {
        let config = ureq::config::Config::builder()
            .timeout_global(Some(Duration::from_secs(10)))
            .build();
        ureq::Agent::new_with_config(config)
    })
}

fn request(endpoint: &str, body: Value) -> Option<Value> {
    let rt = tokio::runtime::Runtime::new().ok()?;
    rt.block_on(async {
        let client = YTMusicClient::builder().build().ok()?;
        client.send_request(endpoint, body).await.ok()
    })
}

fn collect<'a>(v: &'a Value, key: &str, out: &mut Vec<&'a Value>) {
    match v {
        Value::Object(map) => {
            if let Some(found) = map.get(key) {
                out.push(found);
            }
            for child in map.values() {
                collect(child, key, out);
            }
        }
        Value::Array(items) => {
            for child in items {
                collect(child, key, out);
            }
        }
        _ => {}
    }
}

fn text(v: Option<&Value>) -> String {
    let Some(v) = v else {
        return String::new();
    };
    if let Some(Value::Array(runs)) = v.get("runs") {
        let joined: String = runs
            .iter()
            .filter_map(|run| run.get("text").and_then(Value::as_str))
            .collect();
        if !joined.is_empty() {
            return joined;
        }
    }
    v.as_str().unwrap_or_default().to_string()
}

fn accessibility_artist(v: &Value, title: &str) -> String {
    let label = v
        .pointer("/overlay/musicItemThumbnailOverlayRenderer/content/musicPlayButtonRenderer/accessibilityPlayData/accessibilityData/label")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let rest = label.strip_prefix("Play ").unwrap_or(label);
    let rest = rest.strip_prefix(title).unwrap_or(rest);
    rest.trim_start_matches(" - ").to_string()
}

fn thumbnail(v: &Value) -> String {
    match v {
        Value::Object(map) => {
            if let Some(Value::Array(thumbs)) = map.get("thumbnails") {
                if let Some(url) = thumbs
                    .last()
                    .and_then(|t| t.get("url"))
                    .and_then(Value::as_str)
                {
                    return url.to_string();
                }
            }
            for child in map.values() {
                let found = thumbnail(child);
                if !found.is_empty() {
                    return found;
                }
            }
        }
        Value::Array(items) => {
            for child in items {
                let found = thumbnail(child);
                if !found.is_empty() {
                    return found;
                }
            }
        }
        _ => {}
    }
    String::new()
}

fn cached_thumb(url: String) -> String {
    if url.is_empty() {
        return url;
    }
    let path = store::hits_art_dir().join(format!("{:x}.jpg", md5::compute(url.as_bytes())));
    if !path.exists() {
        if let Ok(mut response) = art_agent().get(&url).call() {
            let bytes = response
                .body_mut()
                .with_config()
                .limit(2 * 1024 * 1024)
                .read_to_vec();
            if let Ok(bytes) = bytes {
                let _ = fs::create_dir_all(store::hits_art_dir());
                let tmp = path.with_extension(format!("tmp-{}", std::process::id()));
                if fs::write(&tmp, bytes).is_ok() {
                    let _ = fs::rename(&tmp, &path);
                }
            }
        }
    }
    if path.exists() {
        format!("file://{}", path.display())
    } else {
        url
    }
}

fn make_item(
    title: String,
    subtitle: String,
    id: String,
    thumb: String,
    is_playlist: bool,
) -> Option<Item> {
    if title.is_empty() || id.is_empty() {
        return None;
    }
    let url = if is_playlist {
        format!("https://music.youtube.com/playlist?list={id}")
    } else {
        format!("https://www.youtube.com/watch?v={id}")
    };
    Some(Item {
        title,
        artist: subtitle,
        video_id: id,
        url,
        thumbnail: thumb,
        is_playlist,
        tracks: Vec::new(),
        via: "youtube-music".into(),
        views: None,
        duration: None,
        year: None,
        is_explicit: None,
        album: None,
    })
}

fn responsive_item(v: &Value) -> Option<Item> {
    let columns = v.get("flexColumns")?.as_array()?;
    let title = text(
        columns
            .first()
            .and_then(|c| c.pointer("/musicResponsiveListItemFlexColumnRenderer/text")),
    );
    let subtitle = text(
        columns
            .get(1)
            .and_then(|c| c.pointer("/musicResponsiveListItemFlexColumnRenderer/text")),
    );
    let artist = accessibility_artist(v, &title);
    let subtitle = if artist.is_empty() { subtitle } else { artist };
    let data = v.get("playlistItemData");
    let video_id = data
        .and_then(|d| d.get("videoId"))
        .and_then(Value::as_str)
        .unwrap_or_default();
    let playlist_id = data
        .and_then(|d| d.get("playlistId"))
        .and_then(Value::as_str)
        .unwrap_or_default();
    let browse_id = v
        .pointer("/navigationEndpoint/browseEndpoint/browseId")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let page_type = v
        .pointer("/navigationEndpoint/browseEndpoint/pageType")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let id = if !video_id.is_empty() {
        video_id
    } else if !playlist_id.is_empty() {
        playlist_id
    } else {
        browse_id
    };
    let is_playlist = !playlist_id.is_empty()
        || page_type == "MUSIC_PAGE_TYPE_PLAYLIST"
        || id.starts_with("VL")
        || id.starts_with("MPREb");
    make_item(
        title,
        subtitle,
        id.to_string(),
        cached_thumb(thumbnail(v)),
        is_playlist,
    )
}

fn row_item(v: &Value) -> Option<Item> {
    let title = text(v.get("title"));
    let subtitle = text(v.get("subtitle"));
    let video_id = v
        .pointer("/navigationEndpoint/watchEndpoint/videoId")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let browse_id = v
        .pointer("/navigationEndpoint/browseEndpoint/browseId")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let playlist_id = v
        .pointer("/navigationEndpoint/watchPlaylistEndpoint/playlistId")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let page_type = v
        .pointer("/navigationEndpoint/browseEndpoint/pageType")
        .and_then(Value::as_str)
        .unwrap_or_default();
    let id = if !video_id.is_empty() {
        video_id
    } else if !playlist_id.is_empty() {
        playlist_id
    } else {
        browse_id
    };
    let is_playlist = !playlist_id.is_empty()
        || page_type == "MUSIC_PAGE_TYPE_PLAYLIST"
        || id.starts_with("VL")
        || id.starts_with("MPREb");
    make_item(
        title,
        subtitle,
        id.to_string(),
        cached_thumb(thumbnail(v)),
        is_playlist,
    )
}

fn finish(nodes: Vec<&Value>, limit: i64) -> Vec<Item> {
    let mut seen = HashSet::new();
    nodes
        .into_iter()
        .filter_map(|v| responsive_item(v).or_else(|| row_item(v)))
        .filter(|item| seen.insert(item.video_id.clone()))
        .take(limit.max(0) as usize)
        .collect()
}

pub fn search(query: &str, limit: i64) -> Vec<Item> {
    let Some(response) = request("search", json!({ "query": query })) else {
        return Vec::new();
    };
    let mut nodes = Vec::new();
    collect(&response, "musicResponsiveListItemRenderer", &mut nodes);
    collect(&response, "musicTwoRowItemRenderer", &mut nodes);
    finish(nodes, limit)
}

fn browse(browse_id: &str, limit: i64) -> Vec<Item> {
    let Some(response) = request("browse", json!({ "browseId": browse_id })) else {
        return Vec::new();
    };
    let mut nodes = Vec::new();
    collect(&response, "musicTwoRowItemRenderer", &mut nodes);
    collect(&response, "musicResponsiveListItemRenderer", &mut nodes);
    finish(nodes, limit)
}

pub fn recommend(_music_dir: &str, limit: i64) -> Vec<Item> {
    browse("FEmusic_home", limit)
}

pub fn discover(limit: i64) -> Vec<Item> {
    browse("FEmusic_explore", limit)
}
