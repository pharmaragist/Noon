import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    id: root

    readonly property var forecast: WeatherService.weatherData?.forecast ?? []

    normal: Item {
        anchors.fill: parent

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
                        text: root.isSmall ? "" : DateTimeService.request("dddd, d MMMM")
                        horizontalAlignment: Text.AlignLeft
                        color: Colors.colSubtext
                        font: Fonts.request("main", Fonts.sizes.verysmall)
                    }
                    Spacer {}
                    StyledText {
                        text: DateTimeService.time.toUpperCase()
                        horizontalAlignment: Text.AlignLeft
                        color: Colors.colPrimary
                        font: Fonts.request("numbers", root.isXLarge ? Fonts.sizes.title : (root.isSmall ? Fonts.sizes.subTitle : Fonts.sizes.title - 5))
                    }
                    StyledText {
                        visible: root.isLarge || root.isXLarge
                        Layout.topMargin: Padding.verysmall
                        text: DateTimeService.request("HH:mm:ss")
                        horizontalAlignment: Text.AlignLeft
                        color: Colors.colOnSurfaceVariant
                        font: Fonts.request("numbers", Fonts.sizes.verylarge)
                    }
                }
            }
            Item {
                MouseArea {
                    anchors.fill: parent
                    onClicked: WeatherService.loadWeather()
                }
                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.massive
                    spacing: Padding.small

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Padding.massive

                        MaterialShapeWrappedSymbol {
                            Layout.preferredWidth: (root.isSmall || root.isNormal) ? 44 : 56
                            Layout.preferredHeight: (root.isSmall || root.isNormal) ? 44 : 56
                            shape: MaterialShape.Shape.Cookie6Sided
                            color: Colors.colSecondary
                            padding: Padding.massive
                            fill: 1
                            iconSize: (root.isSmall || root.isNormal) ? 24 : 28
                            colSymbol: Colors.colOnSecondary
                            text: WeatherService.weatherData.material_icon
                        }

                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: Padding.tiny

                            StyledText {
                                text: WeatherService.weatherData.current_temp.replace(/C/g, '')
                                color: Colors.colSecondary
                                font: Fonts.request("numbers", root.isXLarge ? Fonts.sizes.title : Fonts.sizes.subTitle)
                            }
                            StyledText {
                                text: WeatherService.weatherData.current_condition?.trim() || "Loading…"
                                color: Colors.colOnSurfaceVariant
                                font: Fonts.request("main", root.isSmall ? "verysmall" : "small")
                                truncate: true
                            }
                        }
                    }

                    Item {
                        Layout.fillHeight: true
                    }

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Padding.normal

                        WeatherStat {
                            visible: root.isLarge || root.isXLarge
                            icon: "thermostat"
                            label: "Feels"
                            value: WeatherService.weatherData.feels_like
                        }
                        WeatherStat {
                            visible: root.isNormal || root.isLarge || root.isXLarge
                            icon: "cloudy_snowing"
                            label: "Rain"
                            value: root.forecast[0]?.chance_of_rain ?? "—"
                        }
                    }
                }
            }
        }
        M3PageIndicator {
            id: indicator
            anchors.bottom: parent.bottom
            anchors.right: parent.right
            anchors.margins: Padding.large
            currentIndex: view.currentIndex
            count: view.count
        }
    }
    small: normal
    large: normal
    xlarge: normal

    component WeatherStat: ColumnLayout {
        id: stat
        property string icon
        property string label
        property string value

        Layout.fillWidth: true
        spacing: Padding.tiny

        Symbol {
            text: stat.icon
            color: Colors.colPrimary
            fill: 0.5
            iconSize: Fonts.sizes.small
            Layout.alignment: Qt.AlignHCenter
        }
        StyledText {
            text: stat.value
            color: Colors.colOnLayer0
            font: Fonts.request("numbers", "large")
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
        StyledText {
            text: stat.label
            color: Colors.colOnSurfaceVariant
            font: Fonts.request("main", "verysmall")
            horizontalAlignment: Text.AlignHCenter
            Layout.fillWidth: true
        }
    }
}
