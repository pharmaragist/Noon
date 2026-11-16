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
            property int _layoutWidth: width
            property int _spacing: Padding.large
            property int _baseItemWidth: 320
            property int _columns: Math.max(1, Math.floor((_layoutWidth + _spacing) / (_baseItemWidth + _spacing)))
            property int _cellWidth: (_layoutWidth - (_columns - 1) * _spacing) / _columns
            property int _cellHeight: 120

            onWidthChanged: _layoutWidth = width

            StyledGridView {
                id: grid
                anchors.fill: parent
                columns: parent._columns
                cellWidth: parent._cellWidth
                cellHeight: parent._cellHeight
                _model: NotesService.cards

                delegate: NoteCard {
                    width: grid.cellWidth - Padding.normal
                    height: grid.cellHeight - Padding.normal
                    onClicked: root.openNote(modelData?.name)
                }
            }

            PagePlaceholder {
                shown: NotesService.cards.length === 0
                title: qsTr("No notes yet")
                icon: "stylus"
                anchors.centerIn: parent
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
