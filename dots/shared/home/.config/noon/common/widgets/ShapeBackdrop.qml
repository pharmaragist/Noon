import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects

import qs.common

MaterialShape {
    id: root
    property bool rotate: false
    _shape: "Cookie12Sided"
    z: 0
    color: Colors.colSecondaryContainer
    opacity: 0.6

    RotationAnimation on rotation {
        running: root.rotate
        duration: 18000
        easing.type: Easing.Linear
        loops: Animation.Infinite
        from: 0
        to: 360
    }
}
