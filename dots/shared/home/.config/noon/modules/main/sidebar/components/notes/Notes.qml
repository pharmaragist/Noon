import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

SidebarItemContainer {
    id: root
    anchors.margins: Padding.small

    ColumnLayout {
        anchors.fill: parent

        StyledStackView {
            id: stack
            initialItem: listView
            Layout.fillWidth: true
            Layout.fillHeight: true
        }

        StyledRect {
            color: Colors.colLayer3
            radius: 999
            implicitHeight: 65
            Layout.fillWidth: true

            RowLayout {
                anchors.fill: parent
                anchors.margins: Padding.verysmall
                anchors.leftMargin: Padding.huge
                anchors.rightMargin: Padding.huge

                spacing: Padding.huge

                StyledRect {
                    implicitSize: 38
                    radius: Rounding.full
                    color: Colors.colPrimary

                    Symbol {
                        anchors.centerIn: parent
                        icon: "edit"
                        iconSize: 20
                        fill: 1
                        color: Colors.colOnPrimary
                    }
                }

                StyledTextField {
                    Layout.fillWidth: true
                    placeholderText: "Create Note"
                    color: Colors.colOnLayer2
                    background: null
                    onAccepted: {
                        NotesService.createNote(this.text);
                        this.text = "";
                    }
                }
            }
        }
    }

    function openNote(name) {
        NotesService.openNote(name);
        stack.push(editor);
    }

    Component {
        id: listView

        Item {
            StyledListView {
                anchors.fill: parent
                spacing: Padding.large
                radius: Rounding.huge
                clip: true
                _model: NotesService.cards
                delegate: NoteCard {
                    anchors.right: parent?.right
                    anchors.left: parent?.left
                    onClicked: root.openNote(modelData?.name)
                }
            }
        }
    }

    Component {
        id: editor

        NoteEditor {
            onBack: stack.pop()
        }
    }
}
