import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    id: root
    SwipeView {
        id: view
        orientation: Qt.Horizontal
        interactive: true
        anchors.fill: parent
        clip: true
        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Padding.massive
                spacing: 0
                StyledText {
                    text: Mem.options.services.location
                    horizontalAlignment: Text.AlignLeft
                    color: Colors.colSubtext
                    font: Fonts.request("main", Fonts.sizes.verylarge)
                }
                Spacer {}
                StyledText {
                    text: DateTimeService.time.toUpperCase()
                    horizontalAlignment: Text.AlignLeft
                    color: Colors.colSecondary
                    font: Fonts.request("numbers", Fonts.sizes.title - 5)
                }
            }
        }
        Item {
            MouseArea {
                anchors.fill: parent
                onClicked: WeatherService.loadWeather(true)
            }
            GridLayout {
                anchors.fill: parent
                anchors.margins: Padding.massive
                columns: root.expanded ? 3 : 1
                rows: 2
                MaterialShapeWrappedSymbol {
                    Layout.topMargin: 5
                    Layout.leftMargin: root.expanded ? Padding.massive : 0
                    Layout.fillWidth: !root.expanded
                    Layout.alignment: Qt.AlignVCenter
                    shape: MaterialShape.Shape.Cookie6Sided
                    color: Colors.colSecondary
                    padding: Padding.massive
                    implicitSize: parent.height * 0.7
                    fill: 1
                    iconSize: implicitSize * 0.5
                    colSymbol: Colors.colOnSecondary
                    text: WeatherService.weatherData.currentEmoji
                }
                Spacer {
                    Layout.fillWidth: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    StyledText {
                        visible: root.expanded
                        Layout.fillWidth: true
                        text: WeatherService.currentCity
                        horizontalAlignment: Text.AlignHCenter
                        color: Colors.colSubtext
                        font: Fonts.request("main", Fonts.sizes.verylarge)
                    }
                    Spacer {}
                    StyledText {
                        Layout.fillWidth: true
                        Layout.rightMargin: root.expanded ? 20 : 0
                        text: WeatherService.weatherData.currentTemp.substring(/C/g, '')
                        horizontalAlignment: !root.expanded ? Text.AlignHCenter : Text.AlignRight
                        color: Colors.colSecondary
                        font: Fonts.request("numbers", root.expanded ? Fonts.sizes.title : Fonts.sizes.verylarge)
                    }
                }
            }
        }
    }
    PageIndicator {
        id: indicator

        count: view.count
        currentIndex: view.currentIndex

        anchors.bottom: parent.bottom
        anchors.right: parent.right
        anchors.margins: Padding.huge
        anchors.rightMargin: Padding.huge
    }
}
