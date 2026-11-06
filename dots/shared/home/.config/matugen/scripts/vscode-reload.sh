#!/bin/sh
hyprctl dispatch 'hl.dsp.send_shortcut({ mods = "CTRL ALT SHIFT", key = "F12", window = "class:(?i)^(vscodium|codium|code|vscode)$" })'
