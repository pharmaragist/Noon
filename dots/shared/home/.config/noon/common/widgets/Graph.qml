import QtQuick
import qs.common

// Simple sparkline. QtGraphs' GraphsView spams "window doesn't exist" when its
// host layer-shell window is hidden or reloaded, so draw the two dozen points
// ourselves instead.

Canvas {
    id: root

    property color color: Colors.colPrimary
    property real fillOpacity: 0.5
    property real lineWidth: 2

    readonly property QtObject series: QtObject {
        id: seriesData

        property var points: []

        readonly property int count: points.length

        signal changed()

        function clear() {
            points = [];
            changed();
        }

        function append(x, y) {
            points = points.concat([{
                x: x,
                y: y
            }]);
            changed();
        }
    }

    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()
    onFillOpacityChanged: requestPaint()

    Connections {
        target: root.series

        function onChanged() {
            root.requestPaint();
        }
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.clearRect(0, 0, width, height);

        const points = root.series.points;
        if (points.length < 2 || width <= 0 || height <= 0)
            return;

        const pad = Math.max(1, root.lineWidth / 2);
        const plotWidth = width - pad * 2;
        const plotHeight = height - pad * 2;
        const maxIndex = Math.max(1, points.length - 1);

        const xAt = i => pad + plotWidth * i / maxIndex;
        const yAt = value => pad + plotHeight * (1 - Math.max(0, Math.min(1, value)));

        ctx.beginPath();
        ctx.moveTo(xAt(0), yAt(points[0].y));
        for (let i = 1; i < points.length; ++i)
            ctx.lineTo(xAt(i), yAt(points[i].y));
        ctx.lineTo(xAt(points.length - 1), height - pad);
        ctx.lineTo(xAt(0), height - pad);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(root.color.r, root.color.g, root.color.b, root.fillOpacity);
        ctx.fill();

        ctx.beginPath();
        ctx.moveTo(xAt(0), yAt(points[0].y));
        for (let i = 1; i < points.length; ++i)
            ctx.lineTo(xAt(i), yAt(points[i].y));
        ctx.strokeStyle = root.color;
        ctx.lineWidth = root.lineWidth;
        ctx.lineJoin = "round";
        ctx.lineCap = "round";
        ctx.stroke();
    }
}
