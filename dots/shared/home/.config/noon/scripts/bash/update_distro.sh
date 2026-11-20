#!/bin/sh

if [ -z "$SYSTEM_UPDATE_RUNNING" ]; then
    export SYSTEM_UPDATE_RUNNING=1

    case "${TERMINAL:-}" in
        kitty) exec kitty "$0" ;;
        foot) exec foot "$0" ;;
        alacritty) exec alacritty -e "$0" ;;
        *)
            if [ -n "$TERMINAL" ]; then
                exec "$TERMINAL" "$0"
            elif command -v kitty >/dev/null 2>&1; then
                exec kitty "$0"
            else
                exit 1
            fi
            ;;
    esac
fi

if command -v pacman >/dev/null 2>&1; then
    sudo pacman -Syu
elif command -v dnf >/dev/null 2>&1; then
    sudo dnf upgrade --skip-file-locks
elif command -v apt >/dev/null 2>&1; then
    sudo apt update && sudo apt upgrade
elif command -v zypper >/dev/null 2>&1; then
    sudo zypper update
elif command -v apk >/dev/null 2>&1; then
    sudo apk upgrade
else
    npc global toast "System Update" "error"
    exit 1
fi

status=$?

if [ "$status" -eq 0 ]; then
    npc global toast "System Update" "success"
else
    npc global toast "System Update" "error"
fi
