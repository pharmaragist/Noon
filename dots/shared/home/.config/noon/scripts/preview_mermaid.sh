#!/usr/bin/env bash
# preview_mermaid.sh <input.mmd> <output.png> — render mermaid locally via mmdc + system chromium.
set -u
MROOT="$HOME/.local/share/noon/mermaid"
exec "$MROOT/node_modules/.bin/mmdc" \
  --puppeteerConfigFile "$MROOT/puppeteer.json" \
  -t dark -b transparent \
  -i "$1" -o "$2"
