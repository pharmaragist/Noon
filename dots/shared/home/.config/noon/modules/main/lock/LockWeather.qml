import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

LockTopInfoContainer {
    id: root
    contentItem: RLayout {
        z: 999
        anchors.fill: parent
        anchors.rightMargin: Padding.massive * 1.5
        anchors.leftMargin: Padding.massive * 1.5
        spacing: Padding.massive

        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            spacing: 0
            Symbol {
                color: Colors.colOnLayer0
                fill: 0
                font.pixelSize: 28
                horizontalAlignment: Text.AlignHCenter
                text: WeatherService?.weatherData?.currentEmoji ?? "sunny"
            }
            StyledText {
                Layout.leftMargin: -Padding.small
                color: Colors.colOnLayer0
                text: WeatherService?.weatherData.currentCondition
            }
        }

        ColumnLayout {
            anchors.verticalCenter: parent.verticalCenter
            Layout.fillWidth: true
            StyledText {
                color: Colors.colOnLayer0
                font: Fonts.request("main", "large", { weight: 900 })
                text: WeatherService?.weatherData.currentTemp
                horizontalAlignment: Text.alignLeft
                Layout.fillWidth: true
            }
            StyledText {
                color: Colors.colSubtext
                font.pixelSize: Fonts.sizes.small
                text: "Feels Like " + WeatherService?.weatherData.feelsLike
                horizontalAlignment: Text.alignLeft
                Layout.fillWidth: true
            }
        }
    }
}
