//! Text cleaning for lyric lookups (manual equivalents of the Go regexes).

fn is_space(b: u8) -> bool {
    matches!(b, b' ' | b'\t' | b'\n' | b'\r' | 0x0c)
}

fn squash(s: &str) -> String {
    s.split_whitespace().collect::<Vec<_>>().join(" ")
}

fn remove_brackets(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        let mut j = i;
        while j < b.len() && is_space(b[j]) {
            j += 1;
        }
        if j < b.len() && (b[j] == b'(' || b[j] == b'[') {
            let mut k = j + 1;
            while k < b.len() && b[k] != b'\n' && b[k] != b')' && b[k] != b']' {
                k += 1;
            }
            if k < b.len() {
                k += 1;
                while k < b.len() && is_space(b[k]) {
                    k += 1;
                }
                out.push(b' ');
                i = k;
                continue;
            }
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8(out).unwrap_or_else(|_| s.to_string())
}

fn word_at(b: &[u8], at: usize, word: &[u8]) -> bool {
    at + word.len() <= b.len() && b[at..at + word.len()].eq_ignore_ascii_case(word)
}

fn strip_suffix(s: &str) -> &str {
    let b = s.as_bytes();
    for i in 0..b.len() {
        if b[i] != b'-' {
            continue;
        }
        let mut start = i;
        while start > 0 && is_space(b[start - 1]) {
            start -= 1;
        }
        let mut k = i + 1;
        while k < b.len() && is_space(b[k]) {
            k += 1;
        }
        let mut end = None;
        for word in [&b"official"[..], b"lyric", b"audio", b"video"] {
            if word_at(b, k, word) {
                end = Some(k + word.len());
                break;
            }
        }
        if end.is_none() && word_at(b, k, b"music") {
            let mut m = k + 5;
            while m < b.len() && is_space(b[m]) {
                m += 1;
            }
            if word_at(b, m, b"video") {
                end = Some(m + 5);
            }
        }
        if end.is_none() && word_at(b, k, b"visualizer") {
            end = Some(k + 10);
        }
        if end.is_none() && word_at(b, k, b"remaster") {
            let mut m = k + 8;
            if word_at(b, m, b"ed") {
                m += 2;
            }
            end = Some(m);
        }
        if let Some(mut e) = end {
            while e < b.len() && is_space(b[e]) {
                e += 1;
            }
            if e == b.len() {
                return &s[..start];
            }
        }
    }
    s
}

fn strip_feat(s: &str) -> String {
    let b = s.as_bytes();
    let mut out = Vec::with_capacity(b.len());
    let mut i = 0;
    while i < b.len() {
        if is_space(b[i]) {
            let start = i;
            let mut j = i;
            while j < b.len() && is_space(b[j]) {
                j += 1;
            }
            let mut matched = false;
            for tok in [&b"feat."[..], b"featuring", b"ft.", b"with", b"x", b"&"] {
                let after = j + tok.len();
                if word_at(b, j, tok) && after < b.len() && is_space(b[after]) {
                    let mut e = after;
                    while e < b.len() && b[e] != b'\n' {
                        e += 1;
                    }
                    i = e;
                    matched = true;
                    break;
                }
            }
            if matched {
                continue;
            }
            out.extend_from_slice(&b[start..j]);
            i = j;
            continue;
        }
        out.push(b[i]);
        i += 1;
    }
    String::from_utf8(out).unwrap_or_else(|_| s.to_string())
}

pub(crate) fn clean_title(s: &str, artist: &str) -> String {
    let s = remove_brackets(s);
    let s = squash(strip_suffix(&s)).to_lowercase();
    if artist.is_empty() {
        return s;
    }
    let mut out = s;
    if out.len() >= artist.len() {
        let at = out.len() - artist.len();
        if let Some(tail) = out.get(at..) {
            if tail.eq_ignore_ascii_case(artist) {
                if let Some(n) = sep_before_len(&out[..at]) {
                    out.truncate(at - n);
                    out = out.trim_end().to_string();
                }
            }
        }
    }
    if out.len() >= artist.len() {
        if let (Some(head), Some(rest)) = (out.get(..artist.len()), out.get(artist.len()..)) {
            if head.eq_ignore_ascii_case(artist) {
                if let Some(n) = sep_after_len(rest) {
                    out = rest[n..].trim_start().to_string();
                }
            }
        }
    }
    out.trim().to_string()
}

pub(crate) fn clean_artist(s: &str) -> String {
    squash(&remove_brackets(&strip_feat(s))).to_lowercase()
}

pub(crate) fn split_segments(title: &str) -> Vec<String> {
    let mut segs: Vec<String> = Vec::new();
    let mut cur = 0;
    let b = title.as_bytes();
    for (idx, ch) in title.char_indices() {
        if matches!(ch, '|' | '/' | '\u{ff5c}') {
            push_segment(title, &mut segs, cur, idx);
            cur = idx + ch.len_utf8();
        } else if ch == '-'
            && idx > 0
            && idx + 1 < b.len()
            && b[idx - 1] == b' '
            && b[idx + 1] == b' '
        {
            push_segment(title, &mut segs, cur, idx - 1);
            cur = idx + 2;
        }
    }
    push_segment(title, &mut segs, cur, title.len());
    segs
}

fn push_segment(src: &str, segs: &mut Vec<String>, from: usize, to: usize) {
    let s = src[from..to].trim();
    if s.chars().count() >= 4 && !segs.iter().any(|old| old == s) {
        segs.push(s.to_string());
    }
}

pub(crate) fn is_latin(s: &str) -> bool {
    s.chars().all(|c| (c as u32) < 0x600)
}

fn is_token_rune(c: char) -> bool {
    let n = c as u32;
    c == '_' || c.is_alphanumeric() || (0x600..=0x6ff).contains(&n)
}

pub(crate) fn query_tokens(title: &str, artist: &str) -> Vec<String> {
    let mut toks = Vec::new();
    let mut cur = String::new();
    let mut high = false;
    for c in title
        .chars()
        .chain(std::iter::once(' '))
        .chain(artist.chars())
    {
        if is_token_rune(c) {
            cur.push(c);
            high |= (c as u32) >= 0x600;
        } else {
            flush_token(&mut cur, &mut high, &mut toks);
        }
    }
    flush_token(&mut cur, &mut high, &mut toks);
    toks
}

fn flush_token(cur: &mut String, high: &mut bool, toks: &mut Vec<String>) {
    let n = cur.chars().count();
    if n > 0 && ((*high && n >= 3) || (!*high && n >= 4)) {
        toks.push(cur.to_lowercase());
    }
    cur.clear();
    *high = false;
}

const SEP_CHARS: [char; 9] = [
    '\u{2013}', '\u{2014}', '\u{ff0d}', '\u{2212}', '_', '|', '/', '\u{2022}', '\u{00b7}',
];

fn sep_before_len(s: &str) -> Option<usize> {
    let b = s.as_bytes();
    let mut end = b.len();
    while end > 0 && is_space(b[end - 1]) {
        end -= 1;
    }
    let (idx, ch) = s[..end].char_indices().next_back()?;
    if SEP_CHARS.contains(&ch) {
        return Some(b.len() - idx);
    }
    if ch != '-' {
        return None;
    }
    let mut dash = idx;
    while dash > 0 && b[dash - 1] == b'-' {
        dash -= 1;
    }
    if dash == 0 || !is_space(b[dash - 1]) {
        return None;
    }
    let mut start = dash - 1;
    while start > 0 && is_space(b[start - 1]) {
        start -= 1;
    }
    Some(b.len() - start)
}

fn sep_after_len(s: &str) -> Option<usize> {
    let b = s.as_bytes();
    let mut start = 0;
    while start < b.len() && is_space(b[start]) {
        start += 1;
    }
    let had_space = start > 0;
    let (ch, width) = {
        let mut chars = s[start..].char_indices();
        let (_, ch) = chars.next()?;
        (ch, ch.len_utf8())
    };
    if SEP_CHARS.contains(&ch) {
        let mut end = start + width;
        while end < b.len() && is_space(b[end]) {
            end += 1;
        }
        return Some(end);
    }
    if ch != '-' || !had_space {
        return None;
    }
    let mut end = start;
    while end < b.len() && b[end] == b'-' {
        end += 1;
    }
    if end >= b.len() || !is_space(b[end]) {
        return None;
    }
    while end < b.len() && is_space(b[end]) {
        end += 1;
    }
    Some(end)
}
