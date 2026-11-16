import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services
import qs.data

BottomDialog {
    id: root

    property int comboWidth: 240
    z: 9999
    bottomAreaReveal: true
    hoverHeight: 230
    baseHeight: 70
    enableStagedReveal: false

    contentItem: RowLayout {
        anchors.fill: parent
        anchors.margins: Padding.verylarge

        StyledTextField {
            id: folderEntry
            text: Paths.methods.collapsePath(Mem.looks.currentFolder)
            placeholderText: "Wallpaper folder path..."
            placeholderTextColor: Colors.colOnLayer3
            color: Colors.colOnLayer1
            bg.color: Colors.colLayer4
            Keys.onEscapePressed: focus = false
            onAccepted: Mem.looks.currentFolder = Paths.methods.expandPath(folderEntry.text)
            Layout.fillWidth: true
            implicitHeight: 45
        }

        StyledComboBox {
            height: 45
            width: 165
            _model: ["Unsorted", "Name", "Time", "Size", "Type"]
            currentIndex: Math.max(0, model.findIndex(v => v.toLowerCase() === Mem.options.services.wallpapers.order.toLowerCase()))
            onCurrentIndexChanged: Mem.options.services.wallpapers.order = model[this.currentIndex]
        }
    }
}
