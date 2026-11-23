import qs.common
import qs.common.widgets
import qs.services
import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris

Item {
    id: root

    property bool hasLyrics: false
    readonly property MprisPlayer player: MediaPlayerService.player
    readonly property bool isPlaying: player.playbackState === MprisPlaybackState.Playing
    readonly property var trackColors: MediaPlayerService?.colors
    readonly property string iconFont: "Material Symbols Rounded"

    Layout.fillWidth: true
    height: children[0]?.implicitHeight

    ColumnLayout {
        spacing: Padding.veryhuge
        anchors.bottom: parent.bottom
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.margins: Padding.huge
        anchors.bottomMargin: -Padding.normal
        // Spacer {}

        RowLayout {
            Layout.alignment: Qt.AlignBottom | Qt.AlignLeft
            Layout.preferredHeight: 100
            Layout.fillWidth: true
            spacing: Padding.massive

            Revealer {
                reveal: root?.hasLyrics
                implicitWidth: reveal ? 75 : 0
                implicitHeight: 75

                Item {
                    visible: root?.hasLyrics
                    anchors.fill: parent

                    CroppedImage {
                        anchors.centerIn: parent
                        radius: Rounding.large
                        source: MediaPlayerService.artUrl
                        implicitSize: 75
                        tint: true
                        tintLevel: 0.8
                        tintColor: root.trackColors.colSecondaryContainer
                    }
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: -2

                StyledText {
                    Layout.fillWidth: true
                    font: Fonts.request("title", 32)
                    color: root.trackColors.colOnLayer0
                    elide: Text.ElideRight
                    text: root.player.trackTitle || "No Title"
                    horizontalAlignment: Text.AlignLeft
                    truncate: true
                }

                StyledText {
                    Layout.fillWidth: true
                    font: Fonts.request("main", "large")
                    color: root.trackColors.colSubtext
                    elide: Text.ElideRight
                    truncate: true
                    text: root.player.trackArtist || "No Artist"
                    horizontalAlignment: Text.AlignLeft
                }
            }

            IconButton {
                size: 55
                iconSize: 24
                icon: "lyrics"
                toggled: root.hasLyrics
                onClicked: Mem.beats.options.showLyrics = !Mem.beats.options.showLyrics
            }
        }

        Item {
            Layout.fillWidth: true
            implicitHeight: 35

            StyledProgressBar {
                id: progressBar
                anchors.right: parent.right
                anchors.left: parent.left
                sperm: false
                value: root.player ? Math.max(0, Math.min(1, (root.player.position ?? 0) / Math.max(1, root.player.length ?? 1))) : 0
                colors: root.trackColors
                showDot: false
                valueBarHeight: 12
                valueBarGap: 10
                wavelength: 40

                MouseArea {
                    anchors.fill: parent
                    enabled: root.player?.canSeek && root.player?.length > 0
                    hoverEnabled: true

                    property bool isDragging: false

                    onPressed: mouse => {
                        isDragging = true;
                        seekTo(mouse.x);
                    }

                    onPositionChanged: mouse => {
                        if (isDragging)
                            seekTo(mouse.x);
                    }

                    onReleased: isDragging = false

                    function seekTo(x) {
                        if (!root.player?.canSeek || !root.player?.length)
                            return;
                        const ratio = Math.max(0, Math.min(1, x / width));
                        root.player.position = ratio * root.player.length;
                    }
                }
            }

            RowLayout {
                anchors.left: progressBar.left
                anchors.right: progressBar.right
                anchors.top: progressBar.bottom
                anchors.topMargin: Padding.large

                StyledText {
                    text: this.methods.friendlyTimeForSeconds(root.player?.position)
                    color: root.trackColors.colSecondary
                    font: Fonts.request("main", 15)
                }
                Spacer {}
                StyledText {
                    text: this.methods.friendlyTimeForSeconds(root.player?.length)
                    color: root.trackColors.colSecondary
                    font: Fonts.request("main", 15)
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter | Qt.AlignHCenter
            spacing: Padding.silly

            IconButton {
                size: 45
                iconSize: 45
                icon: "skip_previous"
                enabled: root.player?.canGoPrevious
                onClicked: root.player?.previous()
            }

            IconButton {
                size: 74
                iconSize: 70
                fill: 0
                icon: root.isPlaying ? "pause" : "play_arrow"
                enabled: !!root.player
                onClicked: root.player.togglePlaying()
            }

            IconButton {
                size: 45
                iconSize: 45
                icon: "skip_next"
                enabled: root.player?.canGoNext
                onClicked: root.player?.next()
            }
        }
        Spacer {}

        RowLayout {
            Layout.alignment: Qt.AlignBottom
            Layout.fillWidth: true
            Layout.leftMargin: Padding.large
            Layout.rightMargin: Padding.large

            IconButton {
                icon: "shuffle"
                enabled: root.player?.canControl
                toggled: root.player?.shuffle ?? false
                onClicked: root.player && (root.player.shuffle = !root.player.shuffle)
                fill: 0
                iconSize: 24
            }

            Spacer {}

            IconButton {
                icon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                enabled: root.player && root.player.canControl
                toggled: root.player?.loopState !== MprisLoopState.None
                onClicked: MediaPlayerService.cycleRepeat()
                fill: 0
                iconSize: 24
            }

            Spacer {}

            IconButton {
                readonly property string currentTrackPath: Mem.beats.directory + "/" + (BeatsService.currentTrackIndexedInfo?.file ?? "")
                icon: "delete"
                enabled: Paths.methods.exists(currentTrackPath)
                onClicked: deleteConfirmDialog.request(currentTrackPath)
                fill: 0
                iconSize: 24
            }
        }
    }

    BottomDialog {
        id: deleteConfirmDialog
        property string currentFile: ""
        function request(path) {
            if (!path)
                return;
            this.show = true;
            this.currentFile = path;
        }
        colors: root.trackColors
        scrim: false
        baseHeight: 165
        revealOnWheel: false
        enableStagedReveal: false
        bottomAreaReveal: false
        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: Padding.huge
            spacing: Padding.huge

            PageHeader {
                title: "Delete " + decodeURIComponent(Paths.methods.getEscapedFileNameWithoutExtension(deleteConfirmDialog.currentFile))
                colors: root.trackColors
            }

            RowLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
                spacing: Padding.large

                IconButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    icon: "delete"
                    filledBackground: true
                    toggled: true
                    onClicked: {
                        NoonUtils.trash(deleteConfirmDialog.currentFile);
                        deleteConfirmDialog.show = false;
                    }
                }

                IconButton {
                    Layout.fillWidth: true
                    Layout.preferredHeight: 60
                    icon: "close"
                    filledBackground: true
                    onClicked: deleteConfirmDialog.show = false
                }
            }
        }
    }

    component IconButton: Item {
        id: btn

        property string icon: ""
        property int size: iconSize * 2
        property int iconSize: 26
        property bool toggled: false
        property bool filledBackground: false
        property real fill: 1

        signal clicked

        implicitWidth: size
        implicitHeight: size
        opacity: enabled ? 1 : 0.4
        scale: area.pressed ? 0.85 : 1

        Behavior on scale {
            Anim {}
        }

        Rectangle {
            anchors.fill: parent
            radius: Math.min(width, height) / 2
            color: root.trackColors.colLayer2Hover
            opacity: btn.toggled ? 1 : btn.filledBackground ? 0.5 : 0

            Behavior on opacity {
                Anim {}
            }
        }

        Symbol {
            anchors.centerIn: parent
            icon: btn.icon
            iconSize: btn.iconSize
            color: root.trackColors.colOnLayer0
            fill: btn.fill
            animateChange: true
            animationDuration: Animations.durations.normal
        }

        MouseArea {
            id: area
            anchors.fill: parent
            onClicked: btn.clicked()
        }
    }
}
