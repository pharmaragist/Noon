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
        readonly property string revealReason: Globals.main.beam.reason
        readonly property bool pinned: Globals.main.beam.pinned
        readonly property bool reveal: Globals.main.beam.show || pinned
        readonly property int elevationValue: Sizes.elevationMargin + (BarData.position === "bottom" ? BarData.currentInfo.appearance.size : 0)
        readonly property var currentModeData: contentMap[revealReason]
        readonly property var contentMap: BeamData?.contentMap ?? ({})

        exclusiveZone: -1
        fill: true
        keyboardFocus: reveal
        focusHandler.active: root.reveal
        focusHandler.onCleared: root.hide()
        screen: modelData
        _layer: "Overlay"

        // autoHide: true
        // revealed: reveal
        // hideDelay: bg.animationDuration + 50

        dismissArea.target: bg
        dismissArea.active: root.reveal && !root.pinned

        // Blur follows the settled geometry, not the spring-animated bg.
        // Tracking bg would send a new blur region to the compositor every frame.
        Item {
            id: blurTarget
            visible: false
            property int radius: bg.bottomRadius
            property int topLeftRadius: bg.topRadius
            property int topRightRadius: bg.topRadius
            property int bottomLeftRadius: bg.bottomRadius
            property int bottomRightRadius: bg.bottomRadius
            x: (root.width - bg.width) / 2
            y: root.height - bg.height - root.elevationValue
            width: bg.width
            height: bg.height
        }

        Item {
            id: popupBlurTarget
            visible: false
            readonly property int popupHeight: {
                if (!popup.shown)
                    return 0;
                return Math.max(100, Math.min(600, popup.contentHeight));
            }
            property int radius: popup.bottomRadius
            property int topLeftRadius: popup.topRadius
            property int topRightRadius: popup.topRadius
            property int bottomLeftRadius: popup.bottomRadius
            property int bottomRightRadius: popup.bottomRadius
            x: blurTarget.x
            y: blurTarget.y - popupHeight - 2
            width: blurTarget.width
            height: popupHeight
        }

        // blur: Region {
        //     Region {
        //         enabled: bg.morphed && popupBlurTarget.height > 0
        //         target: popupBlurTarget
        //     }
        //     Region {
        //         enabled: bg.morphed
        //         target: blurTarget
        //     }
        // }

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
            Region {
                width: dismissArea.visible ? root.width : 0
                height: dismissArea.visible ? root.height : 0
            }
        }

        function hide() {
            // close only; reason resets later below-screen (clearDelay),
            // so no content switch ever plays visibly during the rewind.
            Globals.main.beam.show = false;
        }

        ScrimOverlay {
            // tied to reveal, not just mode: dim fades with the rewind
            // instead of lingering until the below-screen janitor runs
            shown: !!root?.currentModeData?.dim && root.reveal
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
                    Globals.main.beam.show = true;
                    if (wheel.angleDelta.y < 0)
                        Globals.main.beam.reason = "appearance";
                    if (wheel.angleDelta.y > 0)
                        Globals.main.beam.reason = "default";

                    wheel.accepted = true;
                    return;
                }
                // if (wheel.modifiers === Qt.ShiftModifier) {
                //     Globals.main.sysDialogs.mode = wheel.angleDelta.y < 0 ? "dlp" : "";
                //     wheel.accepted = true;
                //     return;
                // }

                // drag-to-reveal: wheel travel owns the water (puddle->ball->
                // panel across 0..1); full travel or past-halfway on release
                // commits, otherwise it pours back. Same gesture reversed
                // while open pours it away.
                bg.dragBy(-wheel.angleDelta.y / 400);

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
                    if (firstUrl.startsWith("file://")) {
                        Mem.states.sidebar.shelf.filePaths = [...Mem.states.sidebar.shelf.filePaths, ...urlStrings];
                    } else {
                        NoonUtils.runDownloader(firstUrl);
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

        BeamBg {
            id: bg
            z: 999
            reveal: root.reveal
            elevationValue: root.elevationValue
            animationDuration: 300
            height: this.currentItem?.contentItem?.height ?? root.currentModeData.size?.height ?? -1 // getDimension("height")
            width: this.currentItem?.contentItem?.width ?? root.currentModeData.size?.width ?? -1
            bodyColor: Colors.colBackground
            restTransparent: (root.currentModeData?.transparent ?? false)

            contentSource: Qt.resolvedUrl("modes/" + (root.currentModeData?.component ?? "ContentViewItem") + ".qml")

            topRadius: popup?.shown ? popup.bottomRadius : this.bottomRadius
            bottomRadius: root?.currentModeData?.radius ?? Rounding.silly
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
