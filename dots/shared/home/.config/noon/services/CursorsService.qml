pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

Singleton {
    id: root
    readonly property var cursors: Mem.store.services.cursors?.availableCursors ?? []
    readonly property string current: Mem.hypr.cursor_theme

    function reload() {
        if (!getProc.running) {
            Mem.store.services.cursors.availableCursors = [];
            getProc.running = true;
        }
    }

    Connections {
        target: Mem.hypr
        ignoreUnknownSignals: true
        function onCursor_themeChanged() {
            Mem.env.XCURSOR_THEME = current;
            NoonUtils.execDetached(["hyprctl", "setcursor", current, (Mem.hypr?.cursor_size ?? 24)]);
        }
    }

    Process {
        id: getProc
        running: Mem.store.services.cursors.availableCursors.length === 0
        command: ["bash", "-c", Paths.scriptsDir + "/get_cursors.sh"]
        stdout: SplitParser {
            onRead: line => {
                var current = Mem.store.services.cursors.availableCursors;
                current.push(line);
                Mem.store.services.cursors.availableCursors = current;
            }
        }
    }
}
