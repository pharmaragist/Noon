import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

BottomDialog {
    id: root

    collapsedHeight: Math.max(parent.height * 0.6, 480)

    readonly property bool autoEnabled: Mem.options.services.nightLight.autoNightLightCycle ?? false

    contentItem: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.verylarge
        spacing: Padding.large

        PageHeader {
            title: qsTr("Nightlight")
            subTitle: qsTr("Warm color temperature filter")
        }


        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Padding.large
            spacing: Padding.large

            RowLayout {
                Layout.fillWidth: true
                spacing: Padding.large

                Symbol {
                    text: "nightlight"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Enable")
                    color: Colors.colOnSurfaceVariant
                }

                StyledSwitch {
                    checked: Mem.states.services.nightLight.enabled
                    onToggled: Mem.states.services.nightLight.enabled = checked
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Padding.large

                Symbol {
                    text: "schedule"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Auto (on a schedule)")
                    color: Colors.colOnSurfaceVariant
                }

                StyledSwitch {
                    checked: root.autoEnabled
                    onToggled: Mem.options.services.nightLight.autoNightLightCycle = checked
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Padding.large
                enabled: !root.autoEnabled
                opacity: root.autoEnabled ? 0.4 : 1

                Symbol {
                    text: "device_thermostat"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Temperature")
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    text: Math.round(Mem.states.services.nightLight.temperature) + "K"
                    color: Colors.colOnSurfaceVariant
                    opacity: 0.7
                }

                StyledSlider {
                    from: 3000
                    to: 6500
                    implicitWidth: 120
                    value: Mem.states.services.nightLight.temperature
                    onMoved: Mem.states.services.nightLight.temperature = value
                    enableTooltip: false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Padding.large
                enabled: root.autoEnabled
                opacity: root.autoEnabled ? 1 : 0.4

                Symbol {
                    text: "light_mode"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Day temperature")
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    text: Math.round(Mem.options.services.nightLight.autoDayTemp ?? 6400) + "K"
                    color: Colors.colOnSurfaceVariant
                    opacity: 0.7
                }

                StyledSlider {
                    from: 3000
                    to: 6500
                    implicitWidth: 120
                    value: Mem.options.services.nightLight.autoDayTemp ?? 6400
                    onMoved: Mem.options.services.nightLight.autoDayTemp = value
                    enableTooltip: false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Padding.large
                enabled: root.autoEnabled
                opacity: root.autoEnabled ? 1 : 0.4

                Symbol {
                    text: "dark_mode"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Night temperature")
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    text: Math.round(Mem.options.services.nightLight.autoNightTemp ?? 3500) + "K"
                    color: Colors.colOnSurfaceVariant
                    opacity: 0.7
                }

                StyledSlider {
                    from: 3000
                    to: 6500
                    implicitWidth: 120
                    value: Mem.options.services.nightLight.autoNightTemp ?? 3500
                    onMoved: Mem.options.services.nightLight.autoNightTemp = value
                    enableTooltip: false
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Padding.large
                enabled: root.autoEnabled
                opacity: root.autoEnabled ? 1 : 0.4

                Symbol {
                    text: "wb_twilight"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("Start")
                    color: Colors.colOnSurfaceVariant
                }

                HourMinuteField {
                    Layout.preferredWidth: 90
                    value: Mem.options.services.nightLight.autoStart ?? "20:00"
                    onValueEdited: (v) => Mem.options.services.nightLight.autoStart = v
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Padding.large
                enabled: root.autoEnabled
                opacity: root.autoEnabled ? 1 : 0.4

                Symbol {
                    text: "wb_sunny"
                    font.pixelSize: Fonts.sizes.verylarge
                    color: Colors.colOnSurfaceVariant
                }

                StyledText {
                    Layout.fillWidth: true
                    text: qsTr("End")
                    color: Colors.colOnSurfaceVariant
                }

                HourMinuteField {
                    Layout.preferredWidth: 90
                    value: Mem.options.services.nightLight.autoEnd ?? "06:00"
                    onValueEdited: v => Mem.options.services.nightLight.autoEnd = v
                }
            }
        }

        RowLayout {
            Layout.preferredHeight: 50
            Layout.fillWidth: true

            Item {
                Layout.fillWidth: true
            }

            DialogButton {
                buttonText: qsTr("Done")
                onClicked: root.show = false
            }
        }
    }

    component HourMinuteField: MaterialTextField {
        property string value: "20:00"
        signal valueEdited(string v)

        text: value
        placeholderText: qsTr("HH:MM")
        inputMethodHints: Qt.ImhFormattedNumbersOnly
        validator: RegularExpressionValidator {
            regularExpression: /^([01]?\d|2[0-3]):[0-5]\d$/
        }

        onEditingFinished: {
            if (acceptableInput)
                valueEdited(text);
            else
                text = value;
        }
    }
}
