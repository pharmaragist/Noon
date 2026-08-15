import QtQuick
import QtQuick.Layouts
import Quickshell
import QtQuick.Controls
import Quickshell.Services.Mpris

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services
import qs.store





RowLayout {
    spacing: Padding.large

    PlayerSelector {}

    StyledRect {
        id: view
        readonly property MprisPlayer player: BeatsService.player
        Layout.fillHeight: true
        Layout.fillWidth: true
        colors: BeatsService.colors
        color: colors.colLayer2
        enableBorders: true
        radius: 42
        clip: true

        CroppedImage {
            z: 0
            source: view.player.trackArtUrl
            anchors.fill: parent
            antialiasing: true
            mipmap: true
            cache: false
            asynchronous: true
            fillMode: Image.PreserveAspectCrop
            radius: 41
            anchors.margins: 1
        }

        RadialGradient {
            id: overDrop
            z: 2
            anchors.fill: parent
            gradient: Gradient {
                GradientStop {
                    position: 0
                    color: "transparent"
                }
                GradientStop {
                    position: 0.5
                    color: Colors.methods.transparentize(view.colors.colPrimaryContainer, 0.35)
                }
            }
        }

        ColumnLayout {
            z: 3
            anchors.fill: parent
            spacing: 0
            anchors.margins: Padding.huge
            anchors.leftMargin: Padding.massive
            anchors.rightMargin: Padding.massive

            RowLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: Padding.massive

                ColumnLayout {
                    Layout.fillWidth: true

                    StyledText {
                        truncate: true
                        Layout.maximumWidth: 400
                        Layout.fillWidth: true
                        Layout.preferredHeight: 25

                        font: Fonts.request("title", 27)
                        text: this.methods.cleanMusicTitle(view.player?.trackTitle) || "Unknown Track"
                        color: view.colors.colPrimary
                    }

                    StyledText {
                        truncate: true
                        Layout.fillWidth: true
                        Layout.maximumWidth: 400
                        Layout.preferredHeight: 25
                        font: Fonts.request("reading", 19)
                        text: this.methods.cleanMusicTitle(view.player.trackArtist) || "Unknown Artist"
                        color: view.colors.colOnLayer0
                    }

                    StyledText {
                        truncate: true
                        Layout.fillWidth: true
                        Layout.preferredHeight: 10
                        opacity: 0.6
                        font: Fonts.request("reading", 11)
                        color: view.colors.colSubtext
                        text: {
                            
                            const byIdentity = view.player?.identity;
                            const byDBus = view.player?.dbusName?.replace("org.mpris.MediaPlayer2.", "");
                            const byIndex = "Player " + (BeatsService.selectedPlayerIndex + 1);
                            if (/\//.test(byIdentity) && byIdentity.length > 25) {
                                return byIdentity.split('/')[0].replace(/on|via|by|to+/g, "") || byDBus || byIndex;
                            } else
                                return byIdentity || byDBus || byIndex;
                        }
                    }
                }

                Spacer {}

                GroupButtonWithIcon {
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
                    baseSize: 55
                    toggled: true
                    colors: view.colors
                    buttonRadius: width / 3
                    buttonRadiusPressed: Rounding.normal
                    materialIcon: view.player.playbackState === MprisPlaybackState.Playing ? "pause" : "play_arrow"
                    materialIconFill: 1
                    onClicked: view?.player?.togglePlaying() ?? null
                }
            }

            RowLayout {
                Layout.preferredHeight: 55
                spacing: Padding.huge

                RippleButtonWithIcon {
                    implicitSize: 40
                    colors: view.colors
                    buttonRadius: Rounding.full
                    colBackground: "transparent"
                    materialIcon: "skip_previous"
                    releaseAction: () => !!view.player ? view.player?.previous() : null
                }
                StyledProgressBar {
                    id: progressBar
                    colors: view.colors
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignHCenter
                    Layout.preferredHeight: 16
                    sperm: view.player?.isPlaying ?? false
                    value: Math.abs(Math.min(1, view.player?.position / view.player.length))
                    valueBarGap: 8

                    MouseArea {
                        anchors.fill: parent

                        onClicked: mouse => {
                            seekTo(mouse.x);
                        }
                        onPositionChanged: mouse => {
                            seekTo(mouse.x);
                        }
                        function seekTo(x) {
                            if (!view.player?.canSeek || !view.player?.length)
                                return;
                            const ratio = Math.max(0, Math.min(1, x / width));
                            view.player.position = ratio * view.player.length;
                        }
                    }
                }
                RippleButtonWithIcon {
                    colors: view.colors
                    buttonRadius: Rounding.full
                    implicitSize: 40
                    colBackground: "transparent"
                    materialIcon: "forward_5"
                    releaseAction: () => !!view.player ? view.player.position += 5 : null
                }

                RippleButtonWithIcon {
                    colors: view.colors
                    buttonRadius: Rounding.full
                    implicitSize: 40
                    colBackground: "transparent"
                    materialIcon: "skip_next"
                    releaseAction: () => !!view.player ? view.player?.next() : null
                }
            }
        }
    }
    component PlayerSelector: StyledRect {
        id: root
        clip: true
        visible: repeater?.count > 1
        radius: Rounding.full
        Layout.alignment: Qt.AlignHCenter
        implicitHeight: Math.max(iconSize * 2, playerSelector.height + Padding.massive)
        implicitWidth: Math.min(48, iconSize * 1.5)
        Layout.bottomMargin: -10
        color: root.colors.colLayer2

        property var colors: BeatsService.colors
        readonly property int iconSize: 24

        function getPlayerIcon(dbus) {
            if (!dbus)
                return "music_note";
            const dic = {
                "spotify": "queue_music",
                "firefox": "web",
                "vlc": "play_circle",
                "mpv": "video_library"
            };
            for (const [key, val] of Object.entries(dic)) {
                if (dbus.includes(key))
                    return val;
            }
            return "music_note";
        }

        function getPlayerName(player, index) {
            return player?.identity || player?.dbusName?.replace("org.mpris.MediaPlayer2.", "") || "Player " + (index + 1);
        }

        Rectangle {
            id: activeIndicator
            z: 1
            implicitHeight: iconSize
            implicitWidth: iconSize
            anchors.horizontalCenter: parent.horizontalCenter
            radius: Rounding.full
            color: colors.colPrimary

            readonly property int selectedIndex: BeatsService?.selectedPlayerIndex ?? 0

            y: {
                repeater.count;
                const item = repeater.itemAt(selectedIndex);
                return playerSelector.y + (item ? item.y : 0);
            }

            Behavior on y {
                enabled: repeater.count > 1
                Anim {}
            }

            SequentialAnimation {
                id: stretchAnim
                Anim {
                    target: activeIndicator
                    property: "height"
                    to: iconSize * 1.5
                    duration: Animations.durations.verysmall
                }
                Anim {
                    target: activeIndicator
                    property: "height"
                    to: iconSize
                    duration: Animations.durations.large
                }            
                

            }

            onSelectedIndexChanged: {
                if (repeater.count > 1)
                    stretchAnim.restart();
            }
        }

        CLayout {
            id: playerSelector
            anchors.centerIn: parent
            z: 2
            spacing: Padding.verysmall

            Repeater {
                id: repeater
                model: BeatsService?.players

                delegate: Item {
                    id: symbolItem
                    required property var modelData
                    required property int index
                    readonly property bool isSelected: index === activeIndicator.selectedIndex
                    height: iconSize
                    width: iconSize

                    Symbol {
                        anchors.centerIn: parent
                        fill: 1
                        font.pixelSize: 16
                        text: root.getPlayerIcon(modelData?.dbusName)
                        color: symbolItem.isSelected ? root.colors.colOnPrimary : root.colors.colOnLayer2
                    }

                    MouseArea {
                        cursorShape: Qt.PointingHandCursor
                        anchors.fill: parent
                        
                        onClicked: BeatsService.selectedPlayerIndex = index
                        StyledToolTip {
                            extraVisibleCondition: parent.containsMouse
                            content: root.getPlayerName(modelData, index)
                        }
                    }
                }
            }
        }
    }
}
