#!/bin/bash
find /usr/share/icons ~/.local/share/icons ~/.icons -mindepth 2 -maxdepth 2 -type d -name "cursors" -printf "%h\n" 2>/dev/null | xargs -n 1 basename | sort -u | jq -R . | jq -s .
