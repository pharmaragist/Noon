#!/usr/bin/env bash
set -euo pipefail

float_width="${1:-}"
float_height="${2:-}"

floating="$(niri msg -j focused-window | jq -r '.is_floating | tostring')"
case "$floating" in
    true|false) ;;
    *) exit 0 ;;
esac

if [ "$floating" = true ]; then
    niri msg action move-window-to-tiling
    niri msg action expand-column-to-available-width
    niri msg action reset-window-height
else
    niri msg action move-window-to-floating
    if [ -n "$float_width" ] && [ -n "$float_height" ]; then
        niri msg action set-window-width "$float_width"
        niri msg action set-window-height "$float_height"
    fi
fi
