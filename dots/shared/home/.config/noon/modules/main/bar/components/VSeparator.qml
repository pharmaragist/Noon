import QtQuick
import QtQuick.Layouts
import qs.common
import qs.data

RowLayout {
    id: root
    visible: BarData.currentInfo.appearance.separatorsMode !== "off"

    implicitHeight: bg.implicitHeight
    Layout.fillWidth: true

    Layout.leftMargin: Padding.large
    Layout.rightMargin: Padding.large

    Layout.margins: 4
    spacing: 2
    state: BarData.currentInfo.appearance.separatorsMode
    Repeater {
        model: root.state.endsWith('s') ? 3 : 1
        Rectangle {
            required property var modelData
            required property int index
            id: bg
            color: Colors.colOutlineVariant
            state: root.state
            states: [
                State {
                    name: "slant"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 15
                        implicitHeight: 1
                        radius: 999
                        rotation: 15
                    }
                },
                State {
                    name: "dots"
                    PropertyChanges {
                        target: bg
                        implicitHeight: 4
                        implicitWidth: 4
                        radius: 999
                    }
                },
                State {
                    name: "dot"
                    PropertyChanges {
                        target: bg
                        implicitHeight: 4
                        implicitWidth: 4
                        radius: 999
                    }
                },
                State {
                    name: "thick"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 20
                        implicitHeight: 3
                        radius: 999
                    }
                },
                State {
                    name: "thicks"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 5
                        implicitHeight: 3
                        radius: 999
                    }
                },
                State {
                    name: "thin"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 20
                        implicitHeight: 1
                        radius: 4
                    }
                },
                State {
                    name: "thins"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 5
                        implicitHeight: 1
                        radius: 4
                    }
                }
            ]
        }
    }
}
