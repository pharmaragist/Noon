import QtQuick
import Quickshell
import Quickshell.Widgets

GlobalShortcut {
    property bool enabled: true
    appid: enabled ? "noon" : ""
}
