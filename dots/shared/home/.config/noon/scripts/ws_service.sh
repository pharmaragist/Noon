#!/usr/bin/env bash
curr=$(hyprctl activeworkspace -j | jq '.id')


[[ "$1" =~ ^[0-9]+$ ]] && disp="workspace" && target=$1 || { disp=$1; target=$2; }


[[ "$target" =~ ^[0-9]+$ ]] && target=$(( (curr - 1) / 10 * 10 + target ))

hyprctl dispatch "$disp" "$target"
