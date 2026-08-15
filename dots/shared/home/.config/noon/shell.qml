














import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.utils

import "modules/xp"
import "modules/zen"
import "modules/main"
import "modules/nobuntu"
import "modules/applications"
import "modules/common"

ShellRoot {
    id: root

    readonly property string mode: Mem.options.desktop.shell.mode
    readonly property bool deload: Mem.states.desktop.shell.deload || (Mem.options.desktop.shell.deloadOnFullscreen && (Globals.topLevel?.fullscreen ?? false))
    readonly property string currentShellPath: shellMap[mode] || "main/Main.qml"
    readonly property var shellMap: {
        "main": "main/Main.qml",
        "xp": "xp/XP.qml",
        "zen": "zen/Zen.qml",
        "nobuntu": "nobuntu/NoBuntu.qml"
    }

    Loader {
        active: !deload && Mem.ready
        source: "modules/" + root.currentShellPath
        onLoaded: Globals.handle_init(root.mode)
    }

    WidgetLoader {
        enabled: !deload
        CommonModules {}
    }

    WidgetLoader {
        enabled: deload
        DeloadBanner {
            visible: root.deload
        }
    }

    DeloadBanner {}
    MCP {}
    GlobalIPC {}
    
}
