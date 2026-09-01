import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

import qs.common
import qs.common.widgets
import qs.services

Item {
    id: view
    readonly property var stats: WeatherService.weatherData
    readonly property var todayHourly: (stats.forecast ?? [])[0]?.hourly ?? []
    property date currentTime: new Date()

    readonly property var compassDegrees: ({
            "N": 0,
            "NNE": 22.5,
            "NE": 45,
            "ENE": 67.5,
            "E": 90,
            "ESE": 112.5,
            "SE": 135,
            "SSE": 157.5,
            "S": 180,
            "SSW": 202.5,
            "SW": 225,
            "WSW": 247.5,
            "W": 270,
            "WNW": 292.5,
            "NW": 315,
            "NNW": 337.5
        })

    readonly property real windBearing: view.compassDegrees[stats.wind_direction] ?? 0

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: view.currentTime = new Date()
    }

    readonly property int nearestIndex: {
        var nowMin = currentTime.getHours() * 60 + currentTime.getMinutes();
        var best = 0;
        var bestDiff = Infinity;
        for (var i = 0; i < todayHourly.length; i++) {
            var parts = todayHourly[i].time.split(":");
            var mins = parseInt(parts[0], 10) * 60 + parseInt(parts[1], 10);
            var diff = Math.abs(mins - nowMin);
            if (diff < bestDiff) {
                bestDiff = diff;
                best = i;
            }
        }
        return best;
    }

    function formatTime(t) {
        var parts = t.split(":");
        var h = parseInt(parts[0], 10);
        var suffix = h >= 12 ? "PM" : "AM";
        var h12 = h % 12;
        if (h12 === 0)
            h12 = 12;
        return h12 + ":00 " + suffix;
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.large

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.huge

            ColumnLayout {
                spacing: Padding.small

                RowLayout {
                    spacing: Padding.normal
                    Layout.bottomMargin: Padding.small
                    Item {
                        implicitHeight: children[0].implicitSize
                        implicitWidth: children[0].implicitSize

                        MaterialShape {
                            _shape: "Pill"
                            implicitSize: 64
                            color: Colors.colPrimary

                            Anim on rotation {
                                duration: 8000
                                from: 0
                                to: 360
                            }
                        }
                        Symbol {
                            anchors.centerIn: parent
                            icon: stats.material_icon
                            iconSize: 34
                            color: Colors.colOnPrimary
                        }
                    }

                    StyledText {
                        leftPadding: Padding.large
                        font: Fonts.request("title", 44, {
                            weight: Font.DemiBold
                        })
                        text: stats.current_temp
                        color: Colors.colOnLayer0
                    }
                }

                StyledText {
                    font: Fonts.request("main", 20)
                    text: stats.current_condition
                    color: Colors.colOnLayer0
                }

                StyledText {
                    font: Fonts.request("reading", 16)
                    text: stats.location
                    color: Colors.colSecondary
                }
            }

            Item {
                Layout.fillWidth: true
            }

            ColumnLayout {
                spacing: Padding.normal
                Layout.alignment: Qt.AlignTop

                Item {
                    id: windArrowWrapper
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: windArrow.implicitWidth
                    implicitHeight: windArrow.implicitHeight
                    transformOrigin: Item.Center
                    rotation: view.windBearing

                    RotationAnimation on rotation {
                        from: 360
                        to: view.windBearing
                        duration: 500
                        easing.type: Easing.OutCubic
                    }
                    Behavior on rotation {
                        RotationAnimation {
                            duration: 500
                            direction: RotationAnimation.Shortest
                            easing.type: Easing.OutCubic
                        }
                    }

                    MaterialShape {
                        id: windArrow
                        anchors.centerIn: parent
                        _shape: "Arrow"
                        implicitSize: 54
                        color: Colors.colTertiary
                    }

                    Symbol {
                        icon: "navigation"
                        anchors.centerIn: parent
                        iconSize: 26
                        color: Colors.colOnTertiary
                    }
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    font: Fonts.request("reading", 14)
                    text: stats.wind_direction + " " + stats.wind_speed
                    color: Colors.colSecondary
                }
            }
        }

        ListView {
            Layout.fillWidth: true
            Layout.topMargin: Padding.large
            Layout.preferredHeight: 100
            orientation: ListView.Horizontal
            spacing: Padding.normal
            clip: true
            model: view.todayHourly

            delegate: ColumnLayout {
                required property var modelData
                required property int index
                readonly property bool isNearest: index === view.nearestIndex
                width: 56
                height: ListView.view.height
                spacing: Padding.small

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    font: Fonts.request("main", 18, {
                        weight: Font.DemiBold
                    })
                    text: modelData.temp
                    color: isNearest ? Colors.colPrimary : Colors.colSecondary
                }

                MaterialShapeWrappedSymbol {
                    Layout.alignment: Qt.AlignHCenter
                    _shape: "Cookie9Sided"
                    iconSize: 28
                    text: modelData.material_icon
                    fill: isNearest ? 1 : 0
                    color: isNearest ? Colors.colPrimary : Colors.colSecondary
                    colSymbol: isNearest ? Colors.colOnPrimary : Colors.colOnSecondary
                }

                StyledText {
                    Layout.alignment: Qt.AlignHCenter
                    font: Fonts.request("reading", 13)
                    text: view.formatTime(modelData.time)
                    color: isNearest ? Colors.colPrimary : Colors.colSecondary
                }
            }
        }

        StyledText {
            id: sourceHint
            Layout.alignment: Qt.AlignHCenter
            horizontalAlignment: Text.AlignHCenter
            font: Fonts.request("main", "small")
            color: Colors.colSubtext
            text: "Source: MET"
        }
    }
}
