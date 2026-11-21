import QtQuick
import QtQuick.Layouts
import Quickshell.Services.Mpris
import qs.common
import qs.common.widgets
import qs.services
import Qt5Compat.GraphicalEffects

import "../"
import "../home"
import "../home/seamless"

SidebarItemContainer {
    id: root

    readonly property bool playing: MediaPlayerService.player?.playbackState === MprisPlaybackState.Playing
    readonly property bool displayingLyrics: activeLyrics.showContent && Mem.beats.options.showLyrics
    readonly property var colors: MediaPlayerService?.colors ?? Colors

    Keys.onPressed: event => {
        const ctrl = event.modifiers & Qt.ControlModifier;
        const shift = event.modifiers & Qt.ShiftModifier;
        const player = MediaPlayerService.player;
        const audio = AudioService?.sink?.audio;

        if (ctrl && shift) {
            switch (event.key) {
            case Qt.Key_R:
                BeatsService.fetchLyrics(MediaPlayerService.artist || "", MediaPlayerService.title || "");
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
            MediaPlayerService.cycleRepeat();
        } else {
            switch (event.key) {
            case Qt.Key_Up:
                audio && (audio.volume = Math.min(1.0, audio.volume + 0.05));
                break;
            case Qt.Key_Down:
                audio && (audio.volume = Math.max(0.0, audio.volume - 0.05));
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

        Item {
            id: content
            Layout.fillWidth: true
            Layout.fillHeight: true

            readonly property color baseColor: root.colors.colPrimaryContainer
            property color topColor: root.displayingLyrics ? Qt.darker(baseColor, 1.5) : baseColor
            property real gradientReach: root.displayingLyrics ? 0.0 : 0.7

            Behavior on topColor {
                CAnim {}
            }

            Behavior on gradientReach {
                Anim {}
            }

            Rectangle {
                visible: !!MediaPlayerService.player
                anchors.fill: parent
                z: 0
                gradient: Gradient {
                    GradientStop {
                        position: 0.0
                        color: content.topColor
                    }
                    GradientStop {
                        position: content.gradientReach
                        color: content.topColor
                    }
                    GradientStop {
                        position: 1.0
                        color: content.baseColor
                    }
                }
            }

            LiveLyrics {
                id: activeLyrics
                anchors.margins: Padding.huge
                z: 999
            }

            StyledLoader {
                id: bigCover
                z: 1
                anchors {
                    top: parent.top
                    left: parent.left
                    right: parent.right
                }
                height: parent?.height / 1.4
                fade: true
                active: !root.displayingLyrics && !!MediaPlayerService.player
                visible: !root.displayingLyrics && !!MediaPlayerService.player

                sourceComponent: Item {
                    anchors.fill: parent

                    StyledImage {
                        anchors.fill: parent
                        source: MediaPlayerService?.artUrl ?? ""
                        sourceSize: Qt.size(width, height)
                        layer.enabled: true
                        layer.effect: OpacityMask {
                            maskSource: fadeMask
                        }
                    }

                    Rectangle {
                        id: fadeMask
                        anchors.fill: parent
                        visible: false
                        layer.enabled: true
                        gradient: Gradient {
                            GradientStop {
                                position: 0.0
                                color: Qt.rgba(1, 1, 1, 1)
                            }
                            GradientStop {
                                position: 0.65
                                color: Qt.rgba(1, 1, 1, 1)
                            }
                            GradientStop {
                                position: 0.85
                                color: Qt.rgba(1, 1, 1, 0)
                            }
                            GradientStop {
                                position: 1.0
                                color: Qt.rgba(1, 1, 1, 0)
                            }
                        }
                    }
                }
            }

            ColumnLayout {
                z: 999
                spacing: Padding.massive
                height: parent.height * 0.36
                anchors {
                    bottom: parent.bottom
                    left: parent.left
                    right: parent.right
                    margins: Padding.massive
                }

                PlayerSelector {}

                MediaPlayerControls {
                    hasLyrics: root.displayingLyrics
                }
            }
        }
    }
}
