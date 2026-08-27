import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.services




ProgressBar {
    id: root

    property var colors: Colors
    property real valueBarWidth: 120
    property real valueBarHeight: 4
    property real highlightHeight: valueBarHeight
    property real valueBarGap: 4
    property color indicatorColor: colors?.colOnLayer0
    property color highlightColor: colors?.colPrimary ?? "#685496"
    property color trackColor: colors?.colPrimaryContainer ?? "#F1D3F9"
    property bool sperm: false
    property bool animateSperm: true
    property real spermAmplitude: sperm ? 3 : 0
    property real wavelength: 40
    property real trackHeight: Math.max(sperm ? highlightHeight + spermAmplitude * 2 : highlightHeight, valueBarHeight)
    property real spermFps: 60
    property real rounding: Rounding.full
    property bool showProgressIndicator: true
    property bool vertical: false
    property bool showDot: false
    property bool animateOnStart: true
    Behavior on spermAmplitude {
        Anim {}
    }

    Behavior on value {
        Anim {}
    }

    Anim on value {
        from: 0
        to: value
        duration: root.animateOnStart ? Animations.durations.massive: 0
    }

    Anim on spermAmplitude {
        from: 0
        to: spermAmplitude
    }

    background: Rectangle {
        anchors.fill: parent
        color: "transparent"
        radius: root.rounding
        implicitHeight: vertical ? valueBarWidth : trackHeight
        implicitWidth: vertical ? trackHeight : valueBarWidth
    }

    contentItem: Item {
        anchors.fill: parent

        Canvas {
            id: wavyFill
            z: 1

            height: vertical ? parent.height : parent.height + root.spermAmplitude * 2
            width: vertical ? parent.width + root.spermAmplitude * 2 : parent.width
            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                var progress = root.visualPosition;
                if (vertical) {

                    var fillHeight = progress * parent.height;
                    if (root.showDot) {
                        var dotSize = root.valueBarHeight / 1.75;
                        fillHeight = Math.min(fillHeight, parent.height - 6 - dotSize);
                    }
                    var amplitude = root.spermAmplitude;
                    var wavelength = root.wavelength;
                    var phase = Date.now() / 400;
                    var centerX = width / 2;
                    ctx.strokeStyle = root.highlightColor;
                    ctx.lineWidth = root.highlightHeight;
                    ctx.lineCap = root.rounding === 0 ? "butt" : "round";
                    ctx.beginPath();
                    for (var y = parent.height - ctx.lineWidth / 2; y >= parent.height - fillHeight; y -= 1) {
                        var waveX = centerX + amplitude * Math.sin(2 * Math.PI * (parent.height - y) / wavelength + phase);
                        if (y === parent.height - ctx.lineWidth / 2)
                            ctx.moveTo(waveX, y);
                        else
                            ctx.lineTo(waveX, y);
                    }
                    ctx.stroke();
                } else {

                    var fillWidth = progress * width;
                    if (root.showDot) {
                        var dotSize = root.valueBarHeight / 1.75;
                        fillWidth = Math.min(fillWidth, width - 6 - dotSize);
                    }
                    var amplitude = root.spermAmplitude;
                    var wavelength = root.wavelength;
                    var phase = Date.now() / 400;
                    var centerY = height / 2;
                    ctx.strokeStyle = root.highlightColor;
                    ctx.lineWidth = root.highlightHeight;
                    ctx.lineCap = "round";
                    ctx.beginPath();
                    for (var x = ctx.lineWidth / 2; x <= fillWidth; x += 1) {
                        var waveY = centerY + amplitude * Math.sin(2 * Math.PI * x / wavelength + phase);
                        if (x === 0)
                            ctx.moveTo(x, waveY);
                        else
                            ctx.lineTo(x, waveY);
                    }
                    ctx.stroke();
                }
            }

            anchors {
                left: parent.left
                right: parent.right
                verticalCenter: vertical ? undefined : parent.verticalCenter
                top: vertical ? parent.top : undefined
                bottom: vertical ? parent.bottom : undefined
            }

            Connections {
                function onValueChanged() {
                    wavyFill.requestPaint();
                }

                function onHighlightColorChanged() {
                    wavyFill.requestPaint();
                }

                function onVerticalChanged() {
                    wavyFill.requestPaint();
                }

                target: root
            }

            Timer {
                interval: 1000 / root.spermFps
                running: root.animateSperm
                repeat: root.sperm
                onTriggered: wavyFill.requestPaint()
            }
        }

        Rectangle {
            id: gapIndicator
            visible: root.showProgressIndicator
            z: 9999
            radius: root.rounding
            color: root.highlightColor

            implicitWidth: 4
            implicitHeight: 4

            anchors.centerIn: parent
            anchors.horizontalCenterOffset: vertical ? 0 : (-parent.width / 2) + (root.visualPosition * parent.width)
            anchors.verticalCenterOffset: !vertical ? 0 : (parent.height / 2) - (root.visualPosition * parent.height)
        }
        Rectangle {
            id: remaining

            radius: root.rounding
            color: root.trackColor
            visible: !vertical
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: (1 - root.visualPosition) * parent.width - valueBarGap
            height: root.valueBarHeight
        }

        Rectangle {

            radius: root.rounding
            color: root.trackColor
            visible: vertical
            width: root.valueBarHeight
            height: (1 - root.visualPosition) * parent.height - valueBarGap

            anchors {
                horizontalCenter: parent.horizontalCenter
                top: parent.top
            }
        }

        Rectangle {
            visible: root.showDot

            anchors.right: vertical ? undefined : parent.right
            anchors.verticalCenter: vertical ? undefined : parent.verticalCenter
            anchors.rightMargin: vertical ? 0 : 6
            anchors.horizontalCenter: vertical ? parent.horizontalCenter : undefined
            anchors.top: vertical ? parent.top : undefined
            anchors.topMargin: vertical ? 6 : 0
            width: valueBarHeight / 1.75
            height: width
            radius: root.rounding
            color: root.highlightColor
        }
    }
}
