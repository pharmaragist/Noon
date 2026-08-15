import QtQuick.Controls
import QtQuick
import Quickshell
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services

LayerRect {
    id: root
    visible: opacity > 0
    opacity: width > 320 ? 1 : 0
    radius: Rounding.verylarge
    clip: true
    property Item container
    property string query: ""
    property string _debouncedQuery: ""
    signal searchFocusRequested
    signal contentFocusRequested
    signal dismiss

    onQueryChanged: debounceTimer.restart()
    onContentFocusRequested: gridView.forceActiveFocus()

    Timer {
        id: debounceTimer
        interval: 120
        repeat: false
        onTriggered: root._debouncedQuery = root.query.trim()
    }

    property bool dynamic: true
    property int _layoutWidth: root.width

    onWidthChanged: {
        if (!root.dynamic) {
            if (!layoutDebouncer.running) {
                root._layoutWidth = root.width;
                layoutDebouncer.restart();
            }
        }
    }

    Timer {
        id: layoutDebouncer
        interval: Animations.durations.normal + 80
        onTriggered: root._layoutWidth = root.width
    }

    readonly property int _spacing: Padding.small
    readonly property int _baseItemWidth: container?.expanded ? 240 : _layoutWidth
    readonly property int _columns: Math.max(1, Math.floor((_layoutWidth + _spacing) / (_baseItemWidth + _spacing)))
    readonly property int _cellWidth: (_layoutWidth - (_columns - 1) * _spacing) / _columns
    readonly property int _cellHeight: (_cellWidth - _spacing * 2) * 9 / 16 + _spacing * 2

    ScriptModel {
        id: filteredModel

        values: {
            const model = WallpaperService.wallpaperModel;
            const count = model ? model.count : 0;
            let items = [];
            for (let i = 0; i < count; i++) {
                const fileUrl = model.get(i, "fileUrl");
                if (fileUrl) {
                    items.push({
                        fileUrl: fileUrl,
                        thumb: WallpaperService.getThumbnailPath(fileUrl),
                        fileName: FileUtils.getEscapedFileName(fileUrl)
                    });
                }
            }
            const query = root._debouncedQuery;
            if (!!query)
                return Fuzzy.go(query, items, {
                    key: 'fileName',
                    threshold: -10000,
                    limit: 20
                }).map(r => r.obj);
            else
                return items;
        }
    }
    ScrollEdgeFade {
        target: gridView
    }
    StyledGridView {
        id: gridView
        anchors.fill: parent
        cellWidth: root._cellWidth
        cellHeight: root._cellHeight
        boundsBehavior: Flickable.StopAtBounds
        model: filteredModel
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 300
        delegate: Item {
            required property int index
            required property var modelData

            width: gridView.cellWidth
            height: gridView.cellHeight

            WallpaperItem {
                id: wallpaperItem
                anchors.fill: parent
                fileData: modelData
                anchors.margins: isKeyboardSelected ? 3 * root._spacing : root._spacing
                isKeyboardSelected: gridView.currentIndex === index
                isCurrentWallpaper: modelData.fileUrl.toString() === WallpaperService.currentWallpaper
            }

            StyledRectangularShadow {
                target: wallpaperItem
                enabled: wallpaperItem.isKeyboardSelected
                show: wallpaperItem.isKeyboardSelected
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Slash && root.focus) {
                root.searchFocusRequested();
            } else if (event.key === Qt.Key_Up) {
                if (currentIndex < root._columns) {
                    currentIndex = -1;
                    root.searchFocusRequested();
                } else {
                    currentIndex -= root._columns;
                }
            } else if (event.key === Qt.Key_Down) {
                const next = currentIndex + root._columns;
                if (next < count)
                    currentIndex = next;
            } else if (event.key === Qt.Key_Left) {
                if (currentIndex > 0)
                    currentIndex--;
            } else if (event.key === Qt.Key_Right) {
                if (currentIndex < count - 1)
                    currentIndex++;
            } else if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                if (currentIndex >= 0) {
                    const selectedData = filteredModel.values[currentIndex];
                    if (selectedData && selectedData.fileUrl) {
                        WallpaperService.applyWallpaper(selectedData.fileUrl);
                        NoonUtils.playSound("event_accepted");
                    }
                }
            } else if (event.key === Qt.Key_Escape) {
                root.dismiss();
            } else
                return;

            event.accepted = true;
        }
    }

    PagePlaceholder {
        shown: gridView.count === 0
        title: qsTr("No wallpapers found")
        icon: "image_not_supported"
        anchors.centerIn: parent
    }
}
