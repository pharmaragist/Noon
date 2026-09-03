import QtQuick
import QtQuick.Layouts
import qs.common
import qs.data

ColumnLayout {
    id: root
    visible: BarData.currentModeInfo.appearance.enableSeparators

    implicitWidth: bg.implicitWidth
    Layout.fillHeight: true
    Layout.alignment: Qt.AlignVCenter
    spacing: 2
    state: BarData.currentModeInfo.appearance.separatorsMode

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
                        implicitHeight: 20
                        implicitWidth: 3
                        radius: 999
                    }
                },
                State {
                    name: "thin"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 1
                        implicitHeight: 20
                        radius: 4
                    }
                },
                State {
                    name: "slant"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 1
                        implicitHeight: 15
                        radius: 999
                        rotation: 15
                    }
                },
                State {
                    name: "thicks"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 3
                        implicitHeight: 5
                        radius: 999
                    }
                },
                State {
                    name: "thins"
                    PropertyChanges {
                        target: bg
                        implicitWidth: 1
                        implicitHeight: 5
                        radius: 4
                    }
                }
            ]
        }
    }
}
