import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets

WidgetContainer {
    id: root

    readonly property bool low: BatteryService.isLow && !BatteryService.isCharging
    readonly property color accent: low ? Colors.colError : Colors.colPrimary
    readonly property bool charging: BatteryService.isCharging
    readonly property bool plugged: BatteryService.isPluggedIn

    function formatTime(seconds) {
        return Fonts.methods.friendlyTimeForSeconds(seconds);
    }

    function timeLeft() {
        if (root.charging && BatteryService.timeToFull > 0)
            return "Full in " + root.formatTime(BatteryService.timeToFull);
        if (!root.plugged && BatteryService.timeToEmpty > 0)
            return "Left " + root.formatTime(BatteryService.timeToEmpty);
        return root.plugged ? "Plugged in" : "On battery";
    }

    small: Item {
        anchors.fill: parent
        anchors.margins: Padding.normal

        CircularProgress {
            anchors.centerIn: parent
            implicitSize: Math.min(parent.width, parent.height) - Padding.small
            lineWidth: 5
            sperm: true
            value: BatteryService.percentage

            StyledText {
                anchors.centerIn: parent
                text: Math.round(BatteryService.percentage * 100) + "%"
                color: Colors.colOnLayer0
                font: Fonts.request("numbers", "large")
            }
        }

        Symbol {
            visible: root.charging
            anchors.margins: -Padding.tiny
            anchors.top: parent.top
            anchors.right: parent.right
            text: "bolt"
            color: Colors.colPrimary
            fill: 1
            iconSize: Fonts.sizes.normal
        }
    }

    normal: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.verysmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.normal

            MaterialShapeWrappedSymbol {
                id: badge
                shape: MaterialShape.Shape.Cookie6Sided
                color: Colors.colPrimary
                colSymbol: Colors.colOnPrimary
                text: BatteryService.materialIcon
                iconSize: Fonts.sizes.verylarge
                fill: 1
                padding: Padding.normal
                implicitSize: Fonts.sizes.verylarge + Padding.massive
                Layout.alignment: Qt.AlignVCenter
            }

            Spacer {}
        }

        Spacer {}

        StyledText {
            Layout.fillWidth: true
            text: Math.round(BatteryService.percentage * 100) + "%"
            color: Colors.colOnLayer0
            font: Fonts.request("numbers", Fonts.sizes.subTitle)
            horizontalAlignment: Text.AlignHCenter
        }

        StyledProgressBar {
            Layout.fillWidth: true
            Layout.topMargin: Padding.huge
            value: BatteryService.percentage
            valueBarHeight: 5
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Padding.small
            text: root.timeLeft()
            color: Colors.colOnSurfaceVariant
            font: Fonts.request("main", "verysmall")
            horizontalAlignment: Text.AlignHCenter
        }
    }

    large: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.verysmall

        RowLayout {
            Layout.fillWidth: true
            spacing: Padding.normal

            MaterialShapeWrappedSymbol {
                shape: MaterialShape.Shape.Cookie6Sided
                color: Colors.colPrimary
                colSymbol: Colors.colOnPrimary
                text: BatteryService.materialIcon
                iconSize: Fonts.sizes.verylarge
                fill: 1
                padding: Padding.normal
                implicitSize: Fonts.sizes.verylarge + Padding.massive
                Layout.alignment: Qt.AlignVCenter
            }

            Spacer {}

            StyledText {
                text: root.charging ? "Charging" : (root.plugged ? "Full" : "Discharging")
                color: Colors.colPrimary
                font: Fonts.request("main", "small", {
                    weight: Font.DemiBold
                })
                Layout.alignment: Qt.AlignVCenter
            }
        }

        Spacer {}

        StyledText {
            Layout.fillWidth: true
            text: Math.round(BatteryService.percentage * 100) + "%"
            color: Colors.colOnLayer0
            font: Fonts.request("numbers", Fonts.sizes.title)
            horizontalAlignment: Text.AlignLeft
        }

        StyledProgressBar {
            Layout.fillWidth: true
            Layout.topMargin: Padding.huge
            value: BatteryService.percentage
            valueBarHeight: 7
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Padding.small
            text: root.timeLeft()
            color: Colors.colOnSurfaceVariant
            font: Fonts.request("main", "verysmall")
            horizontalAlignment: Text.AlignLeft
        }
    }

    xlarge: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.veryhuge
        spacing: Padding.veryhuge

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Padding.normal

            StyledText {
                text: root.charging ? "Charging" : (root.plugged ? "Fully Charged" : "Discharging")
                color: Colors.colPrimary
                font: Fonts.request("main", "large", {
                    weight: Font.DemiBold
                })
            }

            Item {
                Layout.preferredHeight: Padding.verysmall
            }

            StatRow {
                icon: root.charging ? "schedule" : "hourglass_bottom"
                label: "Time"
                value: root.timeLeft()
            }

            StatRow {
                icon: root.charging ? "battery_charging_full" : "bolt"
                label: "Power"
                value: BatteryService.energyRate > 0 ? BatteryService.energyRate.toFixed(1) + " W" : "—"
            }

            StatRow {
                icon: "battery_status_good"
                label: "Capacity"
                value: BatteryService.energy > 0 ? BatteryService.energy.toFixed(1) + " Wh" : "—"
            }

            StatRow {
                icon: "favorite"
                label: "Health"
                value: BatteryService.energyCapacity > 0 ? Math.round(BatteryService.energy / BatteryService.energyCapacity * 100) + " %" : "—"
            }

            StatRow {
                icon: root.charging ? "power_settings_new" : "power"
                label: "Source"
                value: root.plugged ? "AC Power" : "Battery"
            }

            StyledText {
                visible: BatteryService.model.length > 0
                Layout.fillWidth: true
                text: BatteryService.model
                color: Colors.colOnSurfaceVariant
                font: Fonts.request("main", "verysmall")
                elide: Text.ElideRight
                horizontalAlignment: Text.AlignRight
            }

            Spacer {}

            StyledProgressBar {
                Layout.fillWidth: true
                value: BatteryService.percentage
                valueBarHeight: 10
                highlightHeight: 25
                trackColor: Colors.colSecondaryContainer
            }
        }
    }

    component StatRow: RowLayout {
        id: row
        property string icon
        property string label
        property string value

        Layout.fillWidth: true
        spacing: Padding.normal

        Symbol {
            text: row.icon
            color: Colors.colPrimary
            fill: 0.6
            iconSize: Fonts.sizes.large
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            text: row.label
            color: Colors.colOnSurfaceVariant
            font: Fonts.request("main", "large")
            Layout.fillWidth: true
        }

        StyledText {
            text: row.value
            color: Colors.colOnLayer0
            font: Fonts.request("main", "large", {
                weight: Font.Medium
            })
            horizontalAlignment: Text.AlignRight
        }
    }
}
