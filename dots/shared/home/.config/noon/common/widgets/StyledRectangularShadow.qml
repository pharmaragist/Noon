import QtQuick
import QtQuick.Effects
import qs.common
import Qt5Compat.GraphicalEffects

RectangularShadow {
    id: root
    required property var target
    property bool show: true
    property real transparency: 0.2
    z: -9999
    blur: 25
    spread: 0.25
    cached: true
    visible: !Colors.transparent && opacity > 0
    anchors.fill: target
    color: Colors.t(Colors.colShadow, transparency)
    radius: Rounding.verylarge
    opacity: show ? target.opacity : 0
}
