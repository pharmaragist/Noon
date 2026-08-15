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
    readonly property MprisPlayer player: BeatsService.player
    readonly property bool isPlaying: player.playbackState === MprisPlaybackState.Playing
    readonly property var trackColors: BeatsService.colors

    Layout.fillWidth: true
    height: children[0]?.implicitHeight

    ColumnLayout {
        spacing: Padding.veryhuge
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right

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
                        source: BeatsService.artUrl
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

            GroupButtonWithIcon {
                baseSize: 55
                colors: root.trackColors
                buttonRadius: implicitSize / 2
                toggled: root.hasLyrics
                materialIcon: "lyrics"
                onClicked: Mem.beats.options.showLyrics = !Mem.beats.options.showLyrics
            }
        }
        Item {
            Layout.fillWidth: true
            implicitHeight: 55

            StyledProgressBar {
                id: progressBar
                

                anchors.right: parent.right
                anchors.left: parent.left

                value: root.player ? Math.max(0, Math.min(1, (root.player.position ?? 0) / Math.max(1, root.player.length ?? 1))) : 0
                highlightColor: root.trackColors.colPrimary
                trackColor: root.trackColors.colSecondaryContainer
                highlightHeight: 36
                showDot: true
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
        
        ButtonGroup {
            spacing: Padding.normal
            Layout.alignment: Qt.AlignHCenter

            MediaButton {
                materialIcon: "skip_previous"
                enabled: root.player?.canGoPrevious
                releaseAction: () => root.player?.previous()
            }

            MediaButton {
                id: playButton
                toggled: !!root.player
                enabled: !!root.player
                onClicked: root.player.togglePlaying()
                buttonRadius: Rounding.huge
                buttonRadiusPressed: Rounding.silly
                materialIcon: root.isPlaying ? "pause" : "play_arrow"
                materialIconFill: 1
            }

            MediaButton {
                materialIcon: "skip_next"
                enabled: root.player?.canGoNext
                releaseAction: () => root.player?.next()
            }
        }

        ButtonGroup {
            Layout.alignment: Qt.AlignHCenter
            color: root.trackColors.colLayer2Hover
            spacing: Padding.verysmall + 1
            padding: 8

            ControlButton {
                symbol.anchors.horizontalCenterOffset: 2
                rightRadius: this.down ? this.buttonRadiusPressed : Rounding.verysmall
                materialIcon: root.player?.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                enabled: root.player && root.player.canControl
                toggled: root.player?.loopState !== MprisLoopState.None
                releaseAction: () => BeatsService.cycleRepeat()
            }

            ControlButton {
                leftRadius: this.down ? this.buttonRadiusPressed : Rounding.verysmall
                rightRadius: this.down ? this.buttonRadiusPressed : Rounding.verysmall

                materialIcon: "shuffle"
                enabled: root.player?.canControl
                toggled: root.player?.shuffle ?? false
                releaseAction: () => {
                    if (root.player)
                        root.player.shuffle = !root.player.shuffle;
                }
            }

            ControlButton {
                readonly property string currentTrackPath: Mem.beats.players.main.musicDirectory + "/" + BeatsService.currentTrackIndexedInfo.file
                leftRadius: this.down ? this.buttonRadiusPressed : Rounding.verysmall
                symbol.anchors.horizontalCenterOffset: -2
                materialIcon: "delete"
                enabled: Directories.methods.exists(currentTrackPath)
                toggled: false
                releaseAction: () => deleteConfirmDialog.request(currentTrackPath)
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
        collapsedHeight: 165
        revealOnWheel: false
        enableStagedReveal: false
        bottomAreaReveal: false
        contentItem: ColumnLayout {
            anchors.fill: parent
            anchors.margins: Padding.huge
            spacing: Padding.huge

            PageHeader {
                title: "Delete " + decodeURIComponent(Directories.methods.getEscapedFileNameWithoutExtension(deleteConfirmDialog.currentFile))
                colors:root.trackColors
            }

            ButtonGroup {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter

                GroupButtonWithIcon {
                    colors:root.trackColors
                    toggled: true
                    materialIcon: "delete"
                    Layout.fillWidth: true
                    baseSize: 60
                    releaseAction: () => {
                        NoonUtils.trash(deleteConfirmDialog.currentFile);
                        deleteConfirmDialog.show = false;
                    }
                }
                GroupButtonWithIcon {
                    colors:root.trackColors
                    materialIcon: "close"
                    Layout.fillWidth: true
                    baseSize: 60
                    releaseAction: () => {
                        deleteConfirmDialog.show = false;
                    }
                }
            }
        }
    }
    component ControlButton: GroupButtonWithIcon {
        id: root
        baseSize: 50
        baseWidth: 70
        layerNumber: 4
        colors: BeatsService.colors
        buttonRadius: Rounding.huge
        buttonRadiusPressed: Rounding.veryhuge
        symbol {
            fill: root.toggled ? 1 : 0
            iconSize: 20
        }
    }
    component MediaButton: GroupButtonWithIcon {
        baseSize: 82
        baseWidth: 100
        layerNumber: 3
        colors: BeatsService.colors
        buttonRadius: Rounding.silly
        buttonRadiusPressed: Rounding.large
        iconSize: 30
        materialIconFill: 0
    }
}
