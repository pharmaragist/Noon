//! Shared data models for beats.

use serde::{Deserialize, Serialize};

pub const LAST_MODIFIED_LAYOUT: &str = "%Y-%m-%dT%H:%M:%SZ";
pub const STATE_PLAY: &str = "play";
pub const STATE_PAUSE: &str = "pause";
pub const STATE_STOP: &str = "stop";

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Track {
    pub file: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub genre: String,
    pub date: String,
    pub track: String,
    pub duration: f64,
    pub last_modified: String,
    pub cover: String,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct QueueState {
    pub pos: i64,
    pub state: String,
    pub volume: i64,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub position: f64,
    pub duration: f64,
    pub repeat: bool,
    #[serde(rename = "loopTrack")]
    pub loop_track: bool,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct LyricState {
    pub title: String,
    pub artist: String,
    pub text: String,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Command {
    pub command: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub a: Option<serde_json::Value>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub b: Option<serde_json::Value>,
}

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Item {
    pub title: String,
    pub artist: String,
    #[serde(rename = "videoId")]
    pub video_id: String,
    pub url: String,
    pub thumbnail: String,
    #[serde(rename = "isPlaylist")]
    pub is_playlist: bool,
    #[serde(default, deserialize_with = "non_null_vec")]
    pub tracks: Vec<Item>,
    pub via: String,
    pub views: Option<serde_json::Value>,
    pub duration: Option<serde_json::Value>,
    pub year: Option<serde_json::Value>,
    #[serde(rename = "isExplicit")]
    pub is_explicit: Option<serde_json::Value>,
    pub album: Option<serde_json::Value>,
}

fn non_null_vec<'de, D>(d: D) -> Result<Vec<Item>, D::Error>
where
    D: serde::Deserializer<'de>,
{
    Ok(Option::<Vec<Item>>::deserialize(d)?.unwrap_or_default())
}
