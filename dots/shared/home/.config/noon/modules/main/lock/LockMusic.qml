import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

LockTopInfoContainer {
    id: root
    // visible: BeatsService._playing
    implicitHeight: trackInfo.implicitHeight + Padding.massive
    contentItem: RowLayout {
        z: 2
        spacing: Padding.huge
        anchors.fill: parent
        anchors.leftMargin: Padding.huge
        anchors.rightMargin: Padding.huge

        // Cover Art
        MusicCoverArt {
            radius: Rounding.full
            implicitSize: 60
        }

        // Track Info
        ColumnLayout {
            id: trackInfo
            Layout.fillWidth: true
            z: 2
            spacing: 0

            StyledText {
                font: Fonts.request("main", "huge")
                color: Colors.colOnLayer0
                text: BeatsService.title.charAt(0).toUpperCase() + BeatsService.title.slice(1) || "No Media Playing"
                truncate: true
                Layout.fillWidth: true
                maximumLineCount: 2
                Layout.maximumWidth: 300
            }

            StyledText {
                truncate: true
                font: Fonts.request("main", "normal")
                color: Colors.colSubtext
                text: BeatsService.artist || "No Current Artist"
                Layout.maximumWidth: 200
                Layout.fillHeight: true
                Layout.alignment:Qt.AlignTop
            }
        }
    }
}
