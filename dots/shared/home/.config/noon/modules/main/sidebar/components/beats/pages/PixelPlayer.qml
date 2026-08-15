import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.common
import qs.common.widgets
import qs.services
import "../"
import "../home"
import "../home/pixel"

SidebarItemContainer {
    id: root

    readonly property bool playing: BeatsService.player?.playbackState === MprisPlaybackState.Playing
    readonly property bool displayingLyrics: activeLyrics.showContent && Mem.beats.options.showLyrics
    readonly property var colors: BeatsService?.colors ?? Colors

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        const player = BeatsService.player;

        if (ctrl && shift) {
            switch (event.key) {
            case Qt.Key_R:
                LyricsService.fetchLyrics(BeatsService.artist || "", BeatsService.title || "");
                break;
            case Qt.Key_Right:
                player?.canControl && player.next();
                break;
            case Qt.Key_Left:
                player?.canControl && player.previous();
                break;
            case Qt.Key_S:
                player && (player.shuffle = !player.shuffle);
                break;
            default:
                return;
            }
        } else if (ctrl && event.key === Qt.Key_R) {
            BeatsService.cycleRepeat();
        } else {
            switch (event.key) {
            case Qt.Key_Up:
                AudioService?.sink?.audio && (AudioService.sink.audio.volume = Math.min(1.0, AudioService.sink.audio.volume + 0.05));
                break;
            case Qt.Key_Down:
                AudioService?.sink?.audio && (AudioService.sink.audio.volume = Math.max(0.0, AudioService.sink.audio.volume - 0.05));
                break;
            case Qt.Key_Space:
                player?.togglePlaying();
                break;
            case Qt.Key_Right:
                player?.canSeek && player.length && (player.position = Math.min(player.length, player.position + 10));
                break;
            case Qt.Key_Left:
                player?.canSeek && player.length && (player.position = Math.max(0, player.position - 10));
                break;
            default:
                return;
            }
        }
        event.accepted = true;
    }

    RLayout {
        spacing: Padding.huge

        anchors.fill: parent
        anchors.margins: detached ? Padding.massive : Padding.large

        Item {
            id: content
            Layout.fillWidth: true
            Layout.fillHeight: true
            LiveLyrics {
                id: activeLyrics
            }

            StyledLoader {
                id: bigCover
                anchors.centerIn: parent
                anchors.verticalCenterOffset: -135
                width: parent.width - Padding.massive - (root.playing ? Padding.normal : Padding.massive)
                height: width
                fade: true
                active: !root.displayingLyrics
                visible: !root.displayingLyrics
                sourceComponent: MusicCoverArt {
                    anchors.fill: parent
                    clip: true
                    radius: Rounding.large
                    enableBorders: false
                }
                Behavior on width {
                    Anim {}
                }
            }

            ColumnLayout {
                spacing: Padding.massive
                anchors.top: bigCover?.bottom ?? parent.top
                anchors.bottom: parent.bottom
                anchors.right: parent.right
                anchors.left: parent.left
                anchors.margins: Padding.huge
                PlayerSelector {}
                MediaPlayerControls {
                    hasLyrics: root.displayingLyrics
                }
            }
        }

        StyledLoader {
            shown: root.expanded
            fade: true
            Layout.maximumWidth: 340
            Layout.rightMargin: root.detached ? Padding.massive : 0
            Layout.fillWidth: true
            Layout.fillHeight: true
            binds: ({
                    "colors": () => root.colors
                })

            sourceComponent: TracksQueue {
                id: queue
                anchors.fill: parent
                colors: root.colors
            }
        }
    }
}
