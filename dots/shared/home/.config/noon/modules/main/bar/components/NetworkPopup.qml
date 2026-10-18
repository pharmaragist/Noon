import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.data

StyledPopup {
    id: root
    contentMargins: 0
    popupBackgroundMargin: 0
    popupBackgroundBorders: false
    popupBackgroundColor: "transparent"
    property int sectionWidth: 300

    contentItem: StyledRect {
        anchors.centerIn: parent
        implicitWidth: 350
        implicitHeight: 260
        radius: Rounding.huge
        color: Colors.colLayer0
        clip: true

        ShapeBackdrop {
            _shape: "Cookie12Sided"
            implicitSize: 210
            x: parent?.width - this.width + Padding.silly
            y: -Padding.silly
            rotate: true
            opacity: 0.35
        }

        ColumnLayout {
            anchors.fill: parent
            anchors.margins: Padding.large
            spacing: Padding.large

            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 80
                spacing: Padding.huge

                Symbol {
                    leftPadding: Padding.huge
                    icon: NetworkService.manager.materialSymbol
                    color: NetworkService.manager.ethernet || NetworkService.manager.wifi ? Colors.colPrimary : Colors.colError
                    iconSize: 38
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    StyledText {
                        text: NetworkService.manager.wifi && NetworkService.manager.networkName ? NetworkService.manager.networkName : NetworkService.manager.ipAddress
                        font: Fonts.request("main", "large", {
                            weight: Font.DemiBold
                        })
                        color: Colors.m3.m3onSurface
                    }

                    StyledText {
                        text: NetworkService.manager.ipAddress
                        font.pixelSize: Fonts.sizes.small
                        color: Colors.m3.m3onSurfaceVariant
                        visible: NetworkService.manager.ethernet || NetworkService.manager.wifi
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                Layout.fillHeight: true
                radius: Rounding.large
                color: Colors.colLayer1

                ColumnLayout {
                    spacing: Padding.normal
                    anchors.fill: parent
                    anchors.margins: Padding.large

                    RowLayout {
                        id: speedLayout
                        Layout.fillWidth: true
                        Layout.maximumHeight: 50
                        spacing: Padding.normal

                        StyledRect {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: Colors.colLayer2
                            radius: Rounding.large

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                Symbol {
                                    icon: "keyboard_arrow_down"
                                    color: Colors.m3.m3primary
                                    font.pixelSize: 20
                                }

                                ColumnLayout {
                                    spacing: 4

                                    StyledText {
                                        text: qsTr("Download")
                                        font.pixelSize: Fonts.sizes.small
                                        color: Colors.m3.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        text: NetworkService.manager.downloadSpeedText
                                        font: Fonts.request("main", "small", {
                                            weight: Font.Medium
                                        })
                                        color: Colors.m3.m3onSurface
                                    }
                                }
                            }
                        }

                        StyledRect {
                            Layout.fillHeight: true
                            Layout.fillWidth: true
                            color: Colors.colLayer2
                            radius: Rounding.large

                            RowLayout {
                                anchors.centerIn: parent
                                spacing: 10

                                Symbol {
                                    icon: "keyboard_arrow_up"
                                    color: Colors.m3.m3primary
                                    font.pixelSize: 20
                                }

                                ColumnLayout {
                                    spacing: 4

                                    StyledText {
                                        text: qsTr("Upload")
                                        font.pixelSize: Fonts.sizes.small
                                        color: Colors.m3.m3onSurfaceVariant
                                    }

                                    StyledText {
                                        text: NetworkService.manager.uploadSpeedText
                                        font: Fonts.request("main", "small", {
                                            weight: Font.Medium
                                        })
                                        color: Colors.m3.m3onSurface
                                    }
                                }
                            }
                        }
                    }

                    GGraph {
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                    }
                }
            }
        }
    }

    component GGraph: StyledRect {
        id: ggraph
        clip: true
        color: "transparent"

        readonly property int maxPoints: 24
        property var dlHistory: []
        property var ulHistory: []

        function parseSpeed(text) {
            if (!text)
                return 0;
            const m = text.trim().match(/^([\d.]+)\s*(B|KB|MB|GB)\/s$/i);
            if (!m)
                return 0;
            const v = parseFloat(m[1]);
            const mult = {
                "B": 1,
                "KB": 1024,
                "MB": 1024 * 1024,
                "GB": 1024 * 1024 * 1024
            };
            return v * (mult[m[2].toUpperCase()] ?? 1);
        }

        function updateSpeed() {
            const dl = ggraph.parseSpeed(NetworkService.manager.downloadSpeedText);
            const ul = ggraph.parseSpeed(NetworkService.manager.uploadSpeedText);
            let peak = 1;
            for (const v of ggraph.dlHistory)
                peak = Math.max(peak, v);
            for (const v of ggraph.ulHistory)
                peak = Math.max(peak, v);
            peak = Math.max(peak, dl, ul, 1);

            const arrDl = ggraph.dlHistory.concat([dl / peak]);
            const arrUl = ggraph.ulHistory.concat([ul / peak]);
            ggraph.dlHistory = arrDl.slice(-ggraph.maxPoints);
            ggraph.ulHistory = arrUl.slice(-ggraph.maxPoints);
            sync();
        }

        Timer {
            interval: 4000
            repeat: true
            running: true
            onTriggered: ggraph.updateSpeed()
        }

        Graph {
            id: graph
            anchors.margins: Padding.normal
            anchors.fill: parent
            color: Colors.colSecondary
            fillOpacity: 0.35
        }

        Component.onCompleted: ggraph.updateSpeed()

        function sync() {
            graph.series.clear();
            for (var i = 0; i < ggraph.dlHistory.length; ++i)
                graph.series.append(i, ggraph.dlHistory[i]);
        }
    }
}
