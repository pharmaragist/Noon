import QtQuick
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root
    anchors.fill: parent

    ScrimOverlay {
        shown: true
    }

    StyledText {
        anchors.margins: Padding.large
        anchors.bottom: parent.bottom
        anchors.right: parent.right
        font: Fonts.request("main", 14)
        color: Colors.colSubtext
        text: "NO VOICES ARE BEING RECORDED EVERYTHING IS RUNNING LOCALLY"
    }

    StyledTextArea {
        id: textArea
        readOnly: true
        font: Fonts.request("reading", 50)
        color: Colors.colOnSurfaceVariant
        text: SpeechService.speech.length > 0 ? SpeechService.speech : (SpeechService.listening ? "Listening ..." : "Say Something ...")
        wrapMode: Text.Wrap
        anchors.centerIn: parent
        width: 800
        height: 600
    }
}
