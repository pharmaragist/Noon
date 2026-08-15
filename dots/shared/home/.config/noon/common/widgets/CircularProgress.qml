

import QtQuick
import QtQuick.Shapes
import qs.common




Item {
    id: root

    property int implicitSize: 30
    property int lineWidth: 2
    property real value: 0
    property color colPrimary: Colors.m3.m3onSecondaryContainer
    property color colSecondary: Colors.colSecondaryContainer
    property real gapDistance: 4 
    property bool fill: false
    property int fillOverflow: 2
    property int animationDuration: 1000
    property var easingType: Easing.OutCubic
    property bool enableAnimation: true
    property real degree: Math.min(value, 1) * 360
    property real centerX: root.width / 2
    property real centerY: root.height / 2
    property real arcRadius: root.implicitSize / 2 - root.lineWidth / 2
    property real gapAngle: (gapDistance / (2 * Math.PI * arcRadius)) * 360
    property real startAngle: -90
    property bool sperm: false
    property bool animateSperm: true
    property real spermAmplitude: sperm ? 1.6 : 0 
    property real wavelength: 15 
    property real spermFps: 60

    width: implicitSize
    height: implicitSize

    Loader {
        active: root.fill
        anchors.fill: parent

        sourceComponent: Rectangle {
            radius: Rounding.full
            color: root.colSecondary
        }
    }

    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.smooth: true
        preferredRendererType: Shape.CurveRenderer

        
        ShapePath {
            id: secondaryPath

            strokeColor: root.colSecondary
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.degree === 0 ? root.startAngle : root.startAngle + root.degree + root.gapAngle
                sweepAngle: root.degree === 0 ? 360 : 360 - root.degree - 2 * root.gapAngle
            }
        }

        
        ShapePath {
            id: primaryPath

            strokeColor: root.sperm ? "transparent" : root.colPrimary
            strokeWidth: root.lineWidth
            capStyle: ShapePath.RoundCap
            fillColor: "transparent"

            PathAngleArc {
                centerX: root.centerX
                centerY: root.centerY
                radiusX: root.arcRadius
                radiusY: root.arcRadius
                startAngle: root.startAngle
                sweepAngle: root.degree
            }
        }
    }

    Canvas {
        id: wavyCanvas
        anchors.fill: parent
        visible: root.sperm

        onPaint: {
            var ctx = getContext("2d");
            ctx.clearRect(0, 0, width, height);
            if (root.degree <= 0)
                return;

            var cx = root.centerX;
            var cy = root.centerY;
            var r = root.arcRadius;
            var amp = root.spermAmplitude;
            var wl = root.wavelength;
            var startRad = root.startAngle * Math.PI / 180;
            var sweepRad = root.degree * Math.PI / 180;
            var phase = Date.now() / 400;

            ctx.strokeStyle = root.colPrimary;
            ctx.lineWidth = root.lineWidth;
            ctx.lineCap = "round";
            ctx.beginPath();

            var first = true;
            var steps = Math.max(2, Math.ceil(sweepRad * r / 1));
            for (var i = 0; i <= steps; i++) {
                var t = i / steps;
                var angle = startRad + t * sweepRad;
                var waveR = r + amp * Math.sin(2 * Math.PI * t * sweepRad * r / wl + phase);
                var x = cx + waveR * Math.cos(angle);
                var y = cy + waveR * Math.sin(angle);
                if (first) {
                    ctx.moveTo(x, y);
                    first = false;
                } else {
                    ctx.lineTo(x, y);
                }
            }
            ctx.stroke();
        }

        Connections {
            target: root
            function onDegreeChanged() {
                wavyCanvas.requestPaint();
            }
            function onColPrimaryChanged() {
                wavyCanvas.requestPaint();
            }
        }

        Timer {
            interval: 1000 / root.spermFps
            running: root.animateSperm && root.sperm
            repeat: root.sperm
            onTriggered: wavyCanvas.requestPaint()
        }
    }

    Behavior on degree {
        enabled: root.enableAnimation

        Anim {
            duration: root.animationDuration
            easing.type: root.easingType
        }
    }
}
