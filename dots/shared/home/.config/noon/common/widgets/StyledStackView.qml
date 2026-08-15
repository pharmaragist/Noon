import QtQuick
import QtQuick.Controls
import qs.common





StackView {
    id: root

    property int slideDirection: 1

    replaceEnter: Transition {
        ParallelAnimation {
            PropertyAnimation {
                property: "scale"
                from: 0.65
                to: 1
                duration: Animations.durations.large
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Animations.curves.emphasized
            }
            PropertyAnimation {
                property: "opacity"
                from: 0
                to: 1
                duration: Animations.durations.small
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Animations.curves.emphasizedAccel
            }
        }
    }
    replaceExit: Transition {
        ParallelAnimation {
            PropertyAnimation {
                property: "scale"
                from: 1
                to: 0.65
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Animations.curves.emphasized
                duration: Animations.durations.large
            }
            PropertyAnimation {
                property: "opacity"
                from: 1
                to: 0
                duration: Animations.durations.small
                easing.type: Easing.BezierSpline
                easing.bezierCurve: Animations.curves.emphasizedAccel
            }
        }
    }
}
