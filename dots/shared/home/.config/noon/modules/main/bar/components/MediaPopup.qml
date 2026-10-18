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
        spacing: Padding.large
        Repeater {
            model: MediaPlayerService.players
            delegate: PlayerItem {
                required property var modelData
                required property int index
                player: modelData
                Layout.fillWidth: true
                topRadius: index === 0 ? Rounding.verylarge : Rounding.tiny
                bottomRadius: index === MediaPlayerService.players.length - 1 ? Rounding.verylarge : Rounding.tiny

                implicitWidth: 340
                Layout.preferredHeight: 120
            }
        }
    }

    component PlayerItem: StyledRect {
        id: root
        required property var player
        readonly property var colors: Colors
        color: colors.colLayer0
        clip: true
        enableBorders: true
        radius: Rounding.huge

        BlurredImage {
            z: 0
            source: player?.trackArtUrl
            blur: true
            tintColor: root.colors.colSecondaryContainer
            tint: true
            tintLevel: 0.5
            blurSize: 1
            blurMax: 55
        }

        ShapeBackdrop {
            color: root.colors.colSecondaryContainer
            _shape: "Cookie12Sided"
            implicitSize: 200
            x: parent?.width - this.width + Padding.silly
            y: parent?.height - 2 * Padding.silly
            rotate: true
            opacity: 0.3
            z: 1
        }

        RowLayout {
            z: 2
            anchors.fill: parent
            anchors.margins: Padding.large
            spacing: Padding.verylarge

            StyledRect {
                Layout.leftMargin: Padding.small
                implicitSize: 90
                clip: true
                color: root.colors.colLayer1
                radius: Rounding.large

                Symbol {
                    z: 0
                    icon: "music_note"
                    iconSize: 24
                    color: root.colors.colOnLayer1
                    anchors.centerIn: parent
                }
                StyledImage {
                    z: 1
                    anchors.fill: parent
                    source: player?.trackArtUrl
                }
            }

            ColumnLayout {
                Layout.fillHeight: true
                Layout.fillWidth: true
                spacing: Padding.small

                StyledText {
                    font: Fonts.request("title", "normal")
                    color: Colors.colOnSurface
                    text: this.methods.capitalizeFirstLetter(root.player.trackTitle)
                    truncate: true
                    Layout.fillWidth: true
                    Layout.maximumWidth: 300
                }

                Item {
                    id: lyricsContainer
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    property var lines: []
                    property int currentLine: -1

                    function parseLyrics(text) {
                        if (!text)
                            return [];
                        const rawLines = text.split("\n");
                        const result = [];
                        for (let i = 0; i < rawLines.length; i++) {
                            const l = rawLines[i].trim();
                            if (!l)
                                continue;
                            if (l[0] === "[" && l.indexOf("]") > 0) {
                                const closeIdx = l.indexOf("]");
                                const timeStr = l.substring(1, closeIdx);
                                const lyricsStr = l.substring(closeIdx + 1).trim();
                                if (!lyricsStr)
                                    continue;
                                const splitTime = timeStr.split(":");
                                if (splitTime.length === 2) {
                                    result.push({
                                        t: parseInt(splitTime[0]) * 60 + parseFloat(splitTime[1]),
                                        s: lyricsStr
                                    });
                                }
                            }
                        }
                        return result;
                    }

                    function updateLyrics() {
                        lines = parseLyrics(BeatsService.lyricText);
                    }

                    Component.onCompleted: updateLyrics()

                    Connections {
                        target: BeatsService
                        function onLyricTextChanged() {
                            lyricsContainer.updateLyrics();
                        }
                    }

                    Connections {
                        target: MediaPlayerService
                        function onTitleChanged() {
                            lyricsContainer.lines = [];
                            lyricsContainer.currentLine = -1;
                        }
                    }

                    Timer {
                        running: lyricsContainer.lines.length > 0
                        interval: 100
                        repeat: true
                        onTriggered: {
                            let idx = 0;
                            const currentPos = root.player?.position ?? 0;
                            for (let i = lyricsContainer.lines.length - 1; i >= 0; i--) {
                                if (currentPos >= lyricsContainer.lines[i].t) {
                                    idx = i;
                                    break;
                                }
                            }
                            if (idx !== lyricsContainer.currentLine) {
                                lyricsContainer.currentLine = idx;
                            }
                        }
                    }

                    ColumnLayout {
                        visible: /noon/.test(root.player?.dbusName?.toLowerCase())
                        anchors.fill: parent
                        spacing: 2

                        Repeater {
                            model: 3
                            delegate: StyledText {
                                required property int index
                                property int lineIdx: lyricsContainer.currentLine - 1 + index
                                readonly property bool isCurrent: index === 1
                                readonly property bool hasText: lineIdx >= 0 && lineIdx < lyricsContainer.lines.length
                                horizontalAlignment: Text.AlignHCenter
                                Layout.fillWidth: true
                                text: hasText ? (lyricsContainer.lines[lineIdx].s) : ""
                                color: MediaPlayerService?.colors?.colOnLayer2 ?? Colors.colOnSurface
                                opacity: isCurrent ? 1.0 : (hasText ? 0.4 : 0.0)
                                truncate: true
                                font.family: Fonts.family.variable
                                font.pixelSize: isCurrent ? Fonts.sizes.large : Fonts.sizes.small
                                font.weight: isCurrent ? 600 : 450
                                Layout.maximumWidth: 140
                                Layout.alignment: Qt.AlignHCenter

                                Behavior on font.pixelSize {
                                    Anim {}
                                }
                                Behavior on font.weight {
                                    Anim {}
                                }
                                Behavior on opacity {
                                    Anim {}
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
