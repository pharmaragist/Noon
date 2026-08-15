import QtQuick
import qs.store
import qs.common
import qs.common.widgets
import qs.modules.main.desktop.widgets

SidebarItemContainer {
    id: root
    property int pinnedCount: 0
    readonly property var store: Mem.states.sidebar.widgets
    readonly property int halfCols: expanded ? 8 : 4
    readonly property int cellSize: 190
    readonly property int gridSpacing: Padding.huge
    readonly property int halfUnit: (cellSize + gridSpacing) / 2
    readonly property var db: WidgetsData.db
    color: Colors.colLayer1

    function sizeSpan(size) {
        switch (size) {
        case "small":
            return {
                w: 1,
                h: 1
            };
        case "large":
            return {
                w: 4,
                h: 2
            };
        case "xlarge":
            return {
                w: 4,
                h: 4
            };
        default:
            return {
                w: 2,
                h: 2
            };
        }
    }

    function sizeWidth(span) {
        return root.cellSize * span.w / 2 + (span.w > 2 ? root.gridSpacing : 0);
    }

    function sizeHeight(span) {
        return root.cellSize * span.h / 2 + (span.h > 2 ? root.gridSpacing : 0);
    }

    function initOrder() {
        if (root.db.length === 0)
            return;
        let ids = root.db.map(e => e.id);
        let kept = store.items.filter(w => ids.indexOf(w.id) !== -1);
        let missing = ids.filter(id => !kept.some(w => w.id === id));
        let migrated = kept.some(w => w.size === undefined);
        if (kept.length === store.items.length && missing.length === 0 && !migrated)
            return;
        store.items = kept.map(w => ({
                    id: w.id,
                    enabled: w.enabled,
                    desktop: w.desktop,
                    pin: w.pin,
                    pill: w.pill,
                    size: w.size ?? (w.expanded ? "large" : "normal")
                })).concat(missing.map(id => ({
                    id,
                    enabled: false,
                    desktop: false,
                    pin: false,
                    pill: false,
                    size: "normal"
                })));
    }

    function moveItem(fromId, toGX, toGY) {
        let items = store.items.slice();
        let fromIdx = items.findIndex(w => w.id === fromId);
        if (fromIdx === -1)
            return;

        let fromSpan = root.sizeSpan(items[fromIdx].size);
        let isFromSmall = fromSpan.w === 1 && fromSpan.h === 1;

        let quadOriginX = Math.floor(toGX / 2) * 2;
        let quadOriginY = Math.floor(toGY / 2) * 2;

        let targetId = null;
        let targetIsSmall = false;

        for (let i = 0; i < widgetRepeater.count; i++) {
            let item = widgetRepeater.itemAt(i);
            if (!item?.active || item.widgetId === fromId)
                continue;
            if (item.gX === toGX && item.gY === toGY) {
                targetId = item.widgetId;
                targetIsSmall = item.span.w === 1 && item.span.h === 1;
                break;
            }
        }

        if (targetId === null && isFromSmall) {
            for (let i = 0; i < widgetRepeater.count; i++) {
                let item = widgetRepeater.itemAt(i);
                if (!item?.active || item.widgetId === fromId)
                    continue;
                let small = item.span.w === 1 && item.span.h === 1;
                if (small && item.gX >= quadOriginX && item.gX < quadOriginX + 2 && item.gY >= quadOriginY && item.gY < quadOriginY + 2) {
                    targetId = item.widgetId;
                    targetIsSmall = true;
                    break;
                }
            }
        }

        let reordered = false;
        if (targetId !== null) {
            let toIdx = items.findIndex(w => w.id === targetId);
            if (toIdx !== -1) {
                if (!isFromSmall && targetIsSmall) {
                    while (toIdx + 1 < items.length) {
                        let nextSpan = root.sizeSpan(items[toIdx + 1].size);
                        if (nextSpan.w === 1 && nextSpan.h === 1)
                            toIdx++;
                        else
                            break;
                    }
                    toIdx++;
                }
                let [moved] = items.splice(fromIdx, 1);
                let insertAt = fromIdx < toIdx ? toIdx - 1 : toIdx;
                items.splice(insertAt, 0, moved);
                reordered = true;
            }
        }

        let rec = items.find(w => w.id === fromId) ?? items[fromIdx];
        if (!rec)
            return;

        let isPinnedSection = toGY < root.pinnedCount;
        if (reordered || rec.pin !== isPinnedSection) {
            rec.pin = isPinnedSection;
            store.items = items;
            Qt.callLater(root.arrangeAll);
        }
    }

    function arrangeAll() {
        if (store.items.length === 0)
            root.initOrder();

        let itemMap = {};
        for (let i = 0; i < root.db.length; i++) {
            let item = widgetRepeater.itemAt(i);
            if (!item?.active)
                continue;
            itemMap[root.db[i].id] = {
                item,
                db: root.db[i]
            };
        }

        let pinned = [], unpinned = [];
        for (let rec of store.items) {
            let entry = itemMap[rec.id];
            if (!rec.enabled || !entry)
                continue;
            let span = root.sizeSpan(rec.size);
            (rec.pin ? pinned : unpinned).push({
                item: entry.item,
                w: span.w,
                h: span.h
            });
        }

        function groupSmalls(items) {
            let grouped = [];
            let run = [];
            function flush() {
                while (run.length > 0)
                    grouped.push({
                        quad: run.splice(0, 4)
                    });
            }
            for (let d of items) {
                if (d.w === 1 && d.h === 1) {
                    run.push(d);
                } else {
                    flush();
                    grouped.push(d);
                }
            }
            flush();
            return grouped;
        }

        let x = 0, y = 0, rowH = 0;

        function place(items) {
            const offsets = [[0, 0], [1, 0], [0, 1], [1, 1]];
            for (let d of groupSmalls(items)) {
                let w = d.quad ? 2 : d.w;
                let h = d.quad ? 2 : d.h;
                if (x + w > root.halfCols) {
                    x = 0;
                    y += rowH;
                    rowH = 0;
                }
                if (d.quad) {
                    d.quad.forEach((sub, i) => {
                        sub.item.gX = x + offsets[i][0];
                        sub.item.gY = y + offsets[i][1];
                    });
                } else {
                    d.item.gX = x;
                    d.item.gY = y;
                }
                x += w;
                rowH = Math.max(rowH, h);
                if (x >= root.halfCols) {
                    x = 0;
                    y += rowH;
                    rowH = 0;
                }
            }
        }

        place(pinned);

        root.pinnedCount = x > 0 ? y + rowH : y;
        if (x > 0) {
            x = 0;
            y += rowH;
        }

        place(unpinned);
    }
    onExpandedChanged: Qt.callLater(arrangeAll)

    Connections {
        target: Mem.states.sidebar.widgets
        function onItemsChanged() {
            root.initOrder();
            Qt.callLater(arrangeAll);
        }
    }

    ScrollEdgeFade {
        target: flick
        vertical: true
    }

    StyledFlickable {
        id: flick
        anchors.fill: parent
        contentHeight: container.childrenRect.height + 100
        clip: true
        boundsBehavior: Flickable.StopAtBounds

        Item {
            id: container
            anchors.fill: parent
            anchors.margins: Padding.large

            Repeater {
                id: widgetRepeater
                model: root.db
                
                
                

                delegate: StyledLoader {
                    id: loader
                    required property var modelData
                    required property int index
                    property int gX: 0
                    property int gY: 0
                    readonly property var span: root.sizeSpan(rec?.size ?? "normal")
                    readonly property var rec: root.store.items.find(w => w.id === modelData.id)
                    readonly property bool isDragged: dragHandler.active
                    readonly property bool isPinned: rec?.pin ?? false
                    readonly property bool isDesktop: rec?.desktop ?? false
                    readonly property bool isPill: rec?.pill ?? false
                    readonly property bool isExpanded: span.w > 2
                    readonly property string widgetId: modelData.id

                    Component.onCompleted: {
                        root.initOrder();
                        Qt.callLater(root.arrangeAll);
                    }

                    onSpanChanged: Qt.callLater(root.arrangeAll)

                    shown: rec?.enabled ?? false
                    source: modelData.isPlugin ? Qt.resolvedUrl(modelData.entry) : sanitizeSource(Directories.shellDir + "/modules/main/desktop/widgets/", modelData.component)
                    width: root.sizeWidth(span)
                    height: root.sizeHeight(span)

                    onLoaded: if (ready) {
                        if ("widgetData" in item && loader.rec)
                            item.widgetData = Qt.binding(() => loader.rec);
                    }

                    Drag.active: dragHandler.active
                    Drag.hotSpot.x: width / 2
                    Drag.hotSpot.y: height / 2

                    x: isDragged ? x : gX * root.halfUnit
                    y: isDragged ? y : gY * root.halfUnit
                    z: isDragged ? 1000 : 1

                    Behavior on x {
                        enabled: !isDragged
                        Anim {}
                    }
                    Behavior on y {
                        enabled: !isDragged
                        Anim {}
                    }

                    DragHandler {
                        id: dragHandler
                        target: loader.isPinned ? null : loader
                        acceptedButtons: Qt.LeftButton
                        dragThreshold: 8
                        grabPermissions: PointerHandler.CanTakeOverFromItems | PointerHandler.CanTakeOverFromHandlersOfDifferentType

                        onActiveChanged: {
                            if (active)
                                return;

                            let snapX = Math.max(0, Math.min(Math.round(loader.x / root.halfUnit), root.halfCols - 1));
                            let snapY = Math.max(0, Math.round(loader.y / root.halfUnit));

                            root.moveItem(loader.widgetId, snapX, snapY);
                        }
                    }

                    MouseArea {
                        id: contextArea
                        anchors.fill: parent
                        acceptedButtons: Qt.RightButton | Qt.LeftButton
                        onClicked: event => {
                            if (event.button === Qt.RightButton)
                                widgetMenu.popup(event.x, event.y);
                            else
                                sizeOverlay.show = !sizeOverlay.show;
                        }
                    }

                    WidgetItemContextMenu {
                        id: widgetMenu
                        widgetData: modelData
                    }

                    SizeOverlay {
                        id: sizeOverlay
                        widgetData: loader.modelData
                        radius: loader._item.radius ?? Rouding.large
                        colors: loader._item.colors ?? Colors
                    }
                }
            }
        }
    }

    PagePlaceholder {
        icon: "widgets"
        title: "No Enabled Widgets"
        description: "Scroll Below To Reveal Available Widgets"
        anchors.centerIn: parent
        shape: MaterialShape.Shape.Clover8Leaf
        iconSize: 100
        shown: store.items.filter(w => w.enabled).length === 0
    }

    WidgetsSpawnerDialog {
        db: root.db
    }
}
