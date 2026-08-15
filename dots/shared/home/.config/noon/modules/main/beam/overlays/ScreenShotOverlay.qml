import QtQuick
import Qt5Compat.GraphicalEffects
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root
    anchors.fill: parent
    property bool active: ScreenShotService.isSelecting
    property real startX: 0
    property real startY: 0
    property real endX: 0
    property real endY: 0
    property bool dragging: false
    property bool selectionMade: false
    property int popTick: 0
    readonly property real selX: Math.min(startX, endX)
    readonly property real selY: Math.min(startY, endY)
    readonly property real selW: Math.abs(endX - startX)
    readonly property real selH: Math.abs(endY - startY)
    readonly property real cornerSize: 16
    readonly property real edgePillLength: 28
    readonly property real edgePillThickness: 8
    readonly property real minSize: 12
    readonly property real selRadius: Rounding.huge

    function regionCommitted(x, y, w, h) {
        ScreenShotService.setRegion(x, y, w, h);
        Qt.callLater(() => {
            ScreenShotService.request({
                temp: false,
                region: ScreenShotService.Regions.Part
            });
        });
    }

    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(hi, v));
    }

    onSelectionMadeChanged: {
        if (selectionMade)
            popTick++;
    }

    enabled: active
    visible: active

    Item {
        id: selOverlay
        anchors.fill: parent
        visible: root.dragging || root.selectionMade

        StyledRect {
            id: dimLayer
            anchors.fill: parent
            enableAnimations: false
            visible: false
            color: Colors.m3.m3scrim
        }

        OpacityMask {
            anchors.fill: parent
            opacity: 0.5
            source: dimLayer
            invert: true
            maskSource: Item {
                width: dimLayer.width
                height: dimLayer.height
                Rectangle {
                    x: root.selX
                    y: root.selY
                    width: root.selW
                    height: root.selH
                    radius: root.selRadius
                    color: "white"
                }
            }
        }
    }

    MouseArea {
        id: createArea
        anchors.fill: parent
        cursorShape: Qt.CrossCursor
        enabled: root.active
        onPressed: mouse => {
            root.startX = mouse.x;
            root.startY = mouse.y;
            root.endX = mouse.x;
            root.endY = mouse.y;
            root.dragging = true;
            root.selectionMade = false;
        }
        onPositionChanged: mouse => {
            if (root.dragging) {
                root.endX = mouse.x;
                root.endY = mouse.y;
            }
        }
        onReleased: {
            root.dragging = false;
            root.selectionMade = root.selW > 4 && root.selH > 4;
        }
    }

    MouseArea {
        id: moveArea
        visible: root.selectionMade
        enabled: root.selectionMade
        x: root.selX
        y: root.selY
        width: root.selW
        height: root.selH
        cursorShape: Qt.SizeAllCursor
        property real grabDX: 0
        property real grabDY: 0
        onPressed: mouse => {
            grabDX = mouse.x;
            grabDY = mouse.y;
        }
        onPositionChanged: mouse => {
            const dx = mouse.x - grabDX;
            const dy = mouse.y - grabDY;
            const w = root.selW;
            const h = root.selH;
            const newX = root.clamp(root.selX + dx, 0, root.width - w);
            const newY = root.clamp(root.selY + dy, 0, root.height - h);
            root.startX = newX;
            root.startY = newY;
            root.endX = newX + w;
            root.endY = newY + h;
        }
    }

    StyledRect {
        id: selectionRect
        enableAnimations: false
        visible: (root.dragging || root.selectionMade) && root.selW > 2 && root.selH > 2
        x: root.selX
        y: root.selY
        width: root.selW
        height: root.selH
        color: "transparent"
        radius: root.selRadius
        border.color: Colors.colPrimary
        border.width: 2
        transformOrigin: Item.Center
        SequentialAnimation {
            id: selectionPunch
            Anim {
                target: selectionRect
                property: "scale"
                to: 1.1
                duration: 130
                easing.type: Easing.OutQuad
            }
            Anim {
                target: selectionRect
                property: "scale"
                to: 0.94
                duration: 110
                easing.type: Easing.InOutQuad
            }
            Anim {
                target: selectionRect
                property: "scale"
                to: 1.0
                duration: 180
                easing.type: Easing.OutBack
                easing.overshoot: 3.0
            }
        }
        Connections {
            target: root
            function onPopTickChanged() {
                selectionPunch.start();
            }
        }
    }

    Repeater {
        model: 4
        StyledRect {
            id: cornerHandle
            readonly property bool isLeft: index === 0 || index === 2
            readonly property bool isTop: index === 0 || index === 1
            enableAnimations: false
            width: root.cornerSize
            height: root.cornerSize
            radius: Rounding.verysmall
            color: "transparent"
            
            
            transformOrigin: Item.Center
            scale: selectionRect.visible ? 1 : 0
            opacity: selectionRect.visible ? 1 : 0
            x: (isLeft ? root.selX : root.selX + root.selW) - width / 2
            y: (isTop ? root.selY : root.selY + root.selH) - height / 2
            Behavior on scale {
                Anim {
                    _duration: "small"
                }
            }
            Behavior on opacity {
                Anim {}
            }
            SequentialAnimation {
                id: cornerPunch
                Anim {
                    target: cornerHandle
                    property: "scale"
                    to: 1.4
                    duration: 110
                    easing.type: Easing.OutQuad
                }
                Anim {
                    target: cornerHandle
                    property: "scale"
                    to: 1.0
                    duration: 200
                    easing.type: Easing.OutBack
                    easing.overshoot: 4.0
                }
            }
            Connections {
                target: root
                function onPopTickChanged() {
                    cornerPunch.start();
                }
            }
            MouseArea {
                enabled: root.selectionMade
                anchors.centerIn: parent
                width: parent.width + 20
                height: parent.height + 20
                cursorShape: cornerHandle.isLeft === cornerHandle.isTop ? Qt.SizeFDiagCursor : Qt.SizeBDiagCursor
                onPositionChanged: mouse => {
                    const p = mapToItem(root, mouse.x, mouse.y);
                    if (cornerHandle.isLeft)
                        root.startX = root.clamp(p.x, 0, root.endX - root.minSize);
                    else
                        root.endX = root.clamp(p.x, root.startX + root.minSize, root.width);
                    if (cornerHandle.isTop)
                        root.startY = root.clamp(p.y, 0, root.endY - root.minSize);
                    else
                        root.endY = root.clamp(p.y, root.startY + root.minSize, root.height);
                }
            }
        }
    }

    Repeater {
        model: 4
        StyledRect {
            id: edgeHandle
            readonly property int side: index
            readonly property bool horizontal: side === 0 || side === 1
            enableAnimations: false
            width: horizontal ? root.edgePillLength : root.edgePillThickness
            height: horizontal ? root.edgePillThickness : root.edgePillLength
            radius: height / 2
            color: Colors.colPrimaryContainer
            border.color: Colors.colOnPrimaryContainer
            border.width: 2
            transformOrigin: Item.Center
            scale: selectionRect.visible ? 1 : 0
            opacity: selectionRect.visible ? 1 : 0
            x: {
                if (side === 0)
                    return root.selX + root.selW / 2 - width / 2;
                if (side === 1)
                    return root.selX + root.selW / 2 - width / 2;
                if (side === 2)
                    return root.selX - width / 2;
                return root.selX + root.selW - width / 2;
            }
            y: {
                if (side === 0)
                    return root.selY - height / 2;
                if (side === 1)
                    return root.selY + root.selH - height / 2;
                if (side === 2)
                    return root.selY + root.selH / 2 - height / 2;
                return root.selY + root.selH / 2 - height / 2;
            }
            Behavior on scale {
                Anim {}
            }
            Behavior on opacity {
                Anim {
                    _duration: "small"
                }
            }
            SequentialAnimation {
                id: edgePunch
                Anim {
                    target: edgeHandle
                    property: "scale"
                    to: 1.4
                }
                Anim {
                    target: edgeHandle
                    property: "scale"
                    to: 1.0
                }
            }
            Connections {
                target: root
                function onPopTickChanged() {
                    edgePunch.start();
                }
            }
            MouseArea {
                enabled: root.selectionMade
                anchors.centerIn: parent
                width: edgeHandle.horizontal ? parent.width + 20 : parent.width + 16
                height: edgeHandle.horizontal ? parent.height + 16 : parent.height + 20
                cursorShape: edgeHandle.horizontal ? Qt.SizeVerCursor : Qt.SizeHorCursor
                onPositionChanged: mouse => {
                    const p = mapToItem(root, mouse.x, mouse.y);
                    if (edgeHandle.side === 0)
                        root.startY = root.clamp(p.y, 0, root.endY - root.minSize);
                    else if (edgeHandle.side === 1)
                        root.endY = root.clamp(p.y, root.startY + root.minSize, root.height);
                    else if (edgeHandle.side === 2)
                        root.startX = root.clamp(p.x, 0, root.endX - root.minSize);
                    else
                        root.endX = root.clamp(p.x, root.startX + root.minSize, root.width);
                }
            }
        }
    }

    StyledRect {
        id: dimensionLabel
        enableAnimations: false
        visible: root.dragging && selectionRect.visible
        radius: Rounding.full
        color: Colors.colPrimaryContainer
        width: dimensionText.implicitWidth + Padding.massive
        height: dimensionText.implicitHeight + Padding.large
        x: root.selX + (root.selW - width) / 2
        y: root.selY - height - 12 >= 0 ? root.selY - height - 12 : root.selY + root.selH + 12

        StyledText {
            id: dimensionText
            anchors.centerIn: parent
            text: Math.round(root.selW) + " x " + Math.round(root.selH)
            color: Colors.colOnPrimaryContainer
            font: Fonts.request("numbers", "normal")
        }
    }

    ButtonGroup {
        id: toolbar
        visible: root.selectionMade
        scale: 0
        transformOrigin: Item.Center
        color: Colors.colLayer3
        padding: Padding.small
        x: Math.max(Padding.normal, Math.min(root.width - width - Padding.normal, root.selX + (root.selW - width) / 2))
        y: {
            const below = root.selY + root.selH + Padding.veryhuge;
            const above = root.selY - height - Padding.veryhuge;
            return below + height <= root.height ? below : Math.max(Padding.normal, above);
        }
        SequentialAnimation {
            id: toolbarPunch
            Anim {
                target: toolbar
                property: "scale"
                to: 1.15
                duration: 160
            }
            Anim {
                target: toolbar
                property: "scale"
                to: 0.92
                duration: 120
            }
            Anim {
                target: toolbar
                property: "scale"
                to: 1.0
                duration: 200
            }
        }
        Connections {
            target: root
            function onSelectionMadeChanged() {
                if (root.selectionMade)
                    toolbarPunch.start();
                else
                    toolbar.scale = 0;
            }
        }
        GroupButtonWithIcon {
            buttonRadius: height / 2
            baseSize: 45
            materialIcon: "cancel"
            onClicked: {
                root.selectionMade = false;
                root.startX = 0;
                root.startY = 0;
                root.endX = 0;
                root.endY = 0;
            }
        }
        GroupButtonWithIcon {
            toggled: true
            buttonRadius: height / 2
            baseSize: 45
            materialIcon: "camera"
            onClicked: root.regionCommitted(root.selX, root.selY, root.selW, root.selH)
        }
    }
}
