import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

Item {
    id: root

    signal back

    property bool editing: false
    property int autoSaveInterval: 5000
    property string statusText: ""

    function refreshStatus() {
        if (NotesService.isDirty)
            root.statusText = "Editing...";
        else if (NotesService.lastSaved)
            root.statusText = "Saved " + DateTimeService.friendlyDate(NotesService.lastSaved);
        else
            root.statusText = "Ready";
    }

    Component.onCompleted: {
        textArea.text = NotesService.content;
        refreshStatus();
        textArea.forceActiveFocus();
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.massive
        spacing: Padding.massive

        RowLayout {
            Layout.fillWidth: true
            Layout.maximumHeight: 50
            spacing: Padding.huge

            GroupButtonWithIcon {
                materialIcon: "arrow_back"
                implicitSize: 42
                Layout.fillHeight: false
                Layout.fillWidth: false
                releaseAction: () => root.back()
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0

                StyledText {
                    Layout.fillWidth: true
                    truncate: true
                    text: NotesService.fileName.replace(/\.md$/, "")
                    color: Colors.colOnLayer1
                    font: Fonts.request("title", "subTitle")
                }

                StyledText {
                    Layout.fillWidth: true
                    truncate: true
                    text: root.statusText
                    color: NotesService.isDirty ? Colors.colPrimary : Colors.colSubtext
                    font: Fonts.request("main", "normal")
                }
            }

            GroupButtonWithIcon {
                Layout.fillHeight: false
                Layout.fillWidth: false
                materialIcon: root.editing ? "check" : "edit"
                implicitSize: 42
                toggled: root.editing
                releaseAction: () => root.editing = !root.editing
            }
        }

        StyledTextArea {
            id: textArea
            Layout.topMargin: Padding.massive
            Layout.fillWidth: true
            Layout.fillHeight: true
            color: Colors.m3.m3onSurface
            font: Fonts.request("main", "large")
            selectByMouse: root.editing
            wrapMode: TextArea.Wrap
            readOnly: !root.editing
            textFormat: root.editing ? TextEdit.PlainText : TextEdit.MarkdownText
            placeholderText: root.editing ? "Start typing your notes here..." : "Switch to edit mode to start writing..."
            background: null
            onTextChanged: {
                if (root.editing && text !== NotesService.content) {
                    NotesService.content = text;
                    NotesService.isDirty = true;
                    autoSaveTimer.restart();
                }
            }
            onLinkActivated: link => {
                return Qt.openUrlExternally(link);
            }
            Keys.onPressed: event => {
                if (event.modifiers === Qt.ControlModifier) {
                    if (event.key === Qt.Key_S) {
                        NotesService.save();
                        event.accepted = true;
                    } else if (event.key === Qt.Key_E) {
                        root.editing = !root.editing;
                        event.accepted = true;
                    }
                }
            }
        }
    }

    Timer {
        id: autoSaveTimer

        interval: root.autoSaveInterval
        running: NotesService.isDirty
        repeat: false
        onTriggered: NotesService.save()
    }

    Timer {
        interval: 1000
        running: NotesService.lastSaved !== ""
        repeat: true
        onTriggered: root.refreshStatus()
    }

    Connections {
        target: NotesService

        function onContentChanged() {
            if (!root.editing && textArea.text !== NotesService.content)
                textArea.text = NotesService.content;
            root.refreshStatus();
        }

        function onIsDirtyChanged() {
            root.refreshStatus();
        }

        function onLastSavedChanged() {
            root.refreshStatus();
        }
    }
}
