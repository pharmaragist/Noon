import QtQuick
import QtQuick.Controls

import qs.common
import qs.common.widgets

PanelRect {
    id: root
    readonly property alias currentItem: stack.currentItem
    readonly property alias body: body
    property alias bodyColor: body.color
    property bool reveal: false
    // root is an invisible footprint at target size; `body` paints the shape.
    // animations off: footprint snaps, springs below drive everything.
    color: "transparent"
    clip: false
    enableAnimations: false
    property url contentSource: ""
    signal contentLoaded(var item)
    property int elevationValue: 0
    property url _lastContent: ""

    // Liquid drop: footprint stays at target size; `body` is the visible
    // shape morphing true circle -> rounded rect via REAL geometry
    // (width/height/radius in px, never transform-scale, so arcs stay clean).
    // ball deliberately TALLER than flat panels (70): the 88->70 squash on
    // landing is the splat. Vertical change is what sells the blob.
    property real blobD: 88 // drop diameter px

    // reshape targets read the live content size first (fixed per mode),
    // footprint second, blob fallback while empty. Eased while open so
    // mode switches morph; instant while morphing/hidden for exact aim.
    property real _targetW: {
        const cw = stack.currentItem?.contentItem?.width ?? -1;
        if (cw > 1)
            return cw;
        return root.width > 1 ? root.width : root.blobD;
    }
    property real _targetH: {
        const ch = stack.currentItem?.contentItem?.height ?? -1;
        if (ch > 1)
            return ch;
        return root.height > 1 ? root.height : root.blobD;
    }

    Behavior on _targetW {
        enabled: root.morph > 1.99
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }
    Behavior on _targetH {
        enabled: root.morph > 1.99
        NumberAnimation {
            duration: 320
            easing.type: Easing.OutCubic
        }
    }

    // corners ease with the reshape instead of snapping per mode
    property real _topR: root.topRadius
    property real _botR: root.bottomRadius

    Behavior on _topR {
        enabled: root.morph > 1.99
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }
    Behavior on _botR {
        enabled: root.morph > 1.99
        NumberAnimation {
            duration: 280
            easing.type: Easing.OutCubic
        }
    }

    // ball may exceed panel height (squash on landing); only width is capped
    property real _blob: Math.min(root.blobD, root._targetW)

    // one rect, one continuous pour: flat puddle (0) -> ball (1) -> panel.
    // morph chases its target on a single spring; the ss windows below shape
    // the staging spatially, so there are no timed stops to stutter on.
    // fully interruptible: retoggle mid-flight and both springs just bend.
    // while wheel-dragging, the wheel OWNS the target: the water follows
    // the finger, thresholds commit or cancel the reveal.
    property real dragProgress: 0 // 0 hidden .. 1 revealed, wheel-driven
    property bool dragging: false
    property real morph: root.dragging ? root.dragProgress * 2 : (root.reveal ? 2 : 0)

    function dragBy(amount) {
        if (stack.depth === 0 && root.contentSource.toString() !== "") {
            root._lastContent = root.contentSource;
            stack.push(root.contentSource);
        }
        clearDelay.stop();
        root.dragging = true;
        root.dragProgress = Math.max(0, Math.min(1, root.dragProgress + amount));
        if (!root.reveal && root.dragProgress >= 1) {
            root.dragging = false;
            root.dragProgress = 1;
            Globals.main.beam.reason = "default"; // drag always reveals default
            Globals.main.beam.show = true;
        } else if (root.reveal && root.dragProgress <= 0) {
            root.dragging = false;
            root.dragProgress = 0;
            Globals.main.beam.show = false;
        }
        settleDelay.restart();
    }
    // ball -> panel leg; doubles as the content/popup fade driver.
    property real grow: ss(1, 2, root.morph)
    // geometry-clamped twin: width/height freeze at target the moment we
    // land, so mask raster and layout stop churning through the settle.
    property real growC: Math.min(1, root.grow)

    // puddle geometry: full panel-width thin lens at the screen edge
    property real _lakeW: root._targetW
    property real _lakeH: 28

    Behavior on morph {
        SpringAnimation {
            spring: 3.4
            damping: 0.55
            epsilon: 0.05
        }
    }

    function ss(a, b, x) {
        const t = Math.max(0, Math.min(1, (x - a) / (b - a)));
        return t * t * (3 - 2 * t);
    }
    function mix(a, b, t) {
        return a + (b - a) * t;
    }

    anchors {
        horizontalCenter: parent ? parent.horizontalCenter : undefined
        bottom: parent ? parent.bottom : undefined
        bottomMargin: root.dragging ? mix(-root._targetH, root.elevationValue, ss(0, 1, root.dragProgress)) : (root.reveal ? root.elevationValue : -root._targetH)
    }

    Component.onCompleted: {
        if (!Mem.options.sidebar.behavior.rememberTabIndex)
            Mem.states.sidebar.tabIndexCache = ({});
        root.dragProgress = root.reveal ? 1 : 0;
    }

    Behavior on anchors.bottomMargin {
        SpringAnimation {
            spring: 3.4
            damping: 0.42
            epsilon: 0.6
        }
    }

    // below-screen janitor: destroy content and reset reason once invisible.
    // every close path only flips show; the switch to default (and the -1
    // size collapse) always lands here, never visibly mid-rewind. Interval
    // clears the full rewind tail with margin for slow springs.
    Timer {
        id: clearDelay
        interval: 800
        onTriggered: if (!root.reveal) {
            stack.clear();
            Globals.main.beam.reason = "default";
        }
    }
    // finger lifted: snap to whichever side of halfway the drag reached
    Timer {
        id: settleDelay
        interval: 350
        onTriggered: {
            if (!root.dragging)
                return;
            root.dragging = false;
            if (!root.reveal) {
                if (root.dragProgress > 0.5) {
                    root.dragProgress = 1;
                    Globals.main.beam.show = true;
                } else {
                    root.dragProgress = 0;
                }
            } else {
                if (root.dragProgress < 0.5) {
                    root.dragProgress = 0;
                    Globals.main.beam.show = false;
                } else {
                    root.dragProgress = 1;
                }
            }
        }
    }

    // no timetable: show pours (margin home + morph to panel), hide rewinds
    // (morph home + margin away). Springs retarget mid-flight, so rapid
    // toggles bend instead of jumping.
    onRevealChanged: {
        if (!root.dragging)
            root.dragProgress = root.reveal ? 1 : 0;
        if (!root.reveal) {
            clearDelay.restart();
        } else {
            clearDelay.stop();
            if (stack.depth === 0 && root.contentSource.toString() !== "") {
                root._lastContent = root.contentSource;
                stack.push(root.contentSource);
            }
            if (stack.currentItem)
                root.contentLoaded(stack.currentItem);
        }
    }

    // visible liquid shape, bottom-pinned so it grows upward.
    // puddle (wide lens) -> ball (circle) -> panel, all one rect.
    // Stack lives INSIDE body so content is always clipped to the
    // liquid — it emerges from the pour.
    PanelRect {
        id: body
        enableAnimations: false // geometry follows `morph` exactly, no lag spring
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        width: Math.max(8, mix(mix(root._lakeW, root._blob, ss(0, 1, root.morph)), root._targetW, root.growC))
        height: Math.max(8, mix(mix(root._lakeH, root._blob, ss(0, 1, root.morph)), root._targetH, root.growC))
        topRadius: root._topR
        bottomRadius: root._botR
        // corners resolve by mid-pour — roundness relaxes into the real
        // radii while the panel is still growing, not after
        radius: (1 - ss(1.0, 1.5, root.morph)) * 999

        StyledStackView {
            id: stack
            anchors.fill: parent
            // content appears only once the drop has mostly become panel
            opacity: Math.max(0, (root.grow - 0.55) / 0.45)

            // incoming wells up from the liquid, outgoing sinks back into it
            pushEnter: Transition {
                ParallelAnimation {
                    PropertyAnimation {
                        property: "y"
                        from: 22
                        to: 0
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 210
                        easing.type: Easing.OutCubic
                    }
                }
            }
            replaceEnter: Transition {
                ParallelAnimation {
                    PropertyAnimation {
                        property: "y"
                        from: 22
                        to: 0
                        duration: 260
                        easing.type: Easing.OutCubic
                    }
                    PropertyAnimation {
                        property: "opacity"
                        from: 0
                        to: 1
                        duration: 210
                        easing.type: Easing.OutCubic
                    }
                }
            }
            replaceExit: Transition {
                ParallelAnimation {
                    PropertyAnimation {
                        property: "y"
                        to: 12
                        duration: 130
                        easing.type: Easing.InCubic
                    }
                    PropertyAnimation {
                        property: "opacity"
                        to: 0
                        duration: 120
                    }
                }
            }
        }
    }

    onContentSourceChanged: {
        if (contentSource.toString() === "" || contentSource.toString() === root._lastContent.toString())
            return;
        root._lastContent = contentSource;

        if (stack.currentItem)
            stack.replace(contentSource);
        else
            stack.push(contentSource);
    }

    Connections {
        target: stack

        function onCurrentItemChanged() {
            if (stack.currentItem)
                root.contentLoaded(stack.currentItem);
        }
    }
}
