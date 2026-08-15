import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    id: root

    readonly property var weather: WeatherService.weatherData

    small: Item {
        StyledRect {
            anchors.centerIn: parent
            radius: Rounding.full
            color: Colors.colSecondaryContainer
            implicitSize: 70

            StyledText {
                anchors.centerIn: parent
                text: (weather.current_temp || "—").replace(/C/g, "")
                color: Colors.colOnSecondaryContainer
                font: Fonts.request("numbers", "normal")
                horizontalAlignment: Text.AlignHCenter
            }
        }
    }

    normal: Item {
        property alias shape: shape

        MaterialShape {
            id: shape
            _shape: WeatherService.isLoading ? "Clover8Leaf" : "Pill"
            color: Colors.colSecondaryContainer
            implicitSize: 165
            anchors.centerIn: parent

            RotationAnimation on rotation {
                running: WeatherService?.isLoading ?? false
                duration: 6000
                easing.type: Easing.OutBounce
                loops: Animation.Infinite
                from: 360
                to: 0
            }
        }

        Item {
            visible: !WeatherService.isLoading
            anchors.fill: shape
            anchors.margins: Padding.massive * 1.25

            StyledText {
                id: tempText
                anchors.top: parent.top
                anchors.right: parent.right
                text: root.weather?.current_temp?.replace(/C|c/g, "") ?? "0"
                color: Colors.colOnSecondaryContainer
                font: Fonts.request("banner", shape.implicitSize / 3.5)
            }

            Emoji {
                z: 2
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                text: root.weather.current_emoji ?? "⛅"
                iconSize: shape.implicitSize / 3.5
            }
        }

        ColumnLayout {
            anchors.verticalCenterOffset: Padding.huge
            anchors.centerIn: parent
        }
    }

    large: Item {
        StyledRect {
            anchors.fill: parent
            anchors.margins: Padding.large
            radius: height / 2
            color: Colors.colSecondaryContainer

            RowLayout {
                anchors.fill: parent
                anchors.leftMargin: Padding.massive * 1.25
                anchors.rightMargin: Padding.massive * 1.25

                spacing: Padding.silly

                Emoji {
                    Layout.alignment: Qt.AlignLeft | Qt.AlignVCenter
                    text: root.weather.current_emoji ?? "⛅"
                    iconSize: parent.height / 2
                }

                ColumnLayout {
                    spacing: -Padding.large
                    Layout.preferredHeight: 60
                    Layout.fillWidth: true
                    Layout.alignment: Qt.AlignVCenter | Qt.AlignLeft

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        text: root.weather?.current_temp?.replace(/C|c/g, "") ?? "0"
                        color: Colors.colOnSecondaryContainer
                        font: Fonts.request("banner", 60)
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignLeft
                        text: root.weather?.current_condition ?? ""
                        color: Colors.colSubtext
                        font: Fonts.request("title", 30)
                    }
                }
            }
        }
    }

    xlarge: normal
}
