import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Qt5Compat.GraphicalEffects
import QtQuick.Effects
import qs.common
import qs.common.widgets
import qs.services

SidebarItemContainer {
    id: root
    property bool lazy: true
    property bool _pendingFocus: false
    readonly property int totalTabs: tabButtonList.length
    property var _currentChild: null
    property int padding: 0
    readonly property var item: _currentChild
    required property var tabButtonList
    required property string path

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: padding
        spacing: Padding.normal

        StyledLoader {
            readonly property string currentMode : Mem.options.sidebar.appearance.toolbarStyle.toLowerCase().toString();
            Layout.fillWidth: currentMode !== "tool"
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Padding.large
            sourceComponent: {
                let map = {
                    "tool": toolBarComponent,
                    "tab": tabBarComponent
                };
                return map[currentMode] ?? toolbarComponent;
            }

            Component {
                id: tabBarComponent
                PrimaryTabBar {
                    colors: root.colors
                    tabButtonList: root.tabButtonList
                    currentIndex: root.selectedTabIndex
                    externalTrackedTab: root.selectedTabIndex
                    onCurrentIndexChanged: root.selectedTabIndex = currentIndex
                }
            }
            Component {
                id: toolBarComponent

                Toolbar {
                    colors: root.colors
                    ToolbarTabBar {
                        id: tabBar
                        colors: root.colors
                        Layout.alignment: Qt.AlignHCenter
                        tabButtonList: root.tabButtonList
                        currentIndex: root.selectedTabIndex
                        onCurrentIndexChanged: root.selectedTabIndex = currentIndex
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
            onCurrentIndexChanged: root.selectedTabIndex = currentIndex
            spacing: Padding.normal
            clip: true
            radius: Rounding.verylarge

            Repeater {
                model: tabButtonList.map(item => item.component)
                StyledLoader {
                    required property var modelData
                    required property int index
                    readonly property var listData: root.tabButtonList.find(item => item.component === modelData)
                    active: root.lazy ? root.selectedTabIndex === index : true
                    source: root.path + modelData + ".qml"
                    asynchronous: root.lazy && index > 0
                    onLoaded: {
                        const preloadTable = listData?.preloadTable;
                        const preload = listData?.preload;
                        const preloadData = listData?.preloadData;
                        if (preloadTable) {
                            for (const prop in preloadTable) {
                                if ((prop in _item) && (prop in root)) {
                                    const targetProp = prop;
                                    _item[targetProp] = Qt.binding(() => root[targetProp]);
                                }
                            }
                        } else if (preload && (preload in _item) && preloadData !== undefined) {
                            _item[preload] = Qt.binding(() => listData.preloadData);
                        }
                        if ("container" in _item)
                            _item.container = Qt.binding(() => root);

                        if (root.selectedTabIndex === index)
                            root._currentChild = _item;

                        if (root._pendingFocus && root.selectedTabIndex === index) {
                            root._pendingFocus = false;
                            _item.contentFocusRequested();
                        }
                    }
                }
            }
            Keys.onPressed: event => {
                if (event.modifiers === Qt.ControlModifier) {
                    switch (event.key) {
                    case Qt.Key_PageDown:
                        Mem.states.sidebar.apis.selectedTab = Math.min(Mem.states.sidebar.apis.selectedTab + 1, root.tabButtonList.length - 1);
                        event.accepted = true;
                        break;
                    case Qt.Key_PageUp:
                        Mem.states.sidebar.apis.selectedTab = Math.max(Mem.states.sidebar.apis.selectedTab - 1, 0);
                        event.accepted = true;
                        break;
                    case Qt.Key_Tab:
                        Mem.states.sidebar.apis.selectedTab = (Mem.states.sidebar.apis.selectedTab + 1) % root.tabButtonList.length;
                        event.accepted = true;
                        break;
                    case Qt.Key_Backtab:
                        Mem.states.sidebar.apis.selectedTab = (Mem.states.sidebar.apis.selectedTab - 1 + root.tabButtonList.length) % root.tabButtonList.length;
                        event.accepted = true;
                        break;
                    case Qt.Key_O:
                        root.expandRequested();
                        event.accepted = true;
                        break;
                    }
                }
            }
        }
    }
    
    Connections {
        target: root.item
        ignoreUnknownSignals: true

        function onSearchFocusRequested() {
            root.searchFocusRequested();
        }
        function onDismiss() {
            root.dismiss();
        }
    }
    onSelectedTabIndexChanged: {
        if (root.selectedTabIndex < 0)
            return;
        root._currentChild = null;
        if (root.item)
            root.item.contentFocusRequested();
        else
            root._pendingFocus = true;
    }
    onContentFocusRequested: {
        if (root.item)
            root.item.contentFocusRequested();
        else
            root._pendingFocus = true;
    }
}
