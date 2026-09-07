import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    id: root

    implicitHeight: 114

    anchors {
        right: parent?.right
        left: parent?.left
    }

    color: Colors.colLayer1
    clip: true

    // Local clock used only to refresh the UI.
    property int tick: 0

    readonly property bool isRunning: modelData?.startedIn > 0

    readonly property int remainingTime: {
        tick;

        return TimerService.remainingTime(modelData);
    }

    ColumnLayout {
        anchors {
            margins: Padding.large
            fill: parent
        }

        spacing: 0

        RowLayout {
            Layout.fillHeight: true
            Layout.fillWidth: true

            Layout.leftMargin: Padding.huge
            Layout.rightMargin: Padding.huge

            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignLeft
                Layout.preferredHeight: 40

                spacing: 0

                StyledText {
                    id: duration

                    font: Fonts.request("main", Fonts.sizes.huge)

                    text: TimerService.formatTime(root.remainingTime)

                    color: Colors.colOnLayer1
                }

                StyledText {
                    id: name

                    Layout.fillWidth: true

                    text: modelData?.name ?? ""
                    font.pixelSize: Fonts.sizes.normal
                    color: Colors.colOnLayer1

                    truncate: true
                }
            }

            ButtonGroup {
                id: controls

                Repeater {
                    model: [
                        {
                            materialIcon: root.isRunning ? "pause" : "play_arrow",
                            enabled: !!modelData && root.remainingTime > 0,
                            action: () => {
                                if (root.isRunning)
                                    TimerService.pauseTimer(modelData.id);
                                else
                                    TimerService.startTimer(modelData.id);
                            }
                        },
                        {
                            materialIcon: "restart_alt",
                            enabled: !!modelData,
                            action: () => TimerService.resetTimer(modelData.id)
                        },
                        {
                            materialIcon: "delete",
                            enabled: !!modelData,
                            action: () => TimerService.removeTimer(modelData.id)
                        }
                    ]

                    delegate: GroupButtonWithIcon {
                        required property var modelData

                        baseSize: 40
                        buttonRadius: Rounding.large

                        enabled: modelData.enabled ?? true
                        materialIcon: modelData.materialIcon ?? ""

                        downAction: () => modelData.action()

                        colBackground: Colors.colLayer3

                        Layout.fillHeight: true
                        Layout.fillWidth: true
                    }
                }
            }
        }

        StyledProgressBar {
            Layout.fillWidth: true

            Layout.rightMargin: Padding.large
            Layout.leftMargin: Padding.large

            valueBarHeight: 3
            valueBarGap: 3

            value: {
                if (!root.modelData || root.modelData.duration <= 0)
                    return 0;

                return 1 - (root.remainingTime / root.modelData.duration);
            }

            sperm: true
        }
    }

    Timer {
        interval: 1000
        repeat: true
        running: root.isRunning

        onTriggered: root.tick++
    }
}
