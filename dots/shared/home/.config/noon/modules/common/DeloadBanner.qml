import qs.common
import qs.common.utils
import qs.common.widgets
import QtQuick

Scope {
    id: root
    property bool visible: false
    Variants {
        model: MonitorsInfo.all
        StyledPanel {
            required property var modelData
            visible: root.visible
            name: "unblurred_layer"
            screen: modelData
            fill: true
            color: Colors.colLayer0
            _layer: "Background"
            mask: Region {
                item: null
            }
            StyledText {
                anchors.centerIn: parent
                text: "Noon Is Sleeping \nPress Super + Alt + D to Wake it !"
                font: Fonts.request("main", 100)
                color: Colors.colOnLayer0
            }
        }
    }
}
