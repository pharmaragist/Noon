import QtQuick
import qs.common

NumberAnimation {
    property string _duration: "expressiveFastSpatial"
    property string _curve: Mem.options.appearance.animations?.curve ?? "standard"
    easing.type: Easing.BezierSpline
    duration: Animations.durations[_duration]
    easing.bezierCurve: Animations.curves[_curve]
}
