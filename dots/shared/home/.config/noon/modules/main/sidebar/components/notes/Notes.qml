import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services

SidebarItemContainer {
    id: root

    StyledStackView {
        id: stack
        anchors.fill: parent
        initialItem: listView
    }

    function openNote(name) {
        NotesService.openNote(name);
        stack.push(editor);
    }

    Component {
        id: listView

        Item {
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Padding.huge

                spacing: Padding.large

                PageHeader {
                    title: "Notes"
                    subTitle: Directories.methods.collapsePath(NotesService.folderPath)
                }

                StyledListView {
                    hinter.anchors.margins: -Padding.huge
                    Layout.fillHeight: true
                    Layout.fillWidth: true
                    spacing: Padding.normal
                    _model: NotesService.cards
                    delegate: NoteCard {
                        anchors.right: parent?.right
                        anchors.left: parent?.left
                        onClicked: root.openNote(modelData?.name)
                    }
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
