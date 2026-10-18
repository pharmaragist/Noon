import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Widgets
import qs.common
import qs.common.widgets
import qs.common.functions
import qs.services

FloatingWindow {
    id: root
    minimumSize: Qt.size(1280, 800)
    maximumSize: Qt.size(1280, 800)
    color: Colors.m3.m3surface
    title: "Store"
    readonly property var svc: StoreService
    property string selectedProvider: "kde-store"
    property string selectedCategory: "home"
    property string category: "" // accepted for spawnApp compatibility (detach path), unused
    property string prevProvider: "kde-store"
    property string selectedXdg: ""
    property var activeCats: []
    property string activeCat: ""
    property string query: ""
    property bool loading: false
    property var previewItem: null
    property string previewPath: ""
    property var notices: []
    readonly property var availableCategories: [
        {
            id: "home",
            icon: "home"
        },
        {
            id: "icons",
            icon: "folder"
        },
        {
            id: "cursors",
            icon: "ads_click"
        },
        {
            id: "plugins",
            icon: "extension"
        }
    ]
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
        return status === "error" ? Colors.colError : status === "success" ? Colors.colPrimary : Colors.colSecondary;
    }

    function dlText() {
        const a = svc.dlActive;
        if (!a)
            return "";
        const pct = a.total > 0 ? " " + Math.round(a.progress * 100) + "%" : "";
        const ph = a.phase === "installing" ? "Installing" : "Downloading";
        const q = svc.dlQueue.length ? " (+" + svc.dlQueue.length + " queued)" : "";
        return a.name + " — " + ph + pct + q;
    }

    function dismiss() {
        root.destroy();
    }
    onVisibleChanged: if (!visible)
        root.destroy()

    function xdgForRail(r) {
        return r === "icons" ? "icons" : r === "cursors" ? "cursors" : "";
    }

    function providerById(id) {
        return svc.cache.providers.find(p => p && p.id === id);
    }

    function providerKinds(id) {
        const p = providerById(id || selectedProvider);
        if (p && Array.isArray(p.kinds) && p.kinds.length)
            return p.kinds;
        return null;
    }

    function hubId() {
        // ponytail: Kind truth lives in Go (providers.list kinds); static flag is fallback for old backends.
        const byKind = svc.cache.providers.filter(p => p && Array.isArray(p.kinds) && p.kinds.indexOf("noon-plugin") !== -1);
        if (byKind.length)
            return byKind[0].id;
        const hubs = svc.cache.providers.filter(p => p && p.static);
        return hubs.length ? hubs[0].id : "";
    }

    function ocsProviders() {
        return svc.cache.providers.filter(p => p && !p.static);
    }

    function setRail(r) {
        if (r === "plugins") {
            const hub = hubId();
            if (!hub) {
                root.notify("no plugin hub configured", "error");
                return;
            }
            if (!isStatic())
                root.prevProvider = selectedProvider;
            root.selectedCategory = r;
            root.selectedProvider = hub;
            root.selectedXdg = "";
            root.activeCats = [];
            root.activeCat = "";
            doSearch(searchField.text);
            return;
        }
        if (isStatic())
            root.selectedProvider = root.prevProvider || "kde-store";
        root.selectedCategory = r;
        root.selectedXdg = xdgForRail(r);
        root.activeCats = [];
        root.activeCat = "";
        doSearch(searchField.text);
    }

    function queryObj() {
        return {
            provider: selectedProvider,
            query: root.query,
            xdgType: selectedXdg || "",
            categoryIds: activeCats,
            sort: "",
            // ponytail: OCS latency scales with page size (30 items ~8s warm,
            // 10 items ~1.6s); grid shows ~12, Load more appends the rest.
            pageSize: 15
        };
    }

    function init() {
        // ponytail: the first providers.list is an async RPC, so wait for it
        // before picking the rail — otherwise the Plugins rail can toast
        // "no plugin hub configured" on the very first open.
        svc.ensureProviders((list, err) => {
            svc.ensureCategories(root.selectedProvider);
            root.setRail(root.selectedCategory);
        });
    }

    function doSearch(text) {
        root.query = text || "";
        root.activeCats = [];
        root.activeCat = "";
        root.loading = true;
        try {
            svc.ensureSearch(queryObj(), false, (data, err) => {
                root.loading = false;
                if (err && err.message)
                    root.notify(err.message, "error");
            });
        } catch (e) {
            root.loading = false;
        }
    }

    function loadMore() {
        if (!svc.cache.hasMore || loading)
            return;
        root.loading = true;
        try {
            svc.ensureSearch(queryObj(), true, () => {
                root.loading = false;
            });
        } catch (e) {
            root.loading = false;
        }
    }

    function isStatic() {
        const kinds = providerKinds(selectedProvider);
        if (kinds)
            return kinds.indexOf("noon-plugin") !== -1;
        const p = providerById(selectedProvider);
        return !!(p && p.static);
    }

    function kindFor() {
        if (isStatic())
            return "noon-plugin";
        const k = selectedXdg === "cursors" ? "cursor-theme" : "icon-theme";
        const kinds = providerKinds(selectedProvider);
        if (kinds && kinds.indexOf(k) === -1)
            return kinds[0];
        return k;
    }

    function installItem(item) {
        if (!item || !item.id)
            return;
        const name = item.name || item.id;
        let kind = kindFor();
        let label = name;
        if (isStatic()) {
            const g = item.typeId || activeCats[0] || "";
            if (!g) {
                root.notify("unknown plugin group", "error");
                return;
            }
            const prov = providerById(root.selectedProvider);
            if (prov && Array.isArray(prov.groups) && prov.groups.length && prov.groups.indexOf(g) === -1) {
                root.notify("unknown plugin group", "error");
                return;
            }
            kind = "noon-plugin";
            label = g + "/" + item.id;
        }
        if (!svc.enqueueDownload(root.selectedProvider, item.id, kind, label, (res, err) => {
            if (err)
                root.notify(err.message || "install failed", "error");
            else {
                svc.markInstalled(item.id);
                root.notify("Installed " + name, "success");
            }
        }))
            root.notify(name + " is already queued", "info");
    }

    onPreviewItemChanged: {
        root.previewPath = "";
        const item = root.previewItem;
        const id = item ? item.id : null;
        if (id)
            svc.contentPreview(root.selectedProvider, id, item.previews || [], "", (res, err) => {
                if (!err && res && res.path && root.previewItem && root.previewItem.id === id)
                    root.previewPath = res.path;
            });
    }

    Component.onCompleted: root.init()

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
                    buttonText: modelData?.id ?? ""
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
                        placeholderText: "Search in " + methods.capitalizeFirstLetter(root.selectedCategory) + "..."
                        font: Fonts.request("main", "large")
                        focus: true
                        leftPadding: Padding.massive
                        Keys.onPressed: event => {
                            if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                root.doSearch(searchField.text);
                                event.accepted = true;
                            }
                        }
                        background {
                            implicitHeight: providerBox.implicitHeight
                        }
                    }
                    StyledComboBox {
                        id: providerBox
                        visible: root.selectedCategory !== "plugins"
                        Layout.preferredWidth: 160
                        model: root.ocsProviders().map(p => p.name ?? p.id)
                        currentIndex: root.ocsProviders().findIndex(i => i.id === root.selectedProvider)
                        onActivated: {
                            const p = root.ocsProviders()[providerBox.currentIndex];
                            if (p && p.id) {
                                root.selectedProvider = p.id;
                                root.selectedCategory = p.static ? "plugins" : "home";
                                root.selectedXdg = "";
                                svc.ensureCategories(p.id);
                                root.doSearch(searchField.text);
                            }
                        }
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

                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: Padding.huge
                        spacing: Padding.huge

                        ListView {
                            clip: true
                            visible: count > 0
                            Layout.fillWidth: true
                            Layout.maximumHeight: 45
                            Layout.preferredHeight: 45
                            orientation: Qt.Horizontal
                            spacing: Padding.normal
                            model: svc.chipModel(root.selectedProvider, root.selectedXdg)
                            delegate: IconChip {
                                text: modelData?.name ?? ""
                                icon: modelData?.icon ?? ""
                                toggled: root.activeCat !== "" && root.activeCat === modelData?.id
                                downAction: () => {
                                    if (!modelData || !modelData.id)
                                        return;
                                    root.activeCats = [modelData.id];
                                    root.activeCat = modelData.id;
                                    root.selectedXdg = "";
                                    root.selectedCategory = root.isStatic() ? "plugins" : "home";
                                    root.loading = true;
                                    svc.ensureSearch(root.queryObj(), false, (d, err) => {
                                        root.loading = false;
                                    });
                                }
                            }
                        }

                        StyledGridView {
                            id: gridView
                            Layout.fillWidth: true
                            Layout.fillHeight: true

                            clip: true
                            radius: Rounding.verylarge
                            cellWidth: 180
                            cellHeight: 200
                            reuseItems: false
                            hinter.color: Colors.colLayer0
                            _model: svc.cache.items

                            delegate: StoreItem {
                                grid: gridView
                            }
                            onContentYChanged: {
                                maybeLoadMore();
                                paintVisible();
                            }
                            onContentHeightChanged: {
                                maybeLoadMore();
                                paintVisible();
                            }
                            onCountChanged: paintVisible()

                            function maybeLoadMore() {
                                if (contentHeight > 0 && contentY + height >= contentHeight - height * 0.25)
                                    root.loadMore();
                            }

                            function paintVisible() {
                                if (!count || cellHeight <= 0)
                                    return;
                                const cols = Math.max(1, Math.round(width / cellWidth));
                                const rows = Math.ceil(height / cellHeight) + 1;
                                const first = Math.max(0, Math.floor(contentY / cellHeight)) * cols;
                                const last = Math.min(count, first + rows * cols);
                                for (let i = first; i < last; i++) {
                                    const it = itemAtIndex(i);
                                    if (it)
                                        it.loadThumb();
                                }
                            }
                        }

                        GroupButton {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: Padding.small
                            visible: svc.cache.hasMore && !root.loading
                            buttonText: "Load more"
                            toggled: true
                            downAction: () => root.loadMore()
                        }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            visible: svc.dlActive !== null || svc.dlQueue.length > 0

            StyledText {
                Layout.fillWidth: true
                Layout.leftMargin: Padding.large
                Layout.rightMargin: Padding.large
                font: Fonts.request("main", "verysmall")
                color: Colors.colOnSurfaceVariant
                truncate: true
                text: svc.dlActive ? root.dlText() : svc.dlQueue.length + " queued"
            }
            StyledProgressBar {
                valueBarHeight: 4
                valueBarGap: 4
                Layout.fillWidth: true
                value: svc.dlActive ? svc.dlActive.progress || 0 : 0
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
        anchors.topMargin: loading ? 150 + Padding.large : -150
        Behavior on anchors.topMargin {
            SAnim {}
        }
        visible: loading
        implicitSize: 60
        loading: root.loading
    }

    StyledRect {
        anchors.fill: parent
        visible: root.previewItem !== null
        color: Colors.t(Colors.colScrim, 60)

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
                CroppedImage {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    radius: Rounding.large
                    source: root.previewPath
                    fillMode: Image.PreserveAspectFit
                }
                GroupButtonWithIcon {
                    Layout.alignment: Qt.AlignHCenter
                    baseSize: 40
                    materialIcon: "download"
                    toggled: true
                    onClicked: {
                        root.installItem(root.previewItem);
                        root.previewItem = null;
                    }
                }
            }
        }
    }

    component StoreItem: StyledRect {
        property Item grid: null
        required property var modelData
        required property int index
        property string thumb: ""
        property bool thumbAsked: false

        function loadThumb() {
            if (thumbAsked)
                return;
            thumbAsked = true;
            const item = modelData;
            const id = item ? item.id : null;
            if (id)
                svc.contentPreview(root.selectedProvider, id, item.previews || [], "small", (res, err) => {
                    if (!err && res && res.path && modelData && modelData.id === id)
                        thumb = res.path;
                });
        }
        onModelDataChanged: {
            thumb = "";
            thumbAsked = false;
            if (grid)
                grid.paintVisible();
        }

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
                    onClicked: root.previewItem = modelData
                }

                StyledImage {
                    z: 1
                    mipmap: false
                    anchors.fill: parent
                    source: thumb
                    fillMode: Image.PreserveAspectCrop
                }

                Symbol {
                    anchors.centerIn: parent
                    z: 0
                    visible: thumb === ""
                    icon: modelData?.icon || svc.typeIcon(modelData?.typeName) || "image"
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
                    visible: root.isStatic() && (modelData && modelData.typeId || "") !== ""
                    StyledText {
                        id: badgeText
                        anchors.centerIn: parent
                        text: modelData?.typeId ?? ""
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
                                text: modelData?.installed ? "Installed" : modelData?.downloadsCount ?? 0
                                font: Fonts.request("main", "verysmall")
                                color: Colors.colOnSurfaceVariant
                            }
                        }
                    }

                    GroupButtonWithIcon {
                        baseSize: 32
                        Layout.rightMargin: 6
                        materialIcon: "download"
                        toggled: true
                        onClicked: root.installItem(modelData)
                    }
                }
            }
        }
    }
}
