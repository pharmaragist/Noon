#!/usr/bin/env bash
# dlp.sh — download audio/video with yt-dlp.
set -uo pipefail

command -v yt-dlp >/dev/null || { echo "error: yt-dlp not found" >&2; exit 1; }

usage() {
    echo "usage: dlp.sh (--url URL | --search QUERY) (--audio | --video) [--quality best|standard|low] -d DIR [--dry-run]"
}

url='' search='' media='' quality='best' destination='' dry_run=false

while (($#)); do
    opt=$1
    shift
    case "$opt" in
        --audio) media=audio ;;
        --video) media=video ;;
        --dry-run) dry_run=true ;;
        -h|--help) usage; exit 0 ;;
        --url|--search|--quality|-d|--destination)
            (($#)) || { echo "error: $opt needs a value" >&2; exit 2; }
            val=$1
            shift
            case "$opt" in
                --url) url=$val ;;
                --search) search=$val ;;
                --quality) quality=$val ;;
                *) destination=$val ;;
            esac
            ;;
        *) echo "error: unknown option '$opt'" >&2; exit 2 ;;
    esac
done

[[ -n "$url" || -n "$search" ]] || { echo "error: one of --url or --search is required" >&2; exit 2; }
[[ -z "$url" || -z "$search" ]] || { echo "error: --url and --search are mutually exclusive" >&2; exit 2; }
[[ -n "$media" ]] || { echo "error: one of --audio or --video is required" >&2; exit 2; }
[[ -n "$destination" ]] || { echo "error: --destination is required" >&2; exit 2; }

case "$media-$quality" in
    audio-best)     format='bestaudio/best';                          ext=mp3; mp3q=0 ;;
    audio-standard) format='bestaudio/best';                          ext=mp3; mp3q=5 ;;
    audio-low)      format='bestaudio/best';                          ext=mp3; mp3q=9 ;;
    video-best)     format='bestvideo+bestaudio/best';                ext=mp4 ;;
    video-standard) format='bestvideo[height<=720]+bestaudio/best';   ext=mp4 ;;
    video-low)      format='bestvideo[height<=480]+bestaudio/best';   ext=mp4 ;;
    *) echo "error: invalid quality '$quality'" >&2; exit 2 ;;
esac

if [[ -n "$search" ]]; then
    url=$(yt-dlp --no-config --no-update --no-warnings --no-playlist --flat-playlist --print '%(url)s' "ytsearch1:$search" | head -n1)
    [[ -n "$url" ]] || { echo "error: no results for '$search'" >&2; exit 1; }
fi

mkdir -p "$destination" || exit 1

# Strip leading/trailing bracketed tags from the filename title/track.
prefix='^\s*(?:[\(\[【《「『][^)\]】》」』]*[\)\]】》」』]\s*)+'
suffix='(?:\s*[\(\[【《「『][^)\]】》」』]*[\)\]】》」』])+\s*$'

args=(
    --no-config --no-update --no-warnings --quiet
    --no-playlist --no-cache-dir --write-thumbnail
    --js-runtimes node --js-runtimes deno --js-runtimes bun
    --replace-in-metadata title "$prefix" ''
    --replace-in-metadata title "$suffix" ''
    --replace-in-metadata track "$prefix" ''
    --replace-in-metadata track "$suffix" ''
    -f "$format" -o "$destination/%(track,title)s.%(ext)s"
)

if [[ "$media" == audio ]]; then
    args+=(--extract-audio --audio-format mp3 --audio-quality "$mp3q")
fi
args+=(--embed-metadata --convert-thumbnails jpg --embed-thumbnail)

if [[ "$dry_run" == true ]]; then
    out_path=$(yt-dlp "${args[@]}" --print "$destination/%(track,title)s.%(ext)s" "$url") || exit 1
    [[ "$media" == audio ]] && out_path="${out_path%.*}.$ext"
    printf 'url         : %s\ndestination : %s\nmedia       : %s  quality: %s\n' "$url" "$out_path" "$media" "$quality"
    exit 0
fi

progress='download:%(progress.downloaded_bytes)s,%(progress.total_bytes,progress.total_bytes_estimate)s,%(progress._speed_str|?)s,%(progress._eta_str|?)s'
yt-dlp "${args[@]}" --progress --progress-template "$progress" "$url"
