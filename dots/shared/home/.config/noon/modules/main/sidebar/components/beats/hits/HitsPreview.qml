import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.common
import qs.common.widgets
import qs.services
import QtMultimedia

StyledRect {
    id: root

    property var songData
    clip: true
    radius: Rounding.verylarge
    color: "transparent"
    signal dismiss

    ColumnLayout {
        anchors.fill: parent
        spacing: 2

        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true
            z: 1
            spacing: Padding.massive

            MusicCoverArt {
                implicitSize: 136
                source: songData?.thumbnail ?? ""
            }

            ColumnLayout {
                Layout.fillWidth: true

                StyledText {
                    font: Fonts.request("main", Fonts.sizes.large, { weight: 800 })
                    Layout.fillWidth: true
                    truncate: true
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    text: songData?.title ?? "No Title"
                }

                StyledText {
                    font.pixelSize: Fonts.sizes.verysmall
                    Layout.fillWidth: true
                    text: songData?.artist ?? "No Artist"
                    color: Colors.colSubtext
                }

                ButtonGroup {
                    Layout.topMargin: Padding.large
                    Layout.alignment: Qt.AlignRight | Qt.AlignBottom
                    Layout.fillWidth: false
                    Layout.fillHeight: false

                    Repeater {
                        model: [
                            {
                                icon: "close",
                                action: () => root.player.stop()
                            },
                            {
                                icon: "download",
                                action: () => {
                                    DlpService.request({
                                        url: songData?.url,
                                        audio: true,
                                        quality: "best",
                                        debug: true,
                                        toast: true,
                                        directory: Mem.beats.players.main.musicDirectory
                                    });
                                    root.dismiss();
                                }
                            },
                            {
                                icon: "play_arrow",
                                action: () => BeatsService.previewURL(root.songData.url)
                            }
                        ]

                        delegate: GroupButtonWithIcon {
                            enabled: modelData?.enabled ?? true
                            baseSize: 45
                            buttonRadius: Rounding.small
                            buttonRadiusPressed: Rounding.large
                            toggled: modelData?.toggled ?? false
                            materialIcon: modelData.icon
                            releaseAction: () => modelData.action()
                        }
                    }
                }
            }
        }
        StyledProgressBar {
            Layout.fillWidth: true
            Layout.preferredHeight: 4
            valueBarGap: 4
            showProgressIndicator: false
            value: root.player?.position / root.player?.duration
        }
    }
}
