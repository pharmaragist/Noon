#!/usr/bin/env bash
sleep 0.2
CURRENT=$(sed -n 's/^ColorScheme=\(.*\)/\1/p' ~/.config/kdeglobals)
[[ "$CURRENT" == *2 ]] && TARGET="Noon" || TARGET="Noon2"
if command -v plasma-apply-colorscheme >/dev/null 2>&1; then
    plasma-apply-colorscheme "$TARGET"
else
    kwriteconfig6 --file kdeglobals --group General --key ColorScheme "$TARGET"
fi
