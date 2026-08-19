import QtQuick
import QtQuick.Layouts
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import qs.store

StyledRect {
    id: searchBar
    signal contentFocusRequested

    required property var colors
    required property var root

    property var action
    property alias searchText: searchInput.text
    property alias searchInput: searchInput

    visible: root.effectiveSearchable && root.category !== ""
    Layout.fillWidth: true
    implicitHeight: root.effectiveSearchable ? 65 : 0

    color: searchInput.focus ? colors.colLayer1Active : colors.colLayer1
    radius: Rounding.full

    Connections {
        target: root
        function onCategoryChanged() {
            searchInput.text = "";
        }
    }

    RLayout {
        anchors.fill: parent
        anchors.leftMargin: Padding.huge
        anchors.rightMargin: Padding.huge
        spacing: Padding.huge

        MaterialShapeWrappedSymbol {
            iconSize: 18
            implicitSize: 38
            Layout.alignment: Qt.AlignVCenter
            Layout.fillHeight: true
            color: searchInput.focus ? colors.colPrimary : colors.colPrimaryContainer
            colSymbol: searchInput.focus ? colors.colOnPrimary : colors.colOnPrimaryContainer
            shape: searchInput.focus ? MaterialShape.Shape.Cookie12Sided : SidebarData.getShape(root.category)
            text: SidebarData.getIcon(root.category) || ""
            fill: 1
        }

        StyledTextField {
            id: searchInput
            Layout.fillHeight: true
            Layout.fillWidth: true
            colors: searchBar.colors
            background: null
            placeholderText: "Search..."
            color: colors.colOnLayer1
            font: Fonts.request("main", "large")

            Keys.onPressed: event => {
                if (!root.effectiveSearchable)
                    return;
                if (event.key === Qt.Return) {
                    if (searchBar.action)
                        searchBar.action();
                    event.accepted = true;
                }
                if (event.key === Qt.Key_Down || event.key === Qt.Key_PageDown) {
                    searchBar.contentFocusRequested();
                    event.accepted = true;
                }
            }
        }

        RippleButtonWithIcon {
            implicitSize: 38
            colors: searchBar.colors
            colBackground: colors.colLayer2Active
            materialIcon: "close"
            visible: searchInput.text.length > 0
            releaseAction: () => {
                searchInput.clear();
                searchInput.focus = true;
            }
        }
    }
}
