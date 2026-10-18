#!/usr/bin/env bash

MODE="$1"
TURBO="${2:-always}"
BT="${3:---bluetooth_boot_off}"

if [[ -z "$MODE" ]]; then
    echo "Usage: $0 <powersave|performance> [always|never] [--bluetooth_boot_on|--bluetooth_boot_off]"
    exit 1
fi

if [[ $EUID -ne 0 ]]; then
    exec pkexec "$0" "$MODE" "$TURBO" "$BT"
fi

exec auto-cpufreq --force "$MODE" --turbo="$TURBO" "$BT"
