import QtQuick
import qs.common
import qs.common.widgets


StyledRect {
    id: root
    color: Colors.colLayer1

    property var nodes: [
        {
            x: 0,
            y: 0
        },
        {
            x: 1,
            y: 1
        }
    ]
    property real nodeRadius: 7
    property real hitRadius: 16
    property var curveValues: []
    property real previewDuration: 900
    property real previewT: 0
    property bool previewRunning: false

    onNodesChanged: {
        canvas.requestPaint();
        root.computeSamples();
    }

    onPreviewTChanged: canvas.requestPaint()

    Component.onCompleted: {
        root.nodes = root.nodes.slice().sort(function (a, b) {
            return a.x - b.x;
        });
        root.computeSamples();
    }

    NumberAnimation {
        id: previewAnim
        target: root
        property: "previewT"
        from: 0
        to: 1
        duration: root.previewDuration
        easing.type: Easing.Linear
        onStarted: root.previewRunning = true
        onStopped: root.previewRunning = false
    }

    function playPreview() {
        previewAnim.stop();
        root.previewT = 0;
        previewAnim.start();
    }

    function stopPreview() {
        previewAnim.stop();
        root.previewRunning = false;
    }

    function nodeToPixel(node, w, h) {
        var pad = root.nodeRadius + 4;
        var px = pad + node.x * (w - pad * 2);
        var py = h - pad - node.y * (h - pad * 2);
        return {
            x: px,
            y: py
        };
    }

    function pixelToNode(px, py, w, h) {
        var pad = root.nodeRadius + 4;
        var nx = (px - pad) / (w - pad * 2);
        var ny = (h - pad - py) / (h - pad * 2);
        nx = Math.max(0, Math.min(1, nx));
        ny = Math.max(0, Math.min(1, ny));
        return {
            x: nx,
            y: ny
        };
    }

    function hitTestNode(px, py, w, h) {
        var list = root.nodes;
        for (var i = 0; i < list.length; i++) {
            var p = root.nodeToPixel(list[i], w, h);
            var dx = p.x - px;
            var dy = p.y - py;
            if (Math.sqrt(dx * dx + dy * dy) <= root.hitRadius)
                return i;
        }
        return -1;
    }

    function evaluateAt(x) {
        var list = root.nodes;
        if (x <= list[0].x)
            return list[0].y;
        if (x >= list[list.length - 1].x)
            return list[list.length - 1].y;

        var j = 0;
        for (var i = 0; i < list.length - 1; i++) {
            if (x >= list[i].x && x <= list[i + 1].x) {
                j = i;
                break;
            }
        }

        var p0 = j > 0 ? list[j - 1] : list[j];
        var p1 = list[j];
        var p2 = list[j + 1];
        var p3 = j < list.length - 2 ? list[j + 2] : list[j + 1];

        var cp1y = p1.y + (p2.y - p0.y) / 6;
        var cp2y = p2.y - (p3.y - p1.y) / 6;

        var span = p2.x - p1.x;
        var t = span > 0 ? (x - p1.x) / span : 0;
        var mt = 1 - t;

        return mt * mt * mt * p1.y + 3 * mt * mt * t * cp1y + 3 * mt * t * t * cp2y + t * t * t * p2.y;
    }

    function computeSamples() {
        var list = root.nodes;
        var out = [];
        for (var i = 0; i < list.length; i++) {
            out.push(Math.round(list[i].y * 100) / 100);
        }
        root.curveValues = out;
    }

    function setNodesFrom(values) {
        if (!values || values.length < 2)
            return;
        var last = values.length - 1;
        var out = [];
        for (var i = 0; i <= last; i++) {
            out.push({
                x: i / last,
                y: values[i]
            });
        }
        root.nodes = out;
    }

    function drawGrid(ctx, w, h) {
        var pad = root.nodeRadius + 4;
        ctx.strokeStyle = Colors.methods.transparentize(Colors.colOutline, 0.25);
        ctx.lineWidth = 1;
        var divisions = 4;
        for (var i = 0; i <= divisions; i++) {
            var x = pad + (w - pad * 2) * (i / divisions);
            ctx.beginPath();
            ctx.moveTo(x, pad);
            ctx.lineTo(x, h - pad);
            ctx.stroke();
            var y = pad + (h - pad * 2) * (i / divisions);
            ctx.beginPath();
            ctx.moveTo(pad, y);
            ctx.lineTo(w - pad, y);
            ctx.stroke();
        }
    }

    function drawCurve(ctx, w, h) {
        var list = root.nodes;
        var pts = [];
        for (var i = 0; i < list.length; i++)
            pts.push(root.nodeToPixel(list[i], w, h));

        ctx.strokeStyle = Colors.colPrimary;
        ctx.lineWidth = 2.5;
        ctx.beginPath();
        ctx.moveTo(pts[0].x, pts[0].y);

        for (var j = 0; j < pts.length - 1; j++) {
            var p0 = j > 0 ? pts[j - 1] : pts[j];
            var p1 = pts[j];
            var p2 = pts[j + 1];
            var p3 = j < pts.length - 2 ? pts[j + 2] : pts[j + 1];

            var cp1x = p1.x + (p2.x - p0.x) / 6;
            var cp1y = p1.y + (p2.y - p0.y) / 6;
            var cp2x = p2.x - (p3.x - p1.x) / 6;
            var cp2y = p2.y - (p3.y - p1.y) / 6;

            ctx.bezierCurveTo(cp1x, cp1y, cp2x, cp2y, p2.x, p2.y);
        }
        ctx.stroke();
    }

    function drawNodes(ctx, w, h) {
        var list = root.nodes;
        for (var i = 0; i < list.length; i++) {
            var p = root.nodeToPixel(list[i], w, h);
            var isActive = i === mouseArea.activeIndex;
            ctx.beginPath();
            ctx.arc(p.x, p.y, isActive ? root.nodeRadius + 3 : root.nodeRadius, 0, Math.PI * 2);
            ctx.fillStyle = isActive ? Colors.colPrimary : Colors.colLayer1;
            ctx.fill();
            ctx.lineWidth = 2;
            ctx.strokeStyle = Colors.colPrimary;
            ctx.stroke();
        }
    }

    function drawPlayhead(ctx, w, h) {
        var p = root.nodeToPixel({
            x: root.previewT,
            y: root.evaluateAt(root.previewT)
        }, w, h);

        ctx.beginPath();
        ctx.moveTo(p.x, 4);
        ctx.lineTo(p.x, h - 4);
        ctx.strokeStyle = Colors.methods.transparentize(Colors.colOutline, 0.5);
        ctx.lineWidth = 1;
        ctx.stroke();

        ctx.beginPath();
        ctx.arc(p.x, p.y, root.nodeRadius - 1, 0, Math.PI * 2);
        ctx.fillStyle = Colors.colPrimary;
        ctx.fill();
    }

    Item {
        anchors.fill: parent
        anchors.margins: 16

        Canvas {
            id: canvas
            anchors.fill: parent

            onPaint: {
                var ctx = getContext("2d");
                ctx.clearRect(0, 0, width, height);
                root.drawGrid(ctx, width, height);
                root.drawCurve(ctx, width, height);
                root.drawNodes(ctx, width, height);
                if (root.previewRunning)
                    root.drawPlayhead(ctx, width, height);
            }

            Component.onCompleted: requestPaint()
        }

        MouseArea {
            id: mouseArea
            z: 999
            anchors.fill: canvas
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            property int activeIndex: -1

            onPressed: mouse => {
                var idx = root.hitTestNode(mouse.x, mouse.y, width, height);
                if (mouse.button === Qt.RightButton) {
                    if (idx > 0 && idx < root.nodes.length - 1 && root.nodes.length > 2) {
                        var list = root.nodes;
                        list.splice(idx, 1);
                        root.nodes = list;
                        canvas.requestPaint();
                        root.computeSamples();
                    }
                    return;
                }
                activeIndex = idx;
            }

            onPositionChanged: mouse => {
                if (activeIndex < 0)
                    return;
                var pt = root.pixelToNode(mouse.x, mouse.y, width, height);
                var list = root.nodes;
                if (activeIndex === 0) {
                    pt.x = 0;
                } else if (activeIndex === list.length - 1) {
                    pt.x = 1;
                } else {
                    var minX = list[activeIndex - 1].x + 0.01;
                    var maxX = list[activeIndex + 1].x - 0.01;
                    pt.x = Math.max(minX, Math.min(maxX, pt.x));
                }
                list[activeIndex] = pt;
                root.nodes = list;
                canvas.requestPaint();
                root.computeSamples();
            }

            onReleased: mouse => {
                activeIndex = -1;
            }

            onDoubleClicked: mouse => {
                var pt = root.pixelToNode(mouse.x, mouse.y, width, height);
                var list = root.nodes;
                var insertAt = list.length;
                for (var i = 0; i < list.length; i++) {
                    if (pt.x < list[i].x) {
                        insertAt = i;
                        break;
                    }
                }
                if (insertAt > 0 && insertAt < list.length) {
                    list.splice(insertAt, 0, pt);
                    root.nodes = list;
                    canvas.requestPaint();
                    root.computeSamples();
                }
            }
        }
    }
}
