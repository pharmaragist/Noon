import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.utils
import qs.common.widgets

WidgetLoader {
    AppWindow {
        id: root
        title: "Beats"
        readonly property var userInfo: SysInfoService
        readonly property var svc: BeatsService
        readonly property int sidebarWidth: 250
        readonly property int coverArtSize: 365
        readonly property var colors: palette?.colors ?? Colors

        RowLayout {
            anchors.fill: parent
            spacing: 0

            StyledRect {
                id: sidebar
                Layout.fillHeight: true
                implicitWidth: root.sidebarWidth
                color: root.colors.colLayer1

                Border {
                    side: "right"
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.topMargin: Padding.normal
                    anchors.bottomMargin: Padding.normal
                    anchors.margins: Padding.verysmall

                    RowLayout {
                        Layout.alignment: Qt.AlignHCenter
                        Layout.fillWidth: true
                        Layout.preferredHeight: 100
                        spacing: Padding.large

                        CroppedImage {
                            implicitSize: 60
                            radius: height / 2
                            source: root.userInfo?.userPfp ?? ""
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2

                            StyledText {
                                text: "Beats"
                                font: Fonts.request("banner", "normal")
                                color: root.colors.colOnLayer1
                                truncate: true
                            }
                            StyledText {
                                text: root.userInfo.username ?? "User"
                                font: Fonts.request("title", "large")
                                color: root.colors.colSubtext
                                truncate: true
                            }
                        }
                    }
                    Spacer {}
                }
            }

            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: 0

                Spacer {}

                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 1
                    color: root.colors.colOutline
                }

                StyledRect {
                    id: bottomBar
                    Layout.fillWidth: true
                    implicitHeight: 80
                    color: root.colors.colLayer2

                    RowLayout {
                        anchors.fill: parent
                        anchors.leftMargin: Padding.massive
                        anchors.rightMargin: Padding.silly
                        spacing: Padding.huge

                        CroppedImage {
                            implicitSize: 50
                            source: svc.player?.trackArtUrl ?? ""
                            radius: height / 4
                            clip: true
                            Layout.maximumWidth: 50
                        }

                        ColumnLayout {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter

                            StyledText {
                                Layout.fillWidth: true
                                Layout.maximumHeight: 20
                                Layout.maximumWidth: 450
                                text: this.methods.cleanMusicTitle(root.svc.player?.trackTitle ?? "")
                                font: Fonts.request("title", "large")
                                color: root.colors.colOnLayer2
                                truncate: true
                            }

                            StyledText {
                                Layout.maximumHeight: 20
                                Layout.fillWidth: true
                                Layout.maximumWidth: 400
                                text: this.methods.cleanMusicTitle(root.svc.player?.trackArtist ?? "")
                                font: Fonts.request("main", "normal")
                                color: root.colors.colSubtext
                                truncate: true
                            }
                        }

                        RowLayout {
                            spacing: 4
                            Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
                            Layout.minimumWidth: 210
                            Spacer {}
                            Repeater {
                                model: [
                                    {
                                        "icon": "fast_rewind",
                                        "action": () => svc.player?.previous()
                                    },
                                    {
                                        "icon": svc.player.isPlaying ? "pause" : "play_arrow",
                                        "action": () => svc.player?.togglePlaying()
                                    },
                                    {
                                        "icon": "fast_forward",
                                        "action": () => svc.player?.next()
                                    },
                                ]
                                SymbolButton {
                                    icon: modelData?.icon ?? ""
                                    iconSize: 25
                                    fill: 1
                                    action: () => modelData?.action()
                                }
                            }
                        }
                    }
                }

                StyledProgressBar {
                    id: progress
                    colors: root.colors
                    valueBarHeight: 3
                    Layout.fillWidth: true
                    value: MediaPlayerService.currentTrackProgressRatio(svc.player) ?? 0
                }
            }

            StyledRect {
                id: queue
                Layout.fillHeight: true
                implicitWidth: root.sidebarWidth
                color: root.colors.colLayer1

                Border {
                    side: "left"
                }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.normal
                    spacing: Padding.large

                    StyledText {
                        Layout.preferredHeight: 40
                        text: "Currently Playing"
                        font: Fonts.request("title", "large")
                        color: root.colors.colOnLayer2
                    }

                    Item {
                        Layout.fillHeight: true
                        Layout.fillWidth: true

                        StyledListView {
                            id: queueList
                            model: svc.queue
                            anchors.fill: parent
                            clip: true
                            hint: false
                            radius: 0
                            delegate: Item {
                                id: delegate
                                anchors.right: parent?.right
                                anchors.left: parent?.left
                                implicitHeight: 50
                                MouseArea {
                                    anchors.fill: parent
                                    onClicked: svc.playTrackByFile(modelData?.file)
                                }
                                ColumnLayout {
                                    anchors.right: parent.right
                                    anchors.left: parent.left
                                    anchors.verticalCenter: parent.verticalCenter

                                    StyledText {
                                        truncate: true
                                        Layout.preferredHeight: 15
                                        Layout.rightMargin: Padding.large
                                        text: modelData?.title ?? ""
                                        font: Fonts.request("main", "normal")
                                        color: root.colors.colOnLayer2
                                    }

                                    StyledText {
                                        Layout.preferredHeight: 15
                                        Layout.rightMargin: Padding.large
                                        text: modelData?.artist ?? ""
                                        font: Fonts.request("main", "small")
                                        color: root.colors.colSubtext
                                    }
                                }

                                Border {
                                    visible: index !== queueList.count - 1
                                    side: "bottom"
                                }
                            }
                        }
                    }
                }
            }
        }

        Item {
            z: -1
            visible: false
            anchors.fill: parent

            Rectangle {
                anchors.fill: parent
                z: 1
                opacity: 0.25
                property int randomizer: 0

                SmoothedAnimation on randomizer {
                    running: true
                    duration: 2000
                    loops: Animation.Infinite
                    from: 0
                    to: 1
                }

                gradient: Gradient {
                    GradientStop {
                        position: backdrop.randomizer
                        color: Colors.t(root.colors.colPrimary)
                    }
                    GradientStop {
                        position: backdrop.randomizer / 2
                        color: Colors.t(root.colors.colSecondary)
                    }
                    GradientStop {
                        position: 1 - backdrop.randomizer
                        color: Colors.t(root.colors.colPrimaryContainer)
                    }
                }
            }

            BlurredImage {
                z: 0
                source: svc?.player?.trackArtUrl ?? ""
                anchors.fill: parent
                blur: true
            }
        }

        MaterialColorsGenerator {
            id: palette
            source: svc.player?.trackArtUrl ?? ""
        }
    }
    component SymbolButton: Symbol {
        id: root
        property alias event: eventArea
        property var action: null

        SequentialAnimation {
            id: feed

            Anim {
                target: root
                property: "scale"
                from: 1
                to: 1.25
            }
            Anim {
                target: root
                property: "scale"
                to: 1
                from: 1.25
            }
        }

        MouseArea {
            id: eventArea
            anchors.fill: root
            onClicked: if (!!action) {
                feed.running = true;
                action();
            }
        }
    }
    component Border: Rectangle {
        required property string side
        Component.onCompleted: {
            const pairs = {
                "right": "left",
                "left": "right",
                "top": "bottom",
                "bottom": "top"
            };
            Object.keys(pairs)?.forEach(i => {
                if (pairs[i] === side)
                    return;
                anchors[i] = parent[i];
            });
        }
        implicitWidth: 1
        implicitHeight: 1
        color: root.colors.colOutline
    }
}
