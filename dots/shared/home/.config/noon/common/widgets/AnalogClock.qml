import QtQuick
import qs.services
import qs.common
import qs.common.functions

MaterialShape {
        id: dial
        property bool showNumerals: false
        readonly property var currentTime: DateTimeService.clock.date
        property int padding: Padding.massive * 1.25
        property font font: Fonts.request("banner", 50)
        _shape: "Cookie9Sided"
        color: Colors.colSecondaryContainer

        Timer {
            interval: 1000
            running: false
            repeat: true
            onTriggered: dial._shape = dial.random()
        }

        readonly property real hourAngle: (DateTimeService.hour % 12 + DateTimeService.minute / 60 + DateTimeService.second / 3600) * 30
        readonly property real minuteAngle: DateTimeService.minute * 6 + DateTimeService.second / 60 * 6
        readonly property real secondAngle: DateTimeService.second * 6

        StyledText {
            visible: dial.showNumerals
            anchors.top: parent.top
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: dial.padding
            text: "12"
            font: dial.font
            color: Colors.colSecondary
            opacity: 0.35
        }

        StyledText {
            visible: dial.showNumerals
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: dial.padding
            text: "9"
            font: dial.font
            color: Colors.colSecondary
            opacity: 0.35
        }

        StyledText {
            visible: dial.showNumerals
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.margins: dial.padding
            text: "3"
            font: dial.font
            color: Colors.colSecondary
            opacity: 0.35
        }

        StyledText {
            visible: dial.showNumerals
            anchors.bottom: parent.bottom
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.margins: dial.padding
            text: "6"
            font: dial.font
            color: Colors.colSecondary
            opacity: 0.35
        }

        Rectangle {
            id: hourHand
            width: dial.width * 0.14
            height: dial.height * 0.32
            radius: width / 2
            z: 1
            x: dial.width / 2 - width / 2
            y: dial.height / 2 - height
            transformOrigin: Item.Bottom
            rotation: dial.hourAngle
            color: Colors.colPrimary
        }

        Rectangle {
            id: minuteHand
            width: dial.width * 0.018
            height: dial.height * 0.3
            radius: width / 2
            z: 1
            x: dial.width / 2 - width / 2
            y: dial.height / 2 - height
            transformOrigin: Item.Bottom
            rotation: dial.minuteAngle
            color: Colors.colOnLayer0
        }

        Item {
            visible: dial.showNumerals
            x: dial.width / 2 - width / 2
            y: dial.height / 2 - height
            width: dial.width * 0.1
            height: dial.height * 0.38
            rotation: dial.secondAngle
            transformOrigin: Item.Bottom

            MaterialShape {
                anchors.horizontalCenter: parent.horizontalCenter
                anchors.top: parent.top
                implicitSize: parent.width
                _shape: "Triangle"
                rotation: -90
                color: Colors.colPrimary
            }
        }
    }
