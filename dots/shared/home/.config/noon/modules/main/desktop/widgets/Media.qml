import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.services
import qs.common
import qs.common.functions
import qs.common.widgets

WidgetContainer {
    id: root
    readonly property var controlsModel: [
        {
            icon: "shuffle",
            action: () => root.player.shuffle = !root.player.shuffle
        },
        {
            icon: "skip_previous",
            action: () => root?.player?.previous()
        },
        {
            icon: root.player?.isPlaying ? "pause" : "play_arrow",
            action: () => root?.player?.togglePlaying()
        },
        {
            icon: "skip_next",
            action: () => root?.player?.next()
        },
        {
            icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat",
            action: () => MediaPlayerService.cycleRepeat(root?.player)
        }
    ]
    readonly property PaletteGenerator palette: MaterialColorsGenerator {
        active: source !== null
        source: player?.trackArtUrl
    }
    readonly property MprisPlayer player: BeatsService?.players?.find(p => /noon/.test(p?.dbusName?.toLowerCase()))
    colors: (palette?.colors ?? Colors)
    xlarge: Item {
        anchors.fill: parent
        anchors.margins: Padding.large

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Padding.large
            anchors.rightMargin: Padding.large
            spacing: Padding.large

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                spacing: Padding.huge

                ArtImage {
                    radius: Rounding.normal
                    implicitSize: 60
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        Layout.rightMargin: Padding.massive
                        text: this.methods.cleanMusicTitle(root.player?.trackTitle)
                        font: Fonts.request("title", "large")
                        color: root.colors.colOnLayer0
                        truncate: true
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.rightMargin: Padding.massive
                        text: this.methods.cleanMusicTitle(root.player?.trackArtist)
                        font: Fonts.request("main", "normal")
                        color: root.colors.colSubtext
                        truncate: true
                    }
                }
            }

            ButtonGroup {
                Layout.fillWidth: true
                Repeater {
                    model: root.controlsModel
                    delegate: GroupButtonWithIcon {
                        required property var modelData
                        Layout.fillWidth: true
                        buttonRadius: Rounding.large
                        layerNumber: 3
                        materialIcon: modelData.icon
                        colors: root.colors
                        baseSize: 60
                        releaseAction: () => modelData.action()
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Rounding.verylarge
                color: root.colors.colLayer3
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.normal
                    spacing: 2
                    Repeater {
                        model: BeatsService.queue.slice(1, 5)
                        delegate: StyledRect {
                            required property var modelData
                            required property int index

                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            topRadius: index === 0 ? Rounding.large : 2
                            bottomRadius: index === 3 ? Rounding.large : 2
                            color: root.colors.colLayer4

                            StyledText {
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.margins: Padding.large
                                anchors.verticalCenter: parent.verticalCenter
                                text: modelData?.title ?? ""
                                font: Fonts.request("main", "normal")
                                color: root.colors.colOnLayer4
                                truncate: true
                            }
                            MouseArea {
                                anchors.fill: parent
                                onClicked: BeatsService.playTrackByFile(modelData?.file)
                            }
                        }
                    }
                }
            }
        }
    }

    small: Item {
        anchors.fill: parent

        Symbol {
            z: 999
            anchors.centerIn: parent
            icon: root.player.isPlaying ? "music_note" : "pause"
            iconSize: 30
            fill: 1
            color: root.colors.colOnPrimary
        }

        Item {
            anchors.fill: parent
            Rectangle {
                z: 1
                opacity: 0.6
                anchors.fill: parent
                color: root.colors.colPrimaryContainer
            }
            ArtImage {
                anchors.fill: parent
                blur: true
            }
        }
    }
    normal: Item {
        property int rad: 18

        GridLayout {
            anchors.fill: parent
            anchors.margins: Padding.large
            columns: 2

            ArtImage {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: rad
            }

            RippleButtonWithIcon {
                Layout.fillWidth: true
                Layout.fillHeight: true
                buttonRadius: rad
                materialIcon: root.player?.isPlaying ? "music_note" : "pause"
                colBackground: colors.colLayer3
                colors: root.colors
                onClicked: root?.player?.togglePlaying()
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                Layout.fillHeight: true
                buttonRadius: rad
                materialIcon: "skip_previous"
                colBackground: colors.colLayer3
                colors: root.colors
                onClicked: root?.player?.previous()
            }
            RippleButtonWithIcon {
                Layout.fillWidth: true
                Layout.fillHeight: true
                buttonRadius: rad
                materialIcon: "skip_next"
                colBackground: colors.colLayer3
                colors: root.colors
                onClicked: root?.player?.next()
            }
        }
    }
    large: Item {
        anchors.fill: parent
        anchors.margins: Padding.huge

        ColumnLayout {
            anchors.fill: parent
            anchors.leftMargin: Padding.large
            anchors.rightMargin: Padding.large
            spacing: Padding.normal

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                spacing: Padding.huge

                ArtImage {
                    radius: Rounding.normal
                    implicitSize: 60
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    StyledText {
                        Layout.fillWidth: true
                        Layout.rightMargin: Padding.massive
                        text: this.methods.cleanMusicTitle(root.player?.trackTitle)
                        font: Fonts.request("title", "large")
                        color: root.colors.colOnLayer0
                        truncate: true
                    }
                    StyledText {
                        Layout.fillWidth: true
                        Layout.rightMargin: Padding.massive
                        text: this.methods.cleanMusicTitle(root.player?.trackArtist)
                        font: Fonts.request("main", "normal")
                        color: root.colors.colSubtext
                        truncate: true
                    }
                }
            }
            ButtonGroup {
                Layout.fillWidth: true
                Repeater {
                    model: root.controlsModel
                    delegate: GroupButtonWithIcon {
                        required property var modelData
                        Layout.fillWidth: true
                        buttonRadius: Rounding.large
                        layerNumber: 3
                        materialIcon: modelData.icon
                        colors: root.colors
                        baseSize: 60
                        releaseAction: () => modelData.action()
                    }
                }
            }
        }
    }

    component ArtImage: StyledRect {
        property alias blur: img.blur
        clip: true
        BlurImage {
            id: img
            anchors.fill: parent
            source: root.player.trackArtUrl ?? ""
            blurMax: 40
        }
    }
}
