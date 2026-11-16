pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common.functions
import qs.services
import qs.common.widgets

Singleton {
    id: root

    readonly property var table: {
        "right": 0,
        "left": 0,
        "bottom": 0,
        "top": 0
    }

    Instantiator {
        model: Object.keys(root.table).filter(side => root.table[side] > 0)

        delegate: StyledPanel {
            id: panel
            required property string modelData
            readonly property bool vertical: modelData === "left" || modelData === "right"

            _layer: "Overlay"
            exclusionMode: ExclusionMode.Normal
            exclusiveZone: root.table[modelData]
            mask: Region { item: null }

            anchors.left: modelData !== "right"
            anchors.right: modelData !== "left"
            anchors.top: modelData !== "bottom"
            anchors.bottom: modelData !== "top"

            implicitWidth: vertical ? root.table[modelData] : 0
            implicitHeight: vertical ? 0 : root.table[modelData]
        }
    }
}
