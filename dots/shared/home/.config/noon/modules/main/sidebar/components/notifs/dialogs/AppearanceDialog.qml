import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

BottomDialog {
    id: root

    baseHeight: parent.height * 0.65

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.large

        PageHeader {
            title: "Appearance"
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Padding.large
            spacing: Padding.large

            RowLayout {
                Layout.preferredHeight: 50
                Layout.fillWidth: true
                spacing: Padding.small

                Symbol {
                    text: Mem.looks.mode === "dark" ? "dark_mode" : "light_mode"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Dark Mode")
                    color: Colors.colOnSurfaceVariant
                }

                StyledSwitch {
                    checked: Mem.looks.mode === "dark"
                    onToggled: {
                        Mem.looks.mode = checked ? "dark" : "light";
                        WallpaperService.toggleShellMode();
                    }
                }
            }

            RowLayout {
                Layout.preferredHeight: 50
                Layout.fillWidth: true
                spacing: Padding.small

                Symbol {
                    text: "schedule"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Auto Mode (Time-based)")
                    color: Colors.colOnSurfaceVariant
                }

                StyledSwitch {
                    checked: Mem.looks.autoShellMode
                    onToggled: Mem.looks.autoShellMode = checked
                }
            }

            RowLayout {
                Layout.preferredHeight: 50
                Layout.fillWidth: true
                spacing: Padding.small

                Symbol {
                    text: "auto_awesome"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Auto Color Scheme")
                    color: Colors.colOnSurfaceVariant
                }

                StyledSwitch {
                    checked: Mem.looks.autoSchemeSelection
                    onToggled: Mem.looks.autoSchemeSelection = checked
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Padding.small

                    Symbol {
                        text: "contrast"
                        font.pixelSize: Fonts.sizes.verylarge
                        color: Colors.colOnSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Contrast")
                        color: Colors.colOnSurfaceVariant
                    }

                    MaterialTextField {
                        Layout.preferredWidth: 120
                        placeholderText: "-1 to 1"
                        text: Mem.looks.contrast ?? 0
                        validator: DoubleValidator { bottom: -1; top: 1; decimals: 2 }
                        onAccepted: Mem.looks.contrast = parseFloat(text) || 0
                    }
                }

                StyledText {
                    Layout.leftMargin: Fonts.sizes.verylarge + Padding.small
                    text: qsTr("Affine lightness transform for the current scheme")
                    font.pixelSize: Fonts.sizes.verysmall
                    color: Colors.colOutline
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Padding.small

                    Symbol {
                        text: "light_mode"
                        font.pixelSize: Fonts.sizes.verylarge
                        color: Colors.colOnSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Lightness")
                        color: Colors.colOnSurfaceVariant
                    }

                    MaterialTextField {
                        Layout.preferredWidth: 120
                        placeholderText: "-1 to 1"
                        text: Mem.looks.lightness ?? 0
                        validator: DoubleValidator { bottom: -1; top: 1; decimals: 2 }
                        onAccepted: Mem.looks.lightness = parseFloat(text) || 0
                    }
                }

                StyledText {
                    Layout.leftMargin: Fonts.sizes.verylarge + Padding.small
                    text: qsTr("Light schemes: -1 (min) to 1 (max)")
                    font.pixelSize: Fonts.sizes.verysmall
                    color: Colors.colOutline
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Padding.small

                    Symbol {
                        text: "dark_mode"
                        font.pixelSize: Fonts.sizes.verylarge
                        color: Colors.colOnSurfaceVariant
                    }

                    StyledText {
                        Layout.fillWidth: true
                        text: qsTr("Darkness")
                        color: Colors.colOnSurfaceVariant
                    }

                    MaterialTextField {
                        Layout.preferredWidth: 120
                        placeholderText: "-1 to 1"
                        text: Mem.looks.darkness ?? 0
                        validator: DoubleValidator { bottom: -1; top: 1; decimals: 2 }
                        onAccepted: Mem.looks.darkness = parseFloat(text) || 0
                    }
                }

                StyledText {
                    Layout.leftMargin: Fonts.sizes.verylarge + Padding.small
                    text: qsTr("Dark schemes: -1 (min) to 1 (max)")
                    font.pixelSize: Fonts.sizes.verysmall
                    color: Colors.colOutline
                }
            }

            Spacer {}
        }

        RowLayout {
            Layout.preferredHeight: 50
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }

            DialogButton {
                buttonText: qsTr("Pick Accent Color")
                onClicked: WallpaperService.pickAccentColor()
            }

            DialogButton {
                buttonText: qsTr("Done")
                onClicked: root.show = false
            }
        }
    }
}
