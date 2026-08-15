import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services
import qs.store

BottomDialog {
    id: root

    property int comboWidth: 240

    z: 9999
    bottomAreaReveal: true
    hoverHeight: 230
    collapsedHeight: 70
    enableStagedReveal: false

    contentItem: StyledTextField {
        id: folderEntry
        anchors.fill: parent
        anchors.margins: Padding.verylarge
        text: FileUtils.collapsePath(Mem.looks.currentFolder)
        placeholderText: "Wallpaper folder path..."
        placeholderTextColor: Colors.colOnLayer3
        color: Colors.colOnLayer1
        bg.color: Colors.colLayer4
        Keys.onEscapePressed: focus = false
        onAccepted: Mem.looks.currentFolder = FileUtils.expandPath(folderEntry.text)
    }
}
