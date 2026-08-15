import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.common.utils
import qs.common.functions
import qs.services
import Qt5Compat.GraphicalEffects
import QtQuick.Effects

Item {
    id: root
    z: 999
    implicitHeight: 400
    implicitWidth: 400
    readonly property bool isLocked: Globals.main.locked

    Anim on x {
        from: 0
        to: (Screen?.width - width) / 2
        duration: 450
    }

    Anim on y {
        from: Screen.height + 100 
        to: (Screen?.height - (height * 1.4)) / 2
        duration: 450
    }

    ParallelAnimation {
        id: lockAnimation
        running: root.isLocked
        RotationAnimation {
            target: shape
            property: "rotation"
            from: 360
            to: 0
            duration: 700
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Animations.curves.expressiveEffects
        }
        Anim {
            target: shape
            property: "scale"
            from: 0.0
            to: 1.0
            duration: 700
        }
    }

    Item {
        implicitHeight: children[0].implicitHeight
        implicitWidth: children[0].implicitWidth
        z: 999

        anchors {
            left: shape.left
            top: shape.top
            topMargin: Padding.massive
            margins: -1.25 * Padding.massive
        }

        Shape {
            _shape: "Pill"
            implicitSize: 180
            color: Colors.colTertiaryContainer
            anchors.centerIn: parent

            RotationAnimation on rotation {
                running: true
                duration: 12000
                easing.type: Easing.Linear
                loops: Animation.Infinite
                from: 0
                to: 360
            }
        }

        StyledText {
            anchors.centerIn: parent
            color: Colors.colOnTertiaryContainer
            text: DateTimeService.time
            font: Fonts.request("numbers", 38)
        }
    }

    Item {
        id: lockShape
        implicitHeight: children[0].implicitHeight
        implicitWidth: children[0].implicitWidth
        z: 999

        anchors {
            right: shape.right
            bottom: shape.bottom
            margins: Padding.massive
        }

        Shape {
            shape: MaterialShape.Shape.Cookie6Sided
            implicitSize: 140
            color: Colors.colSecondary
            anchors.centerIn: parent

            RotationAnimation on rotation {
                running: true
                duration: 12000
                easing.type: Easing.Linear
                loops: Animation.Infinite
                from: 0
                to: 360
            }
        }
        Symbol {
            color: Colors.colOnSecondary
            anchors.centerIn: parent
            icon: "lock"
            iconSize: 50
        }
    }

    Shape {
        id: shape
        anchors.centerIn: parent
        implicitSize: 550
        Shape {
            anchors.centerIn: parent
            clip: true
            StyledImage {
                anchors.fill: parent
                source: SysInfoService?.userPfp
            }
            layer.enabled: true
            layer.effect: MultiEffect {
                maskEnabled: true
                maskSource: Shape {}
            }
        }
        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 50
            shadowColor: "white"
        }
    }

    CLayout {
        anchors {
            top: shape.bottom
            horizontalCenter: shape.horizontalCenter
            topMargin: Padding.large
        }

        LockControls {
            Layout.alignment: Qt.AlignHCenter
        }

        StyledText {
            id: greets
            text: "Welcome Back " + TextUtils.capitalizeFirstLetter(SysInfoService.username) + "!"
            color: Colors.colOnLayer0
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font: Fonts.request("title", Fonts.sizes.title * 1.25)
        }
    }
    component Shape: MaterialShape {
        _shape: "Cookie9Sided"
        implicitSize: 450
        color: Colors.colSecondaryContainer
    }
}
