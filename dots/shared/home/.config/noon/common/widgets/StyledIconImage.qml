import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import Quickshell.Widgets
import qs.common

Item {
    id: root

    property real tint: 0.6
    property bool colorize: Mem.options.appearance.icons.tint
    property color tintColor: Colors.methods.transparentize(Colors.m3.m3surfaceTint, 1- tint)
    property int implicitSize: 24
    property string _source: ""
    property string source: ""

    readonly property string resolvedSource: {
        const value = root.source || root._source;
        if (!value)
            return "";
        if (value.startsWith("/") || value.startsWith("file:") || value.startsWith("image:") || value.startsWith("qrc:"))
            return value;
        return NoonUtils.iconPath(value) ?? "";
    }

    implicitWidth: implicitSize
    implicitHeight: implicitSize

    IconImage {
        id: icon
        implicitSize: root.implicitSize
        anchors.centerIn: parent
        source: root.resolvedSource
    }

    Loader {
        anchors.fill: icon
        active: root.colorize

        sourceComponent: ColorOverlay {
            anchors.fill: icon
            source: icon
            color: root.tintColor
        }
    }
}
