import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

StyledPopup {
    id: root

    function yearProgress() {
        const now = DateTimeService.clock.date;
        const start = new Date(now.getFullYear(), 0, 1);
        const end = new Date(now.getFullYear() + 1, 0, 1);
        return (now - start) / (end - start);
    }

    contentItem: Item {
        anchors.centerIn: parent
        implicitHeight: 190
        implicitWidth: 380

        RowLayout {
            anchors.fill: parent

            Item {
                Layout.maximumWidth: parent?.width / 1.65
                Layout.fillHeight: true
                Layout.fillWidth: true
                AnalogClock {
                    anchors.fill: parent
                    anchors.margins: Padding.large
                }
            }

            Rectangle {
                Layout.fillHeight: true
                implicitWidth: 2
                radius: 999
                color: Colors.colOutline
                Layout.topMargin: Padding.massive
                Layout.bottomMargin: Padding.massive
                Layout.margins: Padding.huge
            }

            ColumnLayout {
                Layout.maximumWidth: parent?.width / 2
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: Padding.huge

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Padding.large

                    StyledText {
                        text: DateTimeService.request("yyyy")
                        font: Fonts.request("title", 16)
                        color: Colors.colSubtext
                    }

                    StyledProgressBar {
                        id: progress
                        Layout.fillWidth: true
                        valueBarHeight: 8
                        highlightHeight: 16
                        value: root.yearProgress()
                    }

                    StyledText {
                        text: (root.yearProgress() * 100).toFixed(1) + '%'
                        font: Fonts.request("title", 16)
                        color: Colors.colSubtext
                    }
                }

                MonthCalendar {
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter
                    cellSize: 22
                    showHeader: false
                }
            }
        }
    }
}
