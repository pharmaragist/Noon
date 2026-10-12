import QtQuick
import qs.common

QtObject {
    id: root
    required property int index

    property real idx1: index
    property real idx2: index
    property int idx1Duration: Animations.durations.small
    property int idx2Duration: Animations.durations.large

    Behavior on idx1 {
        SAnim {
            duration: root.idx1Duration
        }
    }
    Behavior on idx2 {
        SAnim {
            duration: root.idx2Duration
        }
    }
}
