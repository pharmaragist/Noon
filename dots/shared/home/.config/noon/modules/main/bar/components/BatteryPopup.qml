import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services

StyledPopup {
    id: root
    contentMargins: 0
    extraVisibilityCondition: BatteryService?.percentage
    contentItem: StyledRect {
        id: main
        clip: true
        color: Colors.colLayer0
        anchors.centerIn: parent
        radius: Rounding.verylarge
        implicitWidth: 300
        implicitHeight: 120

        StyledRect {
            id: progress
            z: 10
            anchors {
                left: parent.left
                top: parent.top
                bottom: parent.bottom
            }
            rightRadius: Rounding.verylarge
            color: {
                const p = BatteryService?.percentage * 100;
                if (p > 0 && p < 15)
                    return Colors.colError;
                if (p >= 85)
                    return Colors.colSuccess;
                return Colors.colPrimary;
            }
            Anim on implicitWidth {
                from: 0
                to: BatteryService?.percentage * main.implicitWidth
                duration: 2500
            }
        }




        ColumnLayout {
            id: rightColumn
            z: 999
            anchors.left: parent.left
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Padding.small
            spacing: -Padding.tiny

            StyledText {
                Layout.fillWidth: true
                color: Colors.t(percentageText.color,0.5)
                font: Fonts.request("title", "verylarge")

                function formatTime(seconds) {
                    var h = Math.floor(seconds / 3600);
                    var m = Math.floor((seconds % 3600) / 60);
                    if (h > 0)
                        return `${h}h, ${m}m`;
                    else
                        return `${m}m`;
                }

                text: BatteryService.percentage === 1 ? "Complete" : BatteryService.isCharging ? formatTime(BatteryService.timeToFull) : formatTime(BatteryService.timeToEmpty)
            }


            RowLayout  {
                Layout.fillHeight: true
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft

                Symbol {
                    visible: BatteryService.isCharging
                    fill: 1
                    text: "bolt"
                    horizontalAlignment: Text.AlignLeft
                    color: Colors.t(percentageText.color,0.5)
                    font.pixelSize: 36
                }

                StyledText {
                    id: percentageText
                    Layout.fillWidth: true
                    text: Math.round(BatteryService.percentage * 100)
                    color: {
                        const p = BatteryService.percentage * 100;

                        if (progress.width < percentageText.contentWidth)
                            return Colors.colOnLayer0

                        else if (p < 15)
                            return Colors.colError;

                        else if (p >= 85)
                            return Colors.colOnSuccess;

                        else return Colors.colOnPrimary;
                    }
                    font: Fonts.request("numbers", 52)
                }
            }
        }
    }
}
