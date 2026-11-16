import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.services

// Plugin store. The rail lists plugin groups; the Python service handles the
// Noon-Plugins GitHub index. Layout follows the original Store window.
FloatingWindow {
    id: root
    minimumSize: Qt.size(1280, 800)
    maximumSize: Qt.size(1280, 800)
    color: Colors.m3.m3surface
    title: "Store"

    property string selectedCategory: "all"
    property string query: ""
    property var notices: []
    property var previewItem: null

    readonly property var availableCategories: {
        const out = [
            {
                id: "all",
                name: "All",
                icon: "apps"
            }
        ];
        for (const group of StoreService.groups)
            out.push({
                id: group,
                name: Fonts.methods.capitalizeFirstLetter(group),
                icon: StoreService.groupIcon(group)
            });
        return out;
    }

    readonly property var shown: {
        const text = root.query.trim().toLowerCase();
        return StoreService.plugins.filter(plugin => {
            if (root.selectedCategory !== "all" && plugin.group !== root.selectedCategory)
                return false;
            if (!text)
                return true;
            return [plugin.name, plugin.id, plugin.maintainer, plugin.group].some(
                value => String(value || "").toLowerCase().indexOf(text) !== -1);
        });
    }

    readonly property string searchPlaceholder: {
        if (root.selectedCategory === "all")
            return "Search plugins...";
        return "Search in " + Fonts.methods.capitalizeFirstLetter(root.selectedCategory) + "...";
    }

    readonly property string emptyText: {
        if (StoreService.error !== "")
            return StoreService.error;
        return root.query ? "No plugins match \"" + root.query + "\"" : "No plugins found";
    }

    readonly property string previewMeta: {
        if (!root.previewItem)
            return "";
        return [root.previewItem.group, root.previewItem.maintainer].filter(v => v).join(" · ");
    }

    readonly property string installingName: {
        const plugin = StoreService.plugins.find(p => p && p.id === StoreService.installing);
        return plugin ? plugin.name : StoreService.installing;
    }

    function notify(text, status) {
        const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
        notices = notices.concat([
            {
                id,
                text: String(text),
                status: status || "info"
            }
        ]);
        NoonUtils.inlineTimer(() => {
            notices = notices.filter(n => n.id !== id);
        }, 3500);
    }

    function noteColor(status) {
        if (status === "error")
            return Colors.colError;
        return status === "success" ? Colors.colPrimary : Colors.colSecondary;
    }

    function dismiss() {
        root.destroy();
    }

    function setRail(r) {
        root.selectedCategory = r;
    }

    function installItem(item) {
        if (!item || !item.id || item.installed || StoreService.installing)
            return;
        StoreService.install(item, (res, err) => {
            if (err)
                root.notify(err.message || "install failed", "error");
            else
                root.notify("Installed " + (item.name || item.id), "success");
        });
    }

    onVisibleChanged: if (!visible)
        root.destroy()

    Component.onCompleted: StoreService.ensure((list, err) => {
        if (err)
            root.notify(err.message || "Store unreachable", "error");
    })

    Shortcut {
        sequences: ["/"]
        onActivated: {
            searchField.forceActiveFocus();
            searchField.selectAll();
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 0

        RowLayout {
            Layout.margins: Padding.large
            spacing: Padding.large

            ListView {
                id: navRailList
                implicitWidth: 80
                Layout.topMargin: Padding.large
                Layout.fillHeight: true
                clip: true
                spacing: Padding.small
                model: root.availableCategories
                currentIndex: root.availableCategories.findIndex(i => i && i.id === root.selectedCategory)
                interactive: false
                highlightFollowsCurrentItem: false
                highlight: Item {
                    z: -1
                    width: navRailList.width
                    height: navRailList.currentItem ? navRailList.currentItem.height : 0
                    y: navRailList.currentItem ? navRailList.currentItem.y : 0

                    Behavior on y {
                        SAnim {}
                    }

                    StyledRect {
                        anchors.centerIn: parent
                        width: navRailList.width * 2 / 3
                        height: width * 0.8
                        radius: width / 2
                        color: Colors.colSecondaryContainer
                    }
                }
                delegate: NavigationRailButton {
                    required property var modelData
                    required property int index

                    expanded: true
                    fontSize: 9
                    showText: false
                    anchors.horizontalCenter: parent.horizontalCenter
                    implicitWidth: baseSize
                    baseSize: Math.round(navRailList.width * 0.6)
                    toggled: root.selectedCategory === modelData.id
                    buttonIcon: modelData?.icon ?? ""
                    buttonText: modelData?.name ?? ""
                    highlightColor: "transparent"
                    highlightColorHover: "transparent"
                    highlightColorActive: "transparent"
                    itemColorActive: Colors.colOnSecondaryContainer
                    onClicked: root.setRail(modelData?.id ?? "")
                }
            }

            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 45
                spacing: Padding.huge
                Layout.topMargin: Padding.large

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Padding.huge

                    Symbol {
                        icon: "search"
                        iconSize: 26
                        color: Colors.colOnSurfaceVariant
                    }

                    StyledTextField {
                        id: searchField
                        Layout.fillWidth: true
                        placeholderText: root.searchPlaceholder
                        font: Fonts.request("main", "large")
                        focus: true
                        leftPadding: Padding.massive
                        onTextChanged: root.query = text
                    }
                }

                StyledRect {
                    id: contentBg
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.leftMargin: Padding.large
                    Layout.rightMargin: Padding.large
                    Layout.bottomMargin: Padding.large
                    color: Colors.colLayer1
                    radius: Rounding.verylarge

                    StyledGridView {
                        id: gridView
                        anchors.fill: parent
                        anchors.margins: Padding.huge

                        clip: true
                        radius: Rounding.verylarge
                        cellWidth: 180
                        cellHeight: 200
                        reuseItems: false
                        hinter.color: Colors.colLayer0
                        _model: root.shown

                        delegate: StoreItem {
                            grid: gridView
                        }
                    }

                    ColumnLayout {
                        anchors.centerIn: parent
                        spacing: Padding.normal
                        visible: root.shown.length === 0 && !StoreService.loading

                        Symbol {
                            Layout.alignment: Qt.AlignHCenter
                            icon: StoreService.error ? "cloud_off" : "extension_off"
                            iconSize: 40
                            fill: 1
                            color: Colors.colOnSurfaceVariant
                        }

                        StyledText {
                            Layout.alignment: Qt.AlignHCenter
                            text: root.emptyText
                            font: Fonts.request("main", "small")
                            color: Colors.colOnSurfaceVariant
                        }

                        GroupButton {
                            Layout.alignment: Qt.AlignHCenter
                            visible: StoreService.error !== ""
                            baseWidth: 110
                            baseHeight: 40
                            buttonText: "Retry"
                            toggled: true
                            downAction: StoreService.refresh()
                        }
                    }
                }
            }
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: StoreService.installing !== ""

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Padding.large
                Layout.rightMargin: Padding.large
                font: Fonts.request("main", "verysmall")
                color: Colors.colOnSurfaceVariant
                truncate: true
                text: "Installing " + root.installingName + "..."
            }

            StyledIndeterminateProgressBar {
                Layout.fillWidth: true
                Layout.preferredHeight: 4
            }
        }
    }

    ColumnLayout {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.margins: Padding.large
        anchors.bottomMargin: 70
        spacing: Padding.small
        z: 10000

        Repeater {
            model: root.notices
            delegate: StyledRect {
                required property var modelData
                Layout.alignment: Qt.AlignRight
                implicitWidth: Math.min(360, noteText.implicitWidth + Padding.large * 2 + 12)
                implicitHeight: noteText.implicitHeight + Padding.normal * 2
                radius: Rounding.large
                color: Colors.colLayer1

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.normal
                    spacing: Padding.small

                    Rectangle {
                        width: 4
                        Layout.fillHeight: true
                        radius: 2
                        color: root.noteColor(modelData.status)
                    }

                    StyledText {
                        id: noteText
                        Layout.fillWidth: true
                        text: modelData.text
                        wrapMode: Text.Wrap
                        font: Fonts.request("main", "small")
                        color: Colors.colOnLayer1
                    }
                }
            }
        }
    }

    MaterialLoadingIndicator {
        z: 9999
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: StoreService.loading ? 150 + Padding.large : -150

        Behavior on anchors.topMargin {
            SAnim {}
        }

        visible: StoreService.loading
        implicitSize: 60
        loading: StoreService.loading
    }

    StyledRect {
        anchors.fill: parent
        visible: root.previewItem !== null
        color: Colors.t(Colors.colScrim, 60)
        z: 100

        MouseArea {
            anchors.fill: parent
            onClicked: root.previewItem = null
        }

        StyledRect {
            width: 560
            height: 520
            anchors.centerIn: parent
            radius: Rounding.huge
            color: Colors.colSurfaceContainer

            MouseArea {
                anchors.fill: parent
            }

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Padding.large
                spacing: Padding.large

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Padding.small

                    StyledText {
                        Layout.fillWidth: true
                        text: root.previewItem ? (root.previewItem.name || "") : ""
                        font: Fonts.request("main", "large")
                        color: Colors.colOnSurface
                        wrapMode: Text.Wrap
                    }

                    GroupButtonWithIcon {
                        baseSize: 32
                        materialIcon: "close"
                        toggled: true
                        onClicked: root.previewItem = null
                    }
                }

                StyledRect {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Colors.colLayer1
                    radius: Rounding.large
                    clip: true

                    Symbol {
                        anchors.centerIn: parent
                        icon: root.previewItem && root.previewItem.icon ? root.previewItem.icon : "extension"
                        iconSize: 64
                        fill: 1
                        color: Colors.colOnLayer1
                    }

                    CroppedImage {
                        anchors.fill: parent
                        radius: Rounding.large
                        source: root.previewItem ? (root.previewItem.preview || "") : ""
                    }
                }

                RowLayout {
                    Layout.fillWidth: true
                    spacing: Padding.small

                    StyledText {
                        Layout.fillWidth: true
                        text: root.previewMeta
                        font: Fonts.request("main", "verysmall")
                        color: Colors.colOnSurfaceVariant
                        truncate: true
                    }

                    GroupButtonWithIcon {
                        baseSize: 40
                        materialIcon: root.previewItem && root.previewItem.installed ? "check" : "download"
                        toggled: true
                        enabled: root.previewItem && !root.previewItem.installed
                            && StoreService.installing === ""
                        onClicked: {
                            if (root.previewItem && !root.previewItem.installed)
                                root.installItem(root.previewItem);
                            root.previewItem = null;
                        }
                    }
                }
            }
        }
    }

    component StoreItem: StyledRect {
        property Item grid: null
        required property var modelData
        required property int index

        width: grid?.cellWidth - Padding.normal
        height: grid?.cellHeight - Padding.normal
        clip: true
        radius: Rounding.large
        color: Colors.colLayer1

        ColumnLayout {
            anchors.fill: parent
            spacing: 0

            StyledRect {
                color: "transparent"
                Layout.fillWidth: true
                Layout.fillHeight: true

                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.previewItem = modelData
                }

                StyledImage {
                    id: previewImage
                    z: 1
                    mipmap: false
                    anchors.fill: parent
                    source: modelData && modelData.preview ? modelData.preview : ""
                    asynchronous: true
                    fillMode: Image.PreserveAspectCrop
                    visible: status === Image.Ready
                }

                Symbol {
                    anchors.centerIn: parent
                    z: 0
                    visible: !(modelData && modelData.preview) || previewImage.status !== Image.Ready
                    icon: modelData?.icon
                        || StoreService.groupIcon(modelData ? modelData.group : "")
                        || "image"
                    iconSize: 32
                    fill: 1
                    color: Colors.colOnLayer1
                }

                StyledRect {
                    z: 2
                    anchors.left: parent.left
                    anchors.top: parent.top
                    anchors.margins: Padding.small
                    implicitHeight: 22
                    implicitWidth: badgeText.implicitWidth + Padding.normal * 2
                    radius: Rounding.full
                    color: Colors.colSecondaryContainer
                    visible: (modelData?.group ?? "") !== ""

                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: modelData?.group ?? ""
                        font: Fonts.request("main", "verysmall")
                        color: Colors.colOnSecondaryContainer
                    }
                }
            }

            StyledRect {
                Layout.fillWidth: true
                implicitHeight: 50
                color: Colors.colLayer2

                RowLayout {
                    anchors.fill: parent
                    anchors.margins: Padding.tiny
                    spacing: Padding.small

                    ColumnLayout {
                        Layout.maximumHeight: 55
                        Layout.leftMargin: Padding.large
                        Layout.rightMargin: Padding.large
                        Layout.fillWidth: true

                        StyledText {
                            Layout.fillWidth: true
                            text: modelData ? (modelData.name || "") : ""
                            truncate: true
                            font: Fonts.request("main", "small")
                            color: Colors.colOnLayer1
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 4

                            Symbol {
                                iconSize: 16
                                icon: modelData?.installed ? "check" : "download"
                                color: modelData?.installed ? Colors.colPrimary : Colors.colOnSurfaceVariant
                            }

                            StyledText {
                                Layout.fillWidth: true
                                text: modelData?.installed
                                    ? "Installed"
                                    : (modelData?.maintainer || modelData?.group || "")
                                font: Fonts.request("main", "verysmall")
                                color: Colors.colOnSurfaceVariant
                                truncate: true
                            }
                        }
                    }

                    GroupButtonWithIcon {
                        baseSize: 32
                        Layout.rightMargin: 6
                        visible: modelData && !modelData.installed
                        materialIcon: "download"
                        toggled: true
                        enabled: modelData && StoreService.installing === ""
                        onClicked: root.installItem(modelData)
                    }
                }
            }
        }
    }
}
