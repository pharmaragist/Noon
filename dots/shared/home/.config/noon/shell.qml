//@ pragma UseQApplication
//@ pragma RespectSystemStyle
//@ pragma Env QML_DISK_CACHE=aot,qmlc
//@ pragma Env QT_AUTO_SCREEN_SCALE_FACTOR=1
//@ pragma Env QT_QUICK_CONTROLS_STYLE=Basic
//@ pragma Env QT_QPA_PLATFORM=wayland
//@ pragma Env QT_QPA_PLATFORMTHEME=kde
//@ pragma Env QT_WAYLAND_DISABLE_WINDOWDECORATION=1

//@ pragma Env QS_DROP_EXPENSIVE_FONTS=1
//@ pragma Env QS_NO_RELOAD_POPUP=1
//@ pragma Env QS_DISABLE_CRASH_HANDLER=1
//@ pragma Env __NV_PRIME_RENDER_OFFLOAD=0

import QtQuick
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.utils

import "modules/xp"
import "modules/zen"
import "modules/main"
import "modules/nobuntu"
import "modules/common"

ShellRoot {
    id: root

    readonly property string mode: Mem.options.desktop.shell.mode
    readonly property bool deload: Globals.deload || (Mem.options.desktop.shell.deloadOnFullscreen && (Globals.topLevel?.fullscreen ?? false))
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
        onLoaded: console.log(root.mode.toUpperCase() + " Initialized");
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
    GlobalIPC {}
}
