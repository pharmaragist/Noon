import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.data
import qs.common
import qs.common.widgets
import qs.services
import "./../components"

StyledPanel {
    id: bar

    property bool hovered: false
    readonly property string style: "pill" // notch
    readonly property bool autoHide: Mem.options.bar.behavior.autoHide
    readonly property bool useBg: BarData.currentInfo.appearance.useBg
    readonly property int peekSize: 10
    readonly property bool isBottom: false // BarData.postition === "bottom"
    readonly property int barHeight: _current.size.height + elevation
    readonly property int elevation: Sizes.barElevation
    readonly property int hideMargin: autoHide && !hovered ? -(barHeight - peekSize) : 0
    readonly property var content: ({
            "default": {
                "component": defaultComp,
                "size": Qt.size(250, 50),
                "exclusive": true
            },
            "details": {
                "component": detailedComp,
                "size": Qt.size(550, 65)
            }
        })
    property string selectedContent: "default"
    readonly property var _current: content[selectedContent] ?? content["default"]

    // onSelectedContentChanged: {
    //     pushComponent();
    // }

    function expand(state) {
        selectedContent = state;
        pushComponent();
    }
    function collapse() {
        selectedContent = "default";
        pushComponent();
    }
    function pushComponent() {
        const src = bar._current?.component ?? defaultComp;
        if (stack.depth === 0 || bar.selectedContent === "default") {
            stack.clear();
            stack.pushItem(src);
        } else {
            stack.replaceCurrentItem(src);
        }
        if (stack.currentItem && "bar" in stack.currentItem)
            stack.currentItem.bar = bar;
    }

    // island trigger: media takes over, releases after a dwell
    Timer {
        id: collapseDelay
        interval: 4000
        onTriggered: bar.collapse()
    }

    Connections {
        target: MediaPlayerService
        function on_PlayingChanged() {
            if (MediaPlayerService._playing) {
                collapseDelay.stop();
                bar.expand("details");
                collapseDelay.restart();
            } else {
                collapseDelay.restart();
            }
        }
    }
    name: "bar"
    shell: "noon"
    _layer: "Top"

    implicitHeight: barHeight + 100
    exclusiveZone: autoHide ? (hovered && !useBg ? barHeight : peekSize) : _current.exclusive ? barHeight : 50

    fill: true
    anchors.top: !isBottom
    anchors.bottom: isBottom

    mask: Region {
        item: bg
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: autoHide
        acceptedButtons: Qt.NoButton
        propagateComposedEvents: true

        onEntered: if (autoHide)
            bar.hovered = true
        onExited: if (autoHide)
            bar.hovered = false

        Item {
            id: container

            opacity: autoHide && !hovered ? 0 : 1
            implicitHeight: barHeight
            implicitWidth: Screen.width

            anchors {
                left: parent.left
                right: parent.right
                top: !isBottom ? parent.top : undefined
                bottom: isBottom ? parent.bottom : undefined
                topMargin: !isBottom ? hideMargin : 0
                bottomMargin: isBottom ? hideMargin : 0
            }

            Behavior on anchors.topMargin {
                enabled: !isBottom
                Anim {}
            }
            Behavior on anchors.bottomMargin {
                enabled: isBottom
                Anim {}
            }

            StyledRectangularShadow {
                target: bg
            }

            StyledRect {
                id: bg

                anchors {
                    topMargin: bar.isBottom ? bar.elevation : 0
                    bottomMargin: !bar.isBottom ? bar.elevation : 0
                    top: bar.isBottom ? undefined : parent.top
                    bottom: !bar.isBottom ? undefined : parent.bottom
                    horizontalCenter: parent.horizontalCenter
                }
                clip: true
                bouncy: true
                width: stack.currentItem.implicitWidth // ?? bar._current?.size?.width ?? 300
                height: bar._current?.size?.height ?? 50
                color: Colors.colLayer0
                bottomRadius: Rounding.large
                topRadius: bar.style === "notch" ? 0 : Rounding.large

                Component.onCompleted: bar.pushComponent()

                MouseArea {
                    z: 2
                    anchors.fill: parent
                    hoverEnabled: true
                    preventStealing: true
                    propagateComposedEvents: true
                    acceptedButtons: Qt.NoButton
                    onEntered: bar.expand("details")
                    onExited: bar.collapse()
                }

                StyledStackView {
                    id: stack
                    anchors.fill: parent

                    // incoming wells up, outgoing sinks back down
                    enter: Transition {
                        ParallelAnimation {
                            PropertyAnimation {
                                property: "scale"
                                from: 0.95
                                to: 1
                                duration: 140
                            }
                            PropertyAnimation {
                                property: "opacity"
                                from: 0
                                to: 1
                                duration: 140
                            }
                        }
                    }
                    exit: Transition {
                        ParallelAnimation {
                            PropertyAnimation {
                                property: "scale"
                                from: 1
                                to: 0.95
                                duration: 140
                            }
                            PropertyAnimation {
                                property: "opacity"
                                to: 0
                                duration: 100
                            }
                        }
                    }
                }
            }
        }
    }
    Component {
        id: detailedComp
        Item {
            id: root
            implicitWidth: row.implicitWidth + Padding.silly
            property var bar
            Visualizer {
                anchors.fill: parent
                active: true
            }
            RowLayout {
                id: row
                height: 50
                anchors.right: parent.right
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                spacing: Padding.massive

                BarModulesFactory {
                    vertical: false
                    panel: root.bar
                    model: ["detailedMedia", "inlineTray", "materialStatusIcons", "clock", "battery"]
                }
            }
        }
    }
    Component {
        id: defaultComp
        Item {
            id: root
            implicitWidth: row.implicitWidth + Padding.silly

            property var bar

            RowLayout {
                id: row
                anchors.centerIn: parent
                spacing: Padding.massive

                BarModulesFactory {
                    vertical: false
                    panel: root.bar
                    model: ["clock", "materialStatusIcons"]
                }
            }
        }
    }
}
