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

    ColumnLayout {
        anchors.centerIn: parent
        spacing: 2

        StyledRect {
            Layout.preferredWidth: root.sectionWidth
            Layout.preferredHeight: headerLayout.implicitHeight + (Padding.huge * 2)
            Layout.fillWidth: true
            topRadius: Rounding.verylarge
            bottomRadius: Rounding.verytiny
            color: Colors.colLayer0

            RowLayout {
                id: headerLayout
                anchors.fill: parent
                anchors.margins: Padding.veryhuge
                spacing: 16

                Symbol {
                    leftPadding: Padding.huge
                    Layout.preferredWidth: 44
                    Layout.preferredHeight: 44
                    icon: NetworkService.manager.ethernet ? "lan" : NetworkService.manager.wifi ? "wifi" : "wifi_off"
                    color: NetworkService.manager.ethernet || NetworkService.manager.wifi ? Colors.m3.m3primary : Colors.m3.m3onError
                    font.pixelSize: 26
                }

                ColumnLayout {
                    spacing: 2
                    Layout.fillWidth: true

                    StyledText {
                        text: NetworkService.manager.wifi && NetworkService.manager.networkName ? NetworkService.manager.networkName : NetworkService.manager.ipAddress
                        font: Fonts.request("main", "large", { weight: Font.DemiBold })
                        color: Colors.m3.m3onSurface
                    }

                    StyledText {
                        text: NetworkService.manager.ethernet ? qsTr("Ethernet") : NetworkService.manager.wifi ? qsTr("Wi-Fi") : qsTr("Disconnected")
                        font.pixelSize: Fonts.sizes.small
                        color: Colors.m3.m3onSurfaceVariant
                        visible: NetworkService.manager.ethernet || NetworkService.manager.wifi
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }
                }
            }
        }

        StyledRect {
            Layout.preferredWidth: root.sectionWidth
            Layout.preferredHeight: speedLayout.implicitHeight + (Padding.huge * 2)
            Layout.fillWidth: true
            radius: Rounding.verytiny
            color: Colors.colLayer0
            visible: NetworkService.manager.ethernet || NetworkService.manager.wifi

            RowLayout {
                id: speedLayout
                anchors.fill: parent
                anchors.margins: Padding.veryhuge
                spacing: 24

                RowLayout {
                    Layout.fillWidth: true
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
                            font: Fonts.request("main", "small", { weight: Font.Medium })
                            color: Colors.m3.m3onSurface
                        }
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
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
                            font: Fonts.request("main", "small", { weight: Font.Medium })
                            color: Colors.m3.m3onSurface
                        }
                    }
                }
            }
        }

        StyledRect {
            Layout.preferredWidth: root.sectionWidth
            Layout.preferredHeight: metadataLayout.implicitHeight + (Padding.huge * 2)
            Layout.fillWidth: true
            topRadius: Rounding.verytiny
            bottomRadius: Rounding.verylarge
            color: Colors.colLayer0

            ColumnLayout {
                id: metadataLayout
                anchors.fill: parent
                anchors.margins: Padding.veryhuge
                spacing: 14

                RowLayout {
                    Layout.fillWidth: true
                    visible: NetworkService.manager.wifi && NetworkService.manager.networkStrength > 0

                    RowLayout {
                        spacing: 8
                        Symbol {
                            icon: "broadcast_on_home"
                            color: Colors.m3.m3onSurfaceVariant
                            font.pixelSize: 18
                        }
                        StyledText {
                            text: qsTr("Signal Strength")
                            color: Colors.m3.m3onSurfaceVariant
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: NetworkService.manager.networkStrengthText
                        color: Colors.m3.m3onSurface
                        font.weight: Font.Medium
                    }
                }

                RowLayout {
                    Layout.fillWidth: true

                    RowLayout {
                        spacing: 8
                        Symbol {
                            icon: "lan"
                            color: Colors.m3.m3onSurfaceVariant
                            font.pixelSize: 18
                        }
                        StyledText {
                            text: qsTr("IP Address")
                            color: Colors.m3.m3onSurfaceVariant
                        }
                    }

                    StyledText {
                        Layout.fillWidth: true
                        horizontalAlignment: Text.AlignRight
                        text: NetworkService.manager.ipAddress
                        color: Colors.m3.m3onSurface
                        font.weight: Font.Medium
                        elide: Text.ElideRight
                    }
                }
            }
        }
    }
}
