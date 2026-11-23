#!/bin/bash
# Kitty hotkey reference, press any key to close

P='\033[38;2;134;209;233m'   # cyan
C='\033[38;2;178;235;255m'   # light cyan
G='\033[38;2;206;231;240m'   # green
Y='\033[38;2;193;196;235m'   # lavender
K='\033[38;2;255;113;188m'   # pink
D='\033[38;2;52;74;82m'      # dim
W='\033[38;2;222;227;230m'   # foreground
B='\033[1m'
R='\033[0m'

clear

echo -e "${P}${B}"
echo -e "  ╭──────────────────────────────────────────────────────────────────╮"
echo -e "  │                  KITTY — KEYBOARD REFERENCE                     │"
echo -e "  ╰──────────────────────────────────────────────────────────────────╯${R}"
echo ""

# Helper: print one row
row() { printf "  ${Y}%-30s${D}│${R}  %s\n" "$1" "$2"; }
hdr() { echo -e "\n  ${C}${B}$1${R}"; echo -e "  ${D}──────────────────────────────────────────────────────────────────${R}"; }

hdr " TABS"
row "Ctrl+T"                    "New tab (same directory)"
row "Ctrl+W"                    "Close tab"
row "Ctrl+Tab"                  "Next tab"
row "Ctrl+Shift+Tab"            "Previous tab"
row "Ctrl+Shift+I"              "Rename tab"
row "Ctrl+Alt+1 … 6"           "Jump to tab 1–6"
row "Ctrl+Shift+,  /  ."        "Move tab left / right"

hdr " WINDOWS & SPLITS"
row "Ctrl+Shift+Enter"          "New window (same directory)"
row "Ctrl+Shift+W"              "Close window"
row "Ctrl+Shift+]  /  ["        "Next / previous window"
row "Ctrl+Shift+Alt+V"          "Vertical split"
row "Ctrl+Shift+Alt+H"          "Horizontal split"
row "Ctrl+Shift+↑ ↓ ← →"       "Resize window"

hdr " LAYOUTS"
row "Ctrl+Alt+T"                "Tall"
row "Ctrl+Alt+G"                "Grid"
row "Ctrl+Alt+H"                "Horizontal"
row "Ctrl+Alt+V"                "Vertical"
row "Ctrl+Alt+Z"                "Toggle stack (fullscreen pane)"
row "Ctrl+Shift+F11"            "OS fullscreen"

hdr " URL & FILE HINTS"
row "Ctrl+Click"                "Open URL in browser"
row "Ctrl+Shift+E"              "Pick URL from screen"
row "Ctrl+Shift+P  →  F"       "Open file path"
row "Ctrl+Shift+P  →  I"       "Insert file path at cursor"
row "Ctrl+Shift+P  →  H"       "Copy git commit hash"
row "Ctrl+Shift+P  →  W"       "Copy word"

hdr " SCROLLBACK & NAVIGATION"
row "Ctrl+Shift+Z  /  X"        "Jump between shell prompts"
row "Ctrl+Shift+PgUp / PgDn"   "Scroll page up / down"
row "Ctrl+Shift+Home / End"     "Scroll to top / bottom"

hdr " CLAUDE BOARD (tmux)  — prefix: Ctrl+Space"
row "Ctrl+Alt+0"           "Open / restore Claude Board"
row "mouse click"          "Switch pane  (just click!)"
row "Ctrl+Space → v"       "Split vertical   (left | right)"
row "Ctrl+Space → s"       "Split horizontal (top / bottom)"
row "Ctrl+Space → z"       "Zoom / unzoom pane"
row "Ctrl+Space → x"       "Close pane"
row "Ctrl+Space → q"       "Window 1 — 󰄛 claude"
row "Ctrl+Space → w"       "Window 2 —  monitor"
row "Ctrl+Space → e"       "Window 3 —  logs"
row "Ctrl+Space → r"       "Window 4 —  shell"
row "Ctrl+Space → [ / ]"   "Previous / next window"
row "Ctrl+Space → 1..6"    "Jump to pane by number"
row "Ctrl+Space → H/L/K/J" "Resize pane"
row "Ctrl+Space → Space"   "Cycle layouts"
row "Ctrl+Space → c"       "New window"

hdr " MISC"
row "Ctrl+=  /  Ctrl+-"         "Font size larger / smaller"
row "Ctrl+0"                    "Reset font size"
row "Ctrl+Shift+Y"              "Open yazi file manager"
row "Ctrl+Shift+U"              "Unicode input"
row "Ctrl+F9  /  F10"          "Magic dust  on / off"
row "Ctrl+Shift+F5"             "Reload kitty config"
row "F1"                        "This help panel"

echo ""
echo -e "  ${D}Press any key to close...${R}"
read -r -s -n 1
