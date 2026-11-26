import QtQuick
import Quickshell
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services

QuickToggleButton {
    id: root
    visible: Mem.store.misc.systemCommands.indexOf("gpu-screen-recorder") !== -1
    dialogName: "Record"
    buttonName: RecordingService.isRecording ? "Recording " + RecordingService.getFormattedDuration() : "Record"
    toggled: RecordingService.isRecording
    buttonIcon: RecordingService.isRecording ? "radio_button_checked" : "radio_button_unchecked"
    onClicked: !toggled ? RecordingService.record() : RecordingService.stop()

    StyledToolTip {
        extraVisibleCondition: RecordingService.isRecording && !root.showButtonName
        content: root.buttonName
    }
}
