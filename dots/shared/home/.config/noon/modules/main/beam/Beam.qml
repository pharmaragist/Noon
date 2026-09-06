import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services
import qs.data

import "modes"
import "overlays"

Variants {
    model: MonitorsInfo.focused

    StyledPanel {
        id: root
        name: "noanim_blurred_layer"
        required property var modelData
        property real scrollSum: 0
        property bool hasAttachedFile: false
        readonly property string revealReason: Globals.main.beam.reason
        readonly property bool reveal: Globals.main.beam.show
        readonly property int elevationValue: Sizes.elevationMargin + (BarData.position === "bottom" ? BarData.currentInfo.appearance.size : 0)
        readonly property alias containsDrag: dropArea.containsDrag
        readonly property var currentModeData: contentMap[revealReason]
        readonly property var contentMap: BeamData?.contentMap ?? ({})

        visible: true
        exclusiveZone: -1
        fill: true
        keyboardFocus: reveal
        focusHandler.active: root.reveal
        focusHandler.onCleared: root.hide()
        screen: modelData
        _layer: "Overlay"

        mask: Region {
            Region {
                target: bg
                enabled: root.reveal
            }
            Region {
                target: hoverArea
            }
            Region {
                target: overlaysLoader
                enabled: overlaysLoader.active
            }
            Region {
                enabled: popup.opacity > 0
                target: popup
            }
        }

        function hide() {
            const opts = Globals.main.beam;
            if (opts.reason !== "default")
                opts.reason = "default";
            else
                opts.show = false;
        }

        ScrimOverlay {
            shown: !!root?.currentModeData?.dim
            onHide: root.hide()
        }

        StyledLoader {
            id: overlaysLoader
            readonly property var data: root.currentModeData ?? ({})
            anchors.fill: parent
            z: 0
            asynchronous: true

            active: {
                const hasSource = (data?.overlay && data?.overlay?.length > 0) ?? false;
                return root.reveal && hasSource;
            }

            source: Qt.resolvedUrl("./overlays/" + (data?.overlay ?? "Stub") + ".qml")
            onLoaded: {
                if (ready && active && "hide" in _item)
                    _item?.hide?.connect(() => root.hide());
                if (!active)
                    root.focusHandler.clear();
            }
        }

        MouseArea {
            id: hoverArea
            z: -1
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom

            implicitHeight: Math.max(1, Sizes.hyprland.gapsOut - 2)
            hoverEnabled: true
            propagateComposedEvents: true
            acceptedButtons: Qt.NoButton
            scrollGestureEnabled: true

            Timer {
                id: idleTimer
                repeat: true
                interval: 6000
                running: {
                    const contentHasTimeOut = root.revealReason !== "default" && (root?.currentModeData?.timeout ?? true);
                    const defaultAndEmpty = root.revealReason === "default" && BeamData.query.length === 0;
                    return root.reveal && (contentHasTimeOut || defaultAndEmpty);
                }
                onTriggered: root.hide()
            }

            onWheel: wheel => {
                if (wheel.modifiers === Qt.ControlModifier) {
                    Globals.main.sysDialogs.mode = wheel.angleDelta.y < 0 ? "incubate" : "";
                    wheel.accepted = true;
                    return;
                }
                if (wheel.modifiers === Qt.ShiftModifier) {
                    Globals.main.sysDialogs.mode = wheel.angleDelta.y < 0 ? "dino" : "";
                    wheel.accepted = true;
                    return;
                }

                root.scrollSum += wheel.angleDelta.y;

                if (!root.reveal && root.scrollSum <= -20) {
                    Globals.main.beam.show = true;
                    root.scrollSum = 0;
                } else if (root.reveal && root.scrollSum >= 20) {
                    Globals.main.beam.show = false;
                    root.scrollSum = 0;
                }

                wheel.accepted = true;
            }

            DropArea {
                id: dropArea
                anchors.fill: parent
                keys: ["text/uri-list"]
                onDropped: drop => {
                    if (!drop || !drop.hasUrls || drop.urls.length === 0)
                        return;

                    let urlStrings = drop.urls.map(url => url.toString());
                    let firstUrl = urlStrings[0];

                    if (NoonUtils.isOnlineUrl(firstUrl)) {
                        NoonUtils.runDownloader(firstUrl);
                    } else if (firstUrl.startsWith("file://")) {
                        Mem.states.sidebar.shelf.filePaths = [...Mem.states.sidebar.shelf.filePaths, ...urlStrings];
                    }
                }
            }
        }

        BeamPopup {
            id: popup
            target: bg
            reveal: root.reveal && root.revealReason === "default"
            topRadius: (root.currentModeData?.ignoreRadiusComplement ?? false) ? (root.currentModeData?.popupRadius ?? Rounding.huge) : this.target.bottomRadius
            bottomRadius: (root.currentModeData?.ignoreRadiusComplement ?? false) ? (root.currentModeData?.popupRadius ?? Rounding.huge) : this.shown ? Rounding.tiny : target.bottomRadius
        }

        StyledRectangularShadow {
            target: popup
            transparency: 0.8
            show: popup?.shown ?? false
        }

        StyledRectangularShadow {
            target: bg
            show: root.reveal && (root.currentModeData?.shadow ?? true)
            transparency: 0.8
        }

        Content {
            id: bg
            z: 999
            reveal: root.reveal
            elevationValue: root.elevationValue
            animationDuration: 300
            height: root.currentModeData.size?.height ?? 1000
            width: root.currentModeData.size?.width ?? 1000
            color: (root.currentModeData?.transparent ?? false) ? "transparent" : Colors.colBackground

            contentSource: Qt.resolvedUrl("modes/" + (root.currentModeData?.component ?? "BeamContentView") + ".qml")

            topRadius: popup?.shown ? popup.bottomRadius : this.bottomRadius
            bottomRadius: root?.currentModeData?.radius ?? Rounding.silly;

            onContentLoaded: item => {
                if (root.reveal && "focusItem" in item)
                    item.focusItem.forceActiveFocus();

                if (root.currentModeData?.when ?? false) {
                    const targetStr = root.currentModeData?.target;
                    if (!targetStr)
                        return;

                    const parts = targetStr.split('.');
                    const property = parts.pop();

                    eval(parts.join('.'))[property] = Qt.binding(() => root.currentModeData?.when ?? false);
                }
            }
        }
    }
}
