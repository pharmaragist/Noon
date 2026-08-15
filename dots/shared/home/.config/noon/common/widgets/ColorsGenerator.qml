import QtQuick
import Quickshell
import qs.common
import "./../../vendors/colors/M3.js" as M3lib
import "./../../vendors/colors/M3Palette.js" as M3Palette





Item {
    id: root
    enum State {
        Working,
        Error
    }
    readonly property var state: keyColor ? ColorsGenerator.State.Working : ColorsGenerator.State.Error
    property color keyColor: "white"
    property bool dark: true
    property string scheme: "scheme-tonal-spot"
    property bool active: false
    property var colors: active ? palette : Colors

    readonly property var palette: M3Palette.build(root.keyColor, root.dark, M3lib.__m3, root.scheme)
}
