import QtQuick
import qs.common

PropertyAnimation {
    easing.type: Easing.BezierSpline
    duration: Animations.durations.verylarge
    easing.bezierCurve: Animations.curves.expressiveFastSpatial
}
