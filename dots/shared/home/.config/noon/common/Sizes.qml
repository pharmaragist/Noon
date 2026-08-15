pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.services

Singleton {
    readonly property real infinity: Number.POSITIVE_INFINITY
    readonly property real barElevation: hyprland.gapsOut
    readonly property real notificationPopupWidth: 420
    readonly property real toastWidth: 385
    readonly property real frameThickness: !Mem.options.desktop.enableFrame ? 0 : hyprland.gapsOut / 4
    readonly property real elevationMargin: frameThickness + Padding.verylarge
    readonly property size clipboardSize: Qt.size(320, 490)
    readonly property size gameLauncherItemSize: Qt.size(225, 360)

    readonly property QtObject editor: QtObject {
        property size statusIsland: Qt.size(120, 40)
    }

    readonly property QtObject mediaPlayer: QtObject {
        property real sidebarWidth: 300
        property real sidebarWidthCollapsed: 82
        property real overlaySize: 145
        property size controlsSize: Qt.size(600, 80)
    }

    readonly property QtObject beam: QtObject {
        readonly property size normal: Qt.size(470, 70)
        readonly property size expanded: Qt.size(1000, 100)
        readonly property size popupMaxSize: Qt.size(1200, 600)
        readonly property size screenshot: Qt.size(340, 60)
        readonly property size weather: Qt.size(440, 300)
        readonly property size music: Qt.size(400, 160)
        readonly property size drop: Qt.size(600, 280)
        readonly property size dictate: Qt.size(200, 55)
        readonly property size appearance: Qt.size(640, 70)
        readonly property size dictateWindow: Qt.size(640, 480)
    }

    readonly property QtObject osd: QtObject {
        readonly property size bottomPill: Qt.size(224, 68)
        readonly property size centerIsland: Qt.size(145, 145)
        readonly property size sideBay: Qt.size(48, 200)
        readonly property size windows_10: Qt.size(85, 240)
    }

    readonly property QtObject sidebar: QtObject {
        readonly property real bar: 70
        readonly property real half: Math.round(Screen.width * 0.46)
        readonly property real quarter: Math.round(Screen.width * 0.27)
        readonly property real largerQuarter: Math.round(Screen.width * 0.275)
        readonly property real threeQuarter: Math.round(Screen.width * 0.75)
        readonly property real widgetsExpanded: Math.round(Screen.width * 0.5)

        readonly property real session: 280
        readonly property real overviewExpanded: Math.round(Screen.width * 0.435)
        readonly property size shelfItemSize: Qt.size(115, 115)
        readonly property size shelfPopupSize: Qt.size(300, 200)
    }

    readonly property QtObject hyprland: QtObject {
        property real gapsOut: Mem.hypr.gaps_out ?? 0
    }
}
