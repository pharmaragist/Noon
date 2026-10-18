import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

import qs.common
import qs.common.widgets
import qs.services

StyledPopup {
    id: root
    extraVisibilityCondition: MediaPlayerService?.title?.length > 0 ?? false
    contentMargins: 0
    popupBackgroundMargin: 0
    popupBackgroundBorders: false
    popupBackgroundColor: "transparent"
    contentItem: ColumnLayout {
        id: content
        spacing: 2
        Repeater {
            model: MediaPlayerService.players
            delegate: PlayerItem {
                required property var modelData
                required property int index
                player: modelData
                Layout.fillWidth: true
                topRadius: index === 0 ? Rounding.verylarge : Rounding.tiny
                bottomRadius: index === MediaPlayerService.players.length - 1 ? Rounding.verylarge : Rounding.tiny

                implicitWidth: 320
                Layout.preferredHeight: 70
            }
        }
    }

    component PlayerItem: StyledRect {
        id: root
        required property var player
        readonly property var colors: Colors
        color: colors.colLayer0

        RowLayout {
            anchors.fill: parent
            anchors.leftMargin: Padding.massive
            anchors.rightMargin: Padding.massive
            spacing: Padding.massive

            CircularProgress {
                implicitSize: 40
                value: MediaPlayerService.currentTrackProgressRatio(root.player)
                sperm: true
                lineWidth: 4
                colSecondary: "transparent"
                Symbol {
                    iconSize: 16
                    fill: 1
                    anchors.centerIn: parent
                    text: root.player.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                }
            }
            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true

                StyledText {
                    visible: !!text
                    font: Fonts.request("main", "large")
                    color: Colors.colOnLayer0
                    text: root.player.trackTitle.charAt(0).toUpperCase() + root.player.trackTitle.slice(1) || "No Media Playing"
                    truncate: true
                    Layout.fillWidth: true
                    Layout.maximumWidth: 300
                }

                StyledText {
                    truncate: true
                    font: Fonts.request("main", "small")
                    color: Colors.colSubtext
                    text: root.player.trackArtist || "No Current Artist"
                    Layout.fillWidth: true
                    Layout.maximumWidth: 200
                }
            }
        }
    }
}
