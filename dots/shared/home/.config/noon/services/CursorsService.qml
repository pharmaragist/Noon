pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils

Singleton {
    id: root
    readonly property var cursors: Mem.store.services.cursors?.availableCursors ?? []
    readonly property string current: Mem.hypr.cursor_theme

    Component.onCompleted:reload()

    function reload() {
        if (!fetcher.running) {
            Mem.store.services.cursors.availableCursors = [];
            fetcher.running = true;
        }
    }

    function set(name, size) {
        Mem.env.XCURSOR_THEME = name;
        NoonUtils.execDetached(["hyprctl", "setcursor", name, size]);
    }

    Connections {
        target: Mem.hypr
        ignoreUnknownSignals: true

        function onCursor_sizeChanged() {
            set(target?.cursor_theme, target?.cursor_size);
        }

        function onCursor_themeChanged() {
            set(target?.cursor_theme, target?.cursor_size);
        }
    }

    Fetcher {
        id: fetcher
        command: ["bash","-c", Paths.scriptsDir + "/get_cursors.sh"]
        onDataChanged: if (data)
            Mem.store.services.cursors.availableCursors = fetcher?.data
    }
}
