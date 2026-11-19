import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.services
import qs.common.widgets
import qs.common.utils

Item {
    id: root
    anchors.fill: parent

    readonly property var clock: Mem.states.desktop.clock
    readonly property string fontFamily: Mem.options.desktop.clock.font
    readonly property real pad: Padding.massive
    readonly property real dockMargin: Padding.large
    readonly property real overlap: 0.3
    readonly property real gap: 0.02
    readonly property real minScale: 0.2
    readonly property real maxScale: 8
    readonly property real minStretch: 0.3
    readonly property real maxStretch: 2.8

    property bool editMode: false
    property real previewScale: -1
    property real previewStretchX: -1
    property real previewStretchY: -1
    property real dragX: -1
    property real dragY: -1
    property real sScale: 1
    property real sSX: 1
    property real sSY: 1
    property real sCW: 1
    property real sCH: 1

    readonly property bool docked: clock.docked ?? true
    readonly property bool horizontal: clock.horizontal ?? false
    readonly property string digits: String(DateTimeService.hour).padStart(2, "0") + String(DateTimeService.minute).padStart(2, "0")

    readonly property real digitWidth: probe.implicitWidth > 0 ? probe.implicitWidth : probe.implicitHeight / 3
    readonly property real colonWidth: probeColon.implicitWidth > 0 ? probeColon.implicitWidth : digitWidth / 2
    readonly property real unitW: (horizontal ? digitWidth * 4 + colonWidth + 400 * gap : digitWidth * 2) || 1
    readonly property real unitH: (horizontal ? probe.implicitHeight : probe.implicitHeight * 2 - 100 * overlap) || 1
    readonly property real aspect: unitW > 0 && unitH > 0 ? unitW / unitH : 0
    readonly property real availW: width - pad * 2
    readonly property real availH: height - pad * 2

    readonly property real liveScale: previewScale > 0 ? previewScale : (clock?.scale || 1)
    readonly property real liveStretchX: clamp(previewStretchX > 0 ? previewStretchX : (clock.stretchX ?? 1), minStretch, stretchLimit(availW, unitW))
    readonly property real liveStretchY: clamp(previewStretchY > 0 ? previewStretchY : (clock.stretchY ?? 1), minStretch, stretchLimit(availH, unitH))
    readonly property real baseScale: Math.max(1e-6, clock?.scale || 1)
    readonly property real scaleX: liveScale / baseScale * liveStretchX
    readonly property real scaleY: liveScale / baseScale * liveStretchY

    readonly property bool dragging: dragX >= 0
    readonly property bool busy: dragging || previewScale > 0 || previewStretchX > 0 || previewStretchY > 0
    readonly property real maxFrameX: Math.max(0, width - frame.width)
    readonly property real maxFrameY: Math.max(0, height - frame.height)
    readonly property real restX: docked ? dockMargin : clamp(width * (clock.x ?? 0), 0, maxFrameX)
    readonly property real restY: docked ? Math.max(0, maxFrameY - dockMargin) : clamp(height * (clock.y ?? 0), 0, maxFrameY)

    Connections {
        target: root.clock

        function onFitXChanged() {
            fitTimer.restart();
        }
        function onFitYChanged() {
            fitTimer.restart();
        }
        function onFitWChanged() {
            fitTimer.restart();
        }
        function onFitHChanged() {
            fitTimer.restart();
        }
    }

    Timer {
        id: fitTimer

        interval: 50
        onTriggered: root.applyFit()
    }

    onAspectChanged: {
        Globals.clockAspect = aspect;
        applyFit();
    }
    onWidthChanged: applyFit()
    onHeightChanged: applyFit()
    Component.onCompleted: applyFit()

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(v, hi));
    }

    function stretchLimit(avail, unit) {
        return Math.max(minStretch, Math.min(maxStretch, avail / (unit * liveScale)));
    }

    function applyFit() {
        if (clock.fitW == null || clock.fitH == null || width <= 0 || height <= 0)
            return;
        const key = [clock.fitX, clock.fitY, clock.fitW, clock.fitH].join();
        if (key === clock.fitDone)
            return;
        if (!(aspect > 0.2 && aspect < 5) || clock.fitW <= 0 || clock.fitH <= 0)
            return;
        const fitAspect = (clock.fitW * width) / (clock.fitH * height);
        const fitWidth = fitAspect > 0.2 && fitAspect < 5 ? clock.fitW : clock.fitH * height * aspect / width;
        const s = clamp(Math.min(fitWidth * width / unitW, clock.fitH * height / unitH), minScale, maxScale);
        const fw = unitW * s + pad * 2;
        const fh = unitH * s + pad * 2;
        clock.scale = s;
        clock.stretchX = 1;
        clock.stretchY = 1;
        clock.x = clamp((clock.fitX + fitWidth / 2) * width - fw / 2, 0, Math.max(0, width - fw)) / width;
        clock.y = clamp((clock.fitY + clock.fitH / 2) * height - fh / 2, 0, Math.max(0, height - fh)) / height;
        clock.placed = true;
        clock.docked = false;
        clock.fitDone = key;
    }

    function touch() {
        editTimer.restart();
    }

    function savePosition(px, py) {
        if (width <= 0 || height <= 0)
            return;
        clock.x = px / width;
        clock.y = py / height;
        clock.placed = true;
    }

    function setDocked(v) {
        if (!v && !clock.placed)
            savePosition(frame.x, frame.y);
        clock.docked = v;
    }

    function beginResize() {
        sScale = liveScale;
        sSX = liveStretchX;
        sSY = liveStretchY;
        sCW = frame.width - pad * 2;
        sCH = frame.height - pad * 2;
    }

    function commitResize() {
        if (previewScale > 0)
            clock.scale = previewScale;
        if (previewStretchX > 0)
            clock.stretchX = previewStretchX;
        if (previewStretchY > 0)
            clock.stretchY = previewStretchY;
        previewScale = previewStretchX = previewStretchY = -1;
    }

    function resetAll() {
        clock.scale = 1;
        clock.stretchX = 1;
        clock.stretchY = 1;
        clock.docked = false;
    }

    Timer {
        id: editTimer

        interval: 5000
        running: root.editMode && !root.busy
        onTriggered: root.editMode = false
    }

    StyledText {
        id: probe

        visible: false
        text: "0"
        font.pixelSize: 100
        font.family: root.fontFamily
    }

    StyledText {
        id: probeColon

        visible: false
        text: ":"
        font.pixelSize: 100
        font.family: root.fontFamily
    }

    component Grip: Rectangle {
        id: grip

        property alias cursorShape: area.cursorShape

        signal started
        signal moved(real dx, real dy)
        signal finished
        signal reset

        color: Colors.colOnBackground
        anchors.margins: 6

        MouseArea {
            id: area

            property point origin

            anchors.fill: parent
            anchors.margins: -8
            preventStealing: true

            onPressed: m => {
                origin = mapToGlobal(m.x, m.y);
                grip.started();
            }
            onPositionChanged: m => {
                if (!pressed)
                    return;
                const p = mapToGlobal(m.x, m.y);
                grip.moved(p.x - origin.x, p.y - origin.y);
            }
            onReleased: grip.finished()
            onCanceled: grip.finished()
            onDoubleClicked: grip.reset()
        }
    }

    component Pill: Rectangle {
        id: pill

        property string text: ""
        property bool filled: false

        signal clicked

        Layout.fillWidth: true
        implicitWidth: label.implicitWidth + 28
        implicitHeight: label.implicitHeight + 16
        radius: height / 2
        color: filled ? Colors.colPrimary : Qt.alpha(Colors.colOnSecondaryContainer, 0.12)

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        StyledText {
            id: label

            anchors.centerIn: parent
            text: pill.text
            color: pill.filled ? Colors.colSecondaryContainer : Colors.colOnSecondaryContainer
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: pill.clicked()
        }
    }

    component SectionLabel: RowLayout {
        id: head

        property string title: ""
        property string value: ""

        Layout.fillWidth: true
        spacing: 8

        StyledText {
            text: head.title
            font: Fonts.request("main", 14)
            color: Colors.colOnSecondaryContainer
        }

        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            elide: Text.ElideRight
            text: head.value
            font: Fonts.request("main", 12)
            color: Qt.alpha(Colors.colOnSecondaryContainer, 0.7)
        }
    }

    component ToggleTile: Rectangle {
        id: tile

        property string label: ""
        property string hint: ""
        property bool checked: false

        signal toggled

        Layout.fillWidth: true
        implicitHeight: 64
        radius: 20
        color: Qt.alpha(Colors.colOnSecondaryContainer, 0.08)

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.toggled()
        }

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: 16
            anchors.rightMargin: 12
            spacing: 12

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2

                StyledText {
                    text: tile.label
                    color: Colors.colOnSecondaryContainer
                }

                StyledText {
                    visible: text.length > 0
                    text: tile.hint
                    font: Fonts.request("main", 12)
                    color: Qt.alpha(Colors.colOnSecondaryContainer, 0.7)
                }
            }

            Item {
                implicitWidth: toggle.implicitWidth * toggle.scale
                implicitHeight: toggle.implicitHeight * toggle.scale

                StyledSwitch {
                    id: toggle

                    scale: 0.75
                    transformOrigin: Item.TopLeft
                    checked: tile.checked
                    onToggled: tile.toggled()
                }
            }
        }
    }

    component LayoutTile: Rectangle {
        id: tile

        property string label: ""
        property bool selected: false
        property bool horizontalGlyph: false
        readonly property color ink: selected ? Colors.colSecondaryContainer : Colors.colOnSecondaryContainer

        signal clicked

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        implicitHeight: 84
        radius: selected ? 30 : 18
        color: selected ? Colors.colPrimary : Qt.alpha(Colors.colOnSecondaryContainer, 0.08)

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on radius {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutBack
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        ColumnLayout {
            anchors.centerIn: parent
            spacing: 8

            Item {
                Layout.alignment: Qt.AlignHCenter
                implicitWidth: 48
                implicitHeight: 34

                Grid {
                    anchors.centerIn: parent
                    visible: !tile.horizontalGlyph
                    columns: 2
                    spacing: 3

                    Repeater {
                        model: 4

                        Rectangle {
                            width: 14
                            height: 14
                            radius: 4
                            color: tile.ink
                        }
                    }
                }

                Row {
                    anchors.centerIn: parent
                    visible: tile.horizontalGlyph
                    spacing: 3

                    Repeater {
                        model: 5

                        Rectangle {
                            required property int index

                            width: index === 2 ? 3 : 7
                            height: 14
                            radius: 2
                            opacity: index === 2 ? 0.5 : 1
                            color: tile.ink
                        }
                    }
                }
            }

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: tile.label
                font: Fonts.request("main", 13)
                color: tile.ink
            }
        }
    }

    component FontTile: Rectangle {
        id: tile

        property string family: ""
        property bool selected: false
        readonly property color ink: selected ? Colors.colSecondaryContainer : Colors.colOnSecondaryContainer

        signal clicked

        implicitWidth: 76
        implicitHeight: 88
        radius: selected ? 28 : 18
        color: selected ? Colors.colPrimary : Qt.alpha(Colors.colOnSecondaryContainer, 0.08)

        Behavior on color {
            ColorAnimation {
                duration: 150
            }
        }

        Behavior on radius {
            NumberAnimation {
                duration: 250
                easing.type: Easing.OutBack
            }
        }

        MouseArea {
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 12
            spacing: 4

            StyledText {
                Layout.alignment: Qt.AlignHCenter
                text: "12"
                font.family: tile.family
                font.pixelSize: 30
                color: tile.ink
            }

            StyledText {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: tile.family
                font: Fonts.request("main", 10)
                color: tile.ink
            }
        }
    }

    Rectangle {
        id: frame

        x: root.dragging ? root.dragX : root.restX
        y: root.dragging ? root.dragY : root.restY
        width: grid.implicitWidth * root.scaleX + root.pad * 2
        height: grid.implicitHeight * root.scaleY + root.pad * 2
        color: "transparent"
        border.color: Colors.colOnBackground
        border.width: root.editMode ? 4 : 0
        radius: Rounding.silly

        Behavior on x {
            enabled: !root.dragging
            Anim {}
        }

        Behavior on y {
            enabled: !root.dragging
            Anim {}
        }

        MouseArea {
            id: dragArea

            property bool grabbing: false
            property point grab

            anchors.fill: parent
            acceptedButtons: Qt.LeftButton | Qt.RightButton
            cursorShape: !root.editMode || root.docked ? Qt.ArrowCursor : (grabbing ? Qt.ClosedHandCursor : Qt.OpenHandCursor)

            onPressed: m => {
                root.touch();
                if (m.button !== Qt.LeftButton || !root.editMode || root.docked)
                    return;
                const p = mapToItem(root, m.x, m.y);
                grab = Qt.point(p.x - frame.x, p.y - frame.y);
                grabbing = true;
            }
            onPositionChanged: m => {
                if (!grabbing)
                    return;
                const p = mapToItem(root, m.x, m.y);
                root.dragX = root.clamp(p.x - grab.x, 0, root.maxFrameX);
                root.dragY = root.clamp(p.y - grab.y, 0, root.maxFrameY);
            }
            onReleased: finishDrag()
            onCanceled: finishDrag()
            onClicked: m => {
                if (m.button === Qt.RightButton)
                    root.editMode = false;
            }
            onDoubleClicked: m => {
                if (m.button === Qt.LeftButton)
                    root.editMode = true;
            }

            function finishDrag() {
                if (grabbing && root.dragging)
                    root.savePosition(root.dragX, root.dragY);
                grabbing = false;
                root.dragX = -1;
                root.dragY = -1;
            }
        }

        GridLayout {
            id: grid

            readonly property real px: 100 * (root.clock?.scale || 1)

            x: root.pad
            y: root.pad
            columns: root.horizontal ? 5 : 2
            rowSpacing: -px * root.overlap
            columnSpacing: root.horizontal ? px * root.gap : 0
            transform: Scale {
                xScale: root.scaleX
                yScale: root.scaleY
            }

            Repeater {
                model: 5

                StyledText {
                    required property int index
                    readonly property int slot: index > 2 ? index - 1 : index

                    visible: index !== 2 || root.horizontal
                    text: index === 2 ? ":" : root.digits[slot]
                    renderType: Text.CurveRendering
                    font.pixelSize: grid.px
                    font.family: root.fontFamily
                    color: index === 2 ? Colors.colOnBackground : ((Math.floor(slot / 2) + slot) % 2 === 0 ? Colors.colPrimary : Colors.colSecondaryContainer)
                }
            }
        }

        Grip {
            visible: root.editMode
            width: 10
            height: 36
            radius: width / 2
            cursorShape: Qt.SizeHorCursor
            anchors.verticalCenter: parent.verticalCenter
            anchors.right: parent.right

            onStarted: {
                root.beginResize();
                root.previewStretchX = root.sSX;
            }
            onMoved: dx => root.previewStretchX = root.clamp(root.sSX * (root.sCW + dx) / root.sCW, root.minStretch, root.stretchLimit(root.availW, root.unitW))
            onFinished: root.commitResize()
            onReset: {
                root.clock.stretchX = 1;
                root.touch();
            }
        }

        Grip {
            visible: root.editMode
            width: 36
            height: 10
            radius: height / 2
            cursorShape: Qt.SizeVerCursor
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom

            onStarted: {
                root.beginResize();
                root.previewStretchY = root.sSY;
            }
            onMoved: (dx, dy) => root.previewStretchY = root.clamp(root.sSY * (root.sCH + dy) / root.sCH, root.minStretch, root.stretchLimit(root.availH, root.unitH))
            onFinished: root.commitResize()
            onReset: {
                root.clock.stretchY = 1;
                root.touch();
            }
        }

        Grip {
            visible: root.editMode
            width: 22
            height: 22
            radius: width / 2
            cursorShape: Qt.SizeFDiagCursor
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            onStarted: {
                root.beginResize();
                root.previewScale = root.sScale;
            }
            onMoved: dx => {
                const limit = Math.min(root.maxScale, root.availW / (root.unitW * root.sSX), root.availH / (root.unitH * root.sSY));
                root.previewScale = root.clamp(root.sScale * (root.sCW + dx) / root.sCW, root.minScale, Math.max(limit, root.minScale));
            }
            onFinished: root.commitResize()
        }
    }

    StyledRect {
        id: card

        readonly property real margin: Padding.verylarge
        readonly property bool fitsBelow: frame.y + frame.height + 10 + height <= root.height

        visible: root.editMode && !root.busy
        color: Colors.colSecondaryContainer
        radius: Rounding.large
        width: 300 + margin * 2
        height: options.implicitHeight + margin * 2
        x: root.clamp(frame.x + (frame.width - width) / 2, 0, Math.max(0, root.width - width))
        y: Math.max(0, fitsBelow ? frame.y + frame.height + 10 : frame.y - height - 10)

        ColumnLayout {
            id: options

            anchors.fill: parent
            anchors.margins: card.margin
            spacing: 16

            RowLayout {
                Layout.fillWidth: true
                spacing: 12

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2

                    StyledText {
                        text: "Clock"
                        font: Fonts.request("main", 20)
                        color: Colors.colOnSecondaryContainer
                    }

                    StyledText {
                        text: "Drag to move, pull the edges to resize"
                        font: Fonts.request("main", 12)
                        color: Qt.alpha(Colors.colOnSecondaryContainer, 0.7)
                    }
                }

                Pill {
                    Layout.fillWidth: false
                    text: "Done"
                    filled: true
                    onClicked: root.editMode = false
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SectionLabel {
                    title: "Layout"
                    value: root.horizontal ? "Horizontal" : "Vertical"
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8

                    LayoutTile {
                        label: "Vertical"
                        selected: !root.horizontal
                        horizontalGlyph: false
                        onClicked: {
                            root.clock.horizontal = false;
                            root.touch();
                        }
                    }

                    LayoutTile {
                        label: "Horizontal"
                        selected: root.horizontal
                        horizontalGlyph: true
                        onClicked: {
                            root.clock.horizontal = true;
                            root.touch();
                        }
                    }
                }
            }

            ToggleTile {
                label: "Docked"
                hint: "Pinned to the bottom left"
                checked: root.docked
                onToggled: {
                    root.setDocked(!root.docked);
                    root.touch();
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8

                SectionLabel {
                    title: "Font"
                    value: root.fontFamily
                }

                ListView {
                    id: fontList

                    Layout.fillWidth: true
                    Layout.preferredHeight: 88
                    orientation: ListView.Horizontal
                    spacing: 8
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds
                    model: Fonts.candidates.display
                    onContentXChanged: root.touch()

                    WheelHandler {
                        onWheel: e => fontList.contentX = root.clamp(fontList.contentX - e.angleDelta.y, 0, Math.max(0, fontList.contentWidth - fontList.width))
                    }

                    delegate: FontTile {
                        required property string modelData

                        family: modelData
                        selected: modelData === root.fontFamily
                        onClicked: {
                            Mem.options.desktop.clock.font = modelData;
                            root.touch();
                        }
                    }
                }
            }

            Pill {
                text: "Reset size and position"
                onClicked: {
                    root.resetAll();
                    root.touch();
                }
            }
        }
    }
}
