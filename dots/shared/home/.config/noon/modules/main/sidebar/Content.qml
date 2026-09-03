import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs.common
import qs.common.widgets
import qs.services
import qs.data

import "components/plugins"
import "components/games"
import "components/cast"
import "components/apps"
import "components/notes"
import "components/timers"
import "components/apis"
import "components/beats"
import "components/sounds"
import "components/etc"
import "components/notifs"
import "components/settings"
import "components/shelf"
import "components/tasks"
import "components/view"
import "components/wallpapers"
import "components/widgets"

Item {
    id: root

    required property var panelWindow
    readonly property bool hovered: mouseArea?.containsMouse ?? false
    readonly property alias rail: rail
    readonly property var colors: SidebarData.getColors(selectedCategory)
    property bool auxVisible: false
    property string selectedCategory: ""
    property string auxCategory: ""
    property string auxSearchText: ""
    property int selectedTabIndex: 0
    property bool isResizing: false
    property int resizeDuration: Animations.durations.small
    readonly property int targetWidth: panelWindow?.sidebarWidth
    readonly property var mainContentItem: mainContentLoader._item._item

    onWidthChanged: isResizing = true
    Timer {
        running: root.isResizing
        repeat: true
        interval: resizeDuration + 50
        onTriggered: if (root.targetWidth === root.width)
            root.isResizing = false
    }

    function dismiss() {
        panelWindow.hide();
    }
    function changeContent(newCategoryKey) {
        if (!newCategoryKey || !SidebarData.enabledCategories.includes(newCategoryKey) && !SidebarData.isStealth(newCategoryKey))
            return;

        if (selectedCategory === newCategoryKey) {
            panelWindow.hide();
            return;
        }
        if (!panelWindow.show)
            panelWindow.hoverMode = false;

        selectedCategory = newCategoryKey;
    }

    function incubateContent(cat) {
        panelWindow.incubate(cat);
    }

    function toggleAux(categoryKey) {
        const enabled = SidebarData.enabledCategories.includes(categoryKey);
        if (!categoryKey || !enabled || categoryKey === "")
            return;

        if (auxVisible && auxCategory === categoryKey) {
            closeAux();
            return;
        }
        openAux(categoryKey);
    }

    function openAux(cat) {
        auxSearchText = "";
        auxCategory = cat;
        auxVisible = true;
    }

    function closeAux() {
        auxVisible = false;
        auxCategory = "";
        auxSearchText = "";
    }

    anchors.fill: parent
    clip: true
    focus: true
    onAuxCategoryChanged: toggleAux()

    Keys.onPressed: event => {
        const {
            key,
            modifiers: mods
        } = event;
        const isCtrl = mods === Qt.ControlModifier;
        const isShift = mods === Qt.ShiftModifier || mods === (Qt.ControlModifier | Qt.ShiftModifier);

        if (key === Qt.Key_Slash)
            return focusMainSearchInput(), event.accepted = true;
        if (key === Qt.Key_Escape)
            return dismiss(), event.accepted = true;
        if (key === Qt.Key_Tab || key === Qt.Key_Backtab) {
            const target = SidebarData[isShift ? "getPreviousEnabledCategory" : "getNextEnabledCategory"](selectedCategory);
            return target && changeContent(target), event.accepted = true;
        }

        const ctrlMap = {
            [Qt.Key_O]: () => SidebarData.isExpandable(selectedCategory) && !auxVisible && (panelWindow.expanded = !panelWindow.expanded),
            [Qt.Key_P]: () => panelWindow.pinned = !panelWindow.pinned,
            [Qt.Key_Q]: () => Qt.callLater(closeAux),
            [Qt.Key_R]: () => selectedCategory === "History" && ClipboardService.wipe()
        };

        if (isCtrl && ctrlMap[key])
            return ctrlMap[key](), event.accepted = true;
    }

    Connections {
        function onFlowChanged() {
            if (PolkitService.flow)
                changeContent("Auth");
            else
                root.panelWindow.hide();
        }

        target: PolkitService
    }

    HoverHandler {
        id: mouseArea
        anchors.fill: parent
    }

    RowLayout {
        anchors.fill: parent
        layoutDirection: (panelWindow.rightMode ^ Mem.options.sidebar.navRail.reverse) ? Qt.RightToLeft : Qt.LeftToRight
        spacing: SidebarData.getPadding(root.selectedCategory) ?? Padding.normal

        SidebarNavigationRail {
            id: rail
            panel: panelWindow
            content: root
            selectedCategory: root.selectedCategory
            colors: root?.colors
            radius: panelWindow.appearanceMode > 0 ? panelWindow.rounding : 0
        }

        Item {
            Layout.fillHeight: true
            Layout.fillWidth: true

            StyledLoader {
                id: mainContentLoader
                active: true
                fade: true
                sourceComponent: Mem.options.sidebar.behavior.enableResizeOverlay && SidebarData.isLazy(root.selectedCategory) && root.isResizing ? overlay : contentRow
                anchors.fill: parent

                readonly property Component overlay: ResizeOverlay {
                    cat: root?.selectedCategory ?? ""
                }
                readonly property Component contentRow: RowLayout {
                    anchors.fill: parent
                    spacing: 0

                    StyledLoader {
                        id: mainLoader

                        asynchronous: SidebarData.isAsync(root.selectedCategory)

                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        sourceComponent: SidebarData.detachedContent.includes(root.selectedCategory) ? placeholder : content
                        onLoaded: if (ready) {
                            if ("focusItem" in item)
                                item?.focusItem?.forceActiveFocus();
                        }
                        readonly property Component content: ContentChild {
                            colors: root?.colors
                            category: root?.selectedCategory
                            selectedTabIndex: root?.selectedTabIndex
                            anchors.margins: SidebarData.getPadding(root.selectedCategory) ?? Padding.huge
                        }
                        readonly property Component placeholder: PagePlaceholder {
                            colors: root.colors
                            shape: SidebarData.getShape(root.selectedCategory)
                            icon: SidebarData.getIcon(root.selectedCategory)
                            iconSize: 80
                            title: "This Content is Detached"
                            description: "close it so u can access it here"
                        }
                    }

                    VerticalSeparator {
                        visible: root.auxVisible
                    }

                    StyledLoader {
                        id: auxLoader
                        asynchronous: true
                        visible: root.auxVisible
                        active: root.auxVisible
                        Layout.fillHeight: true
                        width: SidebarData.currentSize(false, false, root.auxCategory, true)

                        sourceComponent: ContentChild {
                            anchors.margins: SidebarData.getPadding(root.auxCategory) ?? Padding.huge
                            _aux: true
                            category: auxCategory
                            colors: Colors
                        }
                    }
                }
            }
        }
    }

    ActionsMenu {
        id: actionsMenu
        panelWindow: panelWindow

        Connections {
            target: rail
            function onShowContextMenu(category, globalX, globalY) {
                actionsMenu.show(category, globalX, globalY);
            }
        }
    }
}
