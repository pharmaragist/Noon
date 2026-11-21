//! Hits stubs.

use super::models::Item;

pub fn search(_query: &str, _limit: i64) -> Vec<Item> {
    Vec::new()
}

pub fn recommend(_music_dir: &str, _limit: i64) -> Vec<Item> {
    Vec::new()
}

pub fn discover(_limit: i64) -> Vec<Item> {
    Vec::new()
}
