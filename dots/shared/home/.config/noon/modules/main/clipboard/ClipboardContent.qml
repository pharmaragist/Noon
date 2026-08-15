import QtQuick
import QtQuick.Layouts

import qs.common
import qs.services
import qs.common.widgets
import qs.common.utils

Item {
    id: root
    readonly property alias searchInput: searchInput
    readonly property alias currentItem: swipeView.currentItem
    property bool showSearchBar: false
    property int selectedTabIndex: modes.findIndex(i => i.name === mode)
    readonly property string mode: Globals.main.clipboard.mode.toLowerCase().trim()
    readonly property var modes: [
        {
            "icon": "content_paste",
            "name": "history"
        },
        {
            "icon": "sentiment_calm",
            "name": "emoji"
        }
    ]

    anchors.fill: parent
    anchors.margins: Padding.huge

    function dispatch(text) {
        if (!text)
            return;

        ClipboardService.copy(text);
        Qt.callLater(() => root.dismiss());
    }

    function dismiss() {
        Globals.main.clipboard.mode = "";
    }

    function switchMode(mode) {
        if (!mode)
            return;
        Globals.main.clipboard.mode = mode;
    }

    function _get(propery) {
        return root.modes[root.selectedTabIndex][propery];
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: Padding.huge

        Toolbar {
            Layout.alignment: Qt.AlignHCenter
            ToolbarTabBar {
                tabButtonList: root.modes
                onCurrentIndexChanged: root.selectedTabIndex = currentIndex
                currentIndex: swipeView.currentIndex
            }
        }

        Revealer {
            Layout.fillWidth: true
            reveal: root.showSearchBar
            vertical: true

            LayerRect {
                anchors.left: parent?.left
                anchors.right: parent?.right

                implicitHeight: 50
                radius: Rounding.verylarge
                colBackground: Colors.colLayer1

                RowLayout {
                    anchors.fill: parent
                    anchors.leftMargin: Padding.huge
                    anchors.rightMargin: Padding.huge

                    MaterialShapeWrappedSymbol {
                        text: root._get("icon") ?? ""
                        shape: MaterialShape.Shape.Cookie9Sided
                        iconSize: 16
                        color: Colors.colPrimaryContainer
                        colSymbol: Colors.colOnPrimaryContainer
                    }

                    StyledTextField {
                        id: searchInput

                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        background: null
                        placeholderText: "Search..."
                        placeholderTextColor: focus ? Colors.colOnSecondaryContainer : Colors.colOutline
                        selectionColor: Colors.colSecondary
                        selectedTextColor: Colors.colOnSecondary
                        color: Colors.colOnLayer1
                        selectByMouse: true
                        font: Fonts.request("main", "normal")

                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Down) {
                                swipeView.currentItem.focusView();
                                event.accepted = true;
                            }
                        }
                    }

                    GroupButtonWithIcon {
                        visible: !!searchInput.text.trim()
                        materialIcon: "close"
                        buttonRadius: Rounding.huge
                        releaseAction: () => {
                            searchInput.text = "";
                        }
                    }
                }
            }
        }

        StyledSwipeView {
            id: swipeView

            Layout.topMargin: Padding.huge
            Layout.fillWidth: true
            Layout.fillHeight: true
            currentIndex: root.selectedTabIndex
            spacing: Padding.normal
            clip: true
            radius: Rounding.verylarge
            ClipboardListView {}
            EmojiGridView {}

            Keys.onPressed: event => {
                const view = currentItem;
                if (!view)
                    return;

                if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_Left) {
                    root.selectedTabIndex = Math.max(0, root.selectedTabIndex - 1);
                    currentItem.focusView();
                    event.accepted = true;
                } else if (event.modifiers & Qt.ControlModifier && event.key === Qt.Key_Right) {
                    root.selectedTabIndex = Math.min(root.modes.length - 1, root.selectedTabIndex + 1);
                    currentItem.focusView();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Up) {
                    view.navigateUp();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Down) {
                    view.navigateDown();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Left) {
                    view.navigateLeft();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Right) {
                    view.navigateRight();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                    view.dispatchCurrent();
                    event.accepted = true;
                } else if (event.key === Qt.Key_Escape) {
                    root.dismiss();
                    event.accepted = true;
                }
            }
        }
    }
}
