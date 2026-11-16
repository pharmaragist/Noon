import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import qs.common

RectangularShadow {
    id: root
    required property var target
    property bool show: true
    property real transparency: 0.35

    z: Math.min(target?.z, -9999)
    x: target.x
    y: target.y
    width: target.width
    height: target.height
    blur: 25
    radius: 25
    spread: 0.25
    cached: true
    visible: !Colors.transparent && opacity > 0
    color: Colors.t(Colors.colShadow, 1 - transparency)
    opacity: show ? target.opacity : 0
}
