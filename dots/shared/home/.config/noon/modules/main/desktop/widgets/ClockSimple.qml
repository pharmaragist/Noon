import QtQuick
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.widgets
import qs.vendors.shapes

WidgetContainer {
    id: root

    small: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.small
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: DateTimeService.time.toUpperCase()
            horizontalAlignment: Text.AlignHCenter
            color: Colors.colOnLayer0
            font: Fonts.request("numbers", Fonts.sizes.title * 0.45)
        }
    }

    normal: AnalogClock {
        anchors.fill: parent
        anchors.margins: Padding.huge
    }

    large: RowLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.silly

        AnalogClock {
            Layout.preferredWidth: height
            Layout.fillHeight: true
            showNumerals: true
            font: Fonts.request("banner", 35)
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Padding.small

            StyledText {
                Layout.fillWidth: true
                text: DateTimeService.time.toUpperCase()
                horizontalAlignment: Text.AlignLeft
                color: Colors.colOnLayer0
                font: Fonts.request("numbers", Fonts.sizes.title)
            }

            StyledText {
                Layout.fillWidth: true
                text: DateTimeService.request("dddd, dd MMMM")
                horizontalAlignment: Text.AlignLeft
                color: Colors.colSecondary
                font: Fonts.request("main", "small")
            }
        }
    }

    xlarge: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.large

        AnalogClock {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Math.min(parent.width, parent.height * 0.62)
            Layout.preferredHeight: Layout.preferredWidth
            showNumerals: true
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: Padding.small

            StyledText {
                Layout.fillWidth: true
                text: DateTimeService.time.toUpperCase()
                horizontalAlignment: Text.AlignHCenter
                color: Colors.colOnLayer0
                font: Fonts.request("numbers", Fonts.sizes.title * 1.15)
            }

            StyledText {
                Layout.fillWidth: true
                text: DateTimeService.request("dddd, dd MMMM")
                horizontalAlignment: Text.AlignHCenter
                color: Colors.colSecondary
                font: Fonts.request("main", "small")
            }
        }
    }
}
