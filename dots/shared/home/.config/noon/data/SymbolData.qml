import QtQuick
import Quickshell

import qs.common
import qs.common.functions

QtObject {
    id: root
    readonly property var mediaMap: ({
            "beats": "music_cast",
            "kdeconnect": "android",
            "spotify": "queue_music",
            "firefox": "web",
            "vlc": "play_circle",
            "vlc": "play_circle",
            "mpv": "video_library"
        })

    function getGenericAppSymbolFor(cls) {
        if (!cls)
            return "";
        const rules = [
            {
                pattern: /brave|firefox|zen|chromium|chrome|opera|vivaldi/i,
                icon: "globe"
            },
            {
                pattern: /dolphin|nautilus|files|thunar|nemo|pcmanfm|ranger/i,
                icon: "folder"
            },
            {
                pattern: /steam|heroic|lutris|gamescope|bottles/i,
                icon: "joystick"
            },
            {
                pattern: /kitty|ghostty|alacritty|foot|wezterm|konsole|xterm/i,
                icon: "terminal_2"
            },
            {
                pattern: /code|zed|antigravity|cursor|windsurf/i,
                icon: "data_object"
            },
            {
                pattern: /discord|slack|telegram|whatsapp|signal|element|hexchat/i,
                icon: "chat"
            },
            {
                pattern: /thunderbird|evolution|mailspring/i,
                icon: "mail"
            },
            {
                pattern: /spotify|vlc|mpv|audacious|rhythmbox|cmus|strawberry/i,
                icon: "music_note"
            },
            {
                pattern: /gimp|krita|inkscape|pinta|photoshop|illustrator/i,
                icon: "palette"
            },
            {
                pattern: /libreoffice|onlyoffice|wps/i,
                icon: "description"
            },
            {
                pattern: /zoom|meet|teams|webex/i,
                icon: "videocam"
            },
            {
                pattern: /systemsettings|gnome-control|xfce4-settings|kdeconnect/i,
                icon: "settings"
            },
            {
                pattern: /obsidian|notion|todoist|joplin/i,
                icon: "checklist"
            },
        ];
        return rules.find(r => r.pattern.test(cls))?.icon ?? "";
    }
}
