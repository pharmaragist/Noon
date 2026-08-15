import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services
import qs.common.widgets
import qs.common.utils









Variants {
    model: [MonitorsInfo?.focused]
    StyledPanel {
        id: root
        required property var modelData
        name: "blurred_layer"
        screen: modelData
        _layer: "Overlay"
        exclusiveZone: -1
        readonly property bool active: Globals.main.clipboard.mode.length > 0
        readonly property int elevation: 20

        implicitWidth: bg.implicitWidth + elevation
        implicitHeight: bg.implicitHeight + elevation
        keyboardFocus: true

        anchors.bottom: true
        anchors.right: true
        focusHandler.active: active
        focusHandler.onCleared: content.dismiss()
        onActiveChanged: if (active)
            Qt.callLater(() => content.currentItem.focusView())

        StyledRectangularShadow {
            target: bg
            transparency: 0.85
        }

        PanelRect {
            id: bg
            implicitWidth: Sizes.clipboardSize?.width
            implicitHeight: Sizes.clipboardSize?.height
            radius: Rounding.silly
            anchors.centerIn: parent
            enableBorders: true

            Keys.onPressed: event => {
                if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_F) {
                    content.showSearchBar = !content.showSearchBar
                    content.searchInput.forceActiveFocus()
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    content.dismiss()
                    event.accepted = true;
                }
            }

            ClipboardContent {
                id: content
            }
        }
    }
}
