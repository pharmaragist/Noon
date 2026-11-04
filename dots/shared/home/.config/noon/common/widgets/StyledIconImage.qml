import QtQuick
import Quickshell
import Quickshell.Widgets
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs.common

IconImage {
    id: root

    property real tint: 0.6
    property bool colorize: Mem.options.appearance.icons.tint
    property color tintColor: Colors.m3.m3surfaceTint
    property int implicitSize: 24
    property string _source: ""

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    source: NoonUtils.iconPath(_source) ?? "image-x-icon"

    Loader {
        opacity: 1 - root.tint
        active: colorize
        anchors.fill: root
        asynchronous: true

        sourceComponent: Item {
            ColorOverlay {
                z: 1
                anchors.fill: parent
                source: root
                color: root.tintColor
            }
        }
    }
}
