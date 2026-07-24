import QtQuick
import Quickshell

Region {
    id: root
    default property var regions: container?.children ?? []
    required property var components // [{ item: item, enabled: true }]
    readonly property Item container: Repeater {
        model: root.components
        delegate: ConditionedRegion {
            required property var modelData
            required property int index
            enabled: modelData?.enabled ?? true
            component: modelData?.item ?? dummy
        }
    }
}
