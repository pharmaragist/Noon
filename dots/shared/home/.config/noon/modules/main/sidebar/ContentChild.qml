import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import Quickshell
import qs.common
import qs.common.widgets
import qs.services
import qs.store

Item {
    id: panel
    visible: category.length > 0
    anchors.fill: parent
    anchors.margins: Padding.huge

    required property string category
    required property QtObject colors
    readonly property bool effectiveSearchable: SidebarData.isSearchable(category)
    property string previousCategory: ""
    property bool _detached: false
    property bool _expanded: parentRoot?.expanded
    property bool _aux: false
    property alias searchInput: searchBar.searchInput
    property int selectedTabIndex: 0
    property var parentRoot: Globals.main.sidebar
    readonly property var contentItem: contentStack.currentItem

    signal contentFocusRequested
    signal searchFocusRequested

    onCategoryChanged: {
        if (!category) {
            contentStack.clear();
            previousCategory = category;
            return;
        }
        contentStack.slideDirection = SidebarData.getCategoryDirection(previousCategory, category);
        contentStack.replace(null, SidebarData.getComponentPath(category));
        previousCategory = category;
    }

    RippleButtonWithIcon {
        z: 999
        visible: panel._aux
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: Padding.large

        implicitSize: 45
        materialIcon: "close"
        opacity: this.hovered ? 1 : 0.45
        onClicked: NoonUtils.callIpc("sidebar dismiss_aux")
    }
    ColumnLayout {
        spacing: Padding.large
        clip: true
        anchors.fill: parent

        StyledStackView {
            id: contentStack
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            slideDirection: 1

            onCurrentItemChanged: {
                const _item = contentStack.currentItem;
                if (!_item)
                    return;

                const binds = {
                    "selectedTabIndex": () => panel.selectedTabIndex,
                    "searchQuery": () => searchBar.searchText,
                    "debouncedQuery": () => searchBar.debouncedQuery,
                    "detached": () => panel._detached,
                    "expanded": () => !panel._aux ? panel._expanded : undefined,
                    "panelWindow": () => panel.parentRoot
                };

                for (const [property, value] of Object.entries(binds)) {
                    if (property in _item) {
                        if (property === "expanded" && panel._aux) {
                            continue;
                        }
                        _item[property] = Qt.binding(value);
                    }
                }

                if (_item.searchFocusRequested)
                    _item.searchFocusRequested.connect(() => {
                        if (!panel._aux && searchBar.searchInput && panel.effectiveSearchable)
                            searchBar.searchInput.forceActiveFocus();
                    });

                if (_item.dismiss)
                    _item.dismiss.connect(panel.parentRoot.hide);
            }
        }

        SearchBar {
            id: searchBar
            root: panel
            colors: panel.colors
            contentY: contentStack.y

            property string debouncedQuery: ""

            onSearchTextChanged: debounceTimer.restart()

            Timer {
                id: debounceTimer
                interval: 180
                repeat: false
                onTriggered: searchBar.debouncedQuery = searchBar.searchText
            }

            onContentFocusRequested: {
                if (panel.contentItem && "contentFocusRequested" in panel.contentItem)
                    panel.contentItem.contentFocusRequested();
            }
        }
    }
}
