import qs.services
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

StyledRect {
    id: root

    property bool editing: parent?.editing ?? false
    property bool enableMouseSelection: parent?.enableMouseSelection ?? false
    property var segmentContent: parent?.segmentContent ?? ({})
    property var segmentLang: parent?.segmentLang ?? "txt"
    property bool isCommandRequest: segmentLang === "command"
    property var displayLang: (isCommandRequest ? "bash" : segmentLang)
    property var messageData: parent?.messageData ?? {}
    property bool thinking: false

    implicitHeight: width
    Layout.fillWidth: true
    color: Colors.colLayer1
    radius: Rounding.huge
    enableBorders: true

    StyledImage {
        anchors.fill: parent
        source: root.image
    }
}
