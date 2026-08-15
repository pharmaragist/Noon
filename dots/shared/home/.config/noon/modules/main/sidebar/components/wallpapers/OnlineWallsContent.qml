import QtQuick
import QtQuick.Layouts
import qs.common
import qs.common.widgets
import qs.services
import qs.services.wallpapers

LayerRect {
    id: root
    visible: opacity > 0
    opacity: width > 320 ? 1 : 0
    radius: Rounding.verylarge
    clip: true
    property Item container
    property string query: ""
    property string _debouncedQuery: ""

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

    signal searchFocusRequested
    signal contentFocusRequested
    signal dismiss

    onQueryChanged: debounceTimer.restart()
    onContentFocusRequested: gridView.forceActiveFocus()
    Component.onCompleted: OnlineWallpaperService._doFetch(1, false)

    Timer {
        id: debounceTimer
        interval: 200
        repeat: false
        onTriggered: {
            root._debouncedQuery = root.query.trim();
            OnlineWallpaperService.search(root._debouncedQuery);
        }
    }

    ScrollEdgeFade {
        target: gridView
    }

    StyledRectangularShadow {
        target: categoryBar
        transparency: 0.9
        z: 1
    }

    StyledGridView {
        id: gridView
        anchors.fill: parent

        cellWidth: root._cellWidth
        cellHeight: root._cellHeight
        boundsBehavior: Flickable.StopAtBounds
        model: OnlineWallpaperService.results ?? []
        highlightFollowsCurrentItem: true
        highlightMoveDuration: 300

        onContentYChanged: maybeLoadMore()
        onContentHeightChanged: maybeLoadMore()

        function maybeLoadMore() {
            if (contentHeight > 0 && contentY + height >= contentHeight - height * 0.25)
                OnlineWallpaperService.loadMore();
        }

        delegate: Item {
            required property int index
            required property var modelData

            width: gridView.cellWidth
            height: gridView.cellHeight

            WallpaperItem {
                id: wallpaperItem
                anchors.fill: parent
                anchors.margins: isKeyboardSelected ? 3 * root._spacing : root._spacing
                isKeyboardSelected: gridView.currentIndex === index
                isCurrentWallpaper: WallpaperService.currentWallpaper.toString().includes(modelData.id + ".")
                fileUrl: modelData.thumbUrl
                applyAction: () => OnlineWallpaperService.downloadAndApply(modelData)

                StyledRect {
                    z: 999
                    anchors {
                        bottom: parent.bottom
                        right: parent.right
                        margins: Padding.large
                    }
                    width: resLabel.implicitWidth + Padding.large
                    height: resLabel.implicitHeight + Padding.normal
                    radius: Rounding.normal
                    color: Colors.colPrimary
                    visible: OnlineWallpaperService.downloadingId !== modelData.id

                    StyledText {
                        id: resLabel
                        anchors.centerIn: parent
                        text: modelData.resolution
                        font.pixelSize: Fonts.sizes.verysmall
                        color: Colors.colOnPrimary
                    }
                }
            }

            StyledRect {
                anchors.fill: parent
                radius: parent.height * 0.05
                color: Colors.colLayer0
                opacity: OnlineWallpaperService.downloadingId === modelData.id ? 0.65 : 0

                MaterialLoadingIndicator {
                    z: 999
                    loading: parent.opacity > 0
                    anchors.centerIn: parent
                }
            }

            StyledRectangularShadow {
                target: wallpaperItem
                enabled: wallpaperItem.isKeyboardSelected
                show: wallpaperItem.isKeyboardSelected
            }
        }

        Keys.onPressed: event => {
            if (event.key === Qt.Key_Slash) {
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
                    const item = gridView._model[currentIndex];
                    if (item)
                        OnlineWallpaperService.downloadAndApply(item);
                }
            } else if (event.key === Qt.Key_Escape) {
                root.dismiss();
            } else
                return;

            event.accepted = true;
        }
    }

    StyledRect {
        id: categoryBar
        z: 2

        anchors {
            right: parent.right
            bottom: parent.bottom
            margins: Padding.huge
        }

        implicitWidth: 55
        implicitHeight: categoryRow.implicitHeight + Padding.massive
        color: Colors.colLayer0
        radius: Rounding.full

        ColumnLayout {
            id: categoryRow

            anchors.centerIn: parent
            spacing: Padding.small
            clip: true

            Repeater {
                model: OnlineWallpaperService.categories
                delegate: RippleButtonWithIcon {
                    required property int index
                    required property var modelData
                    Layout.alignment: Qt.AlignHCenter
                    toggled: OnlineWallpaperService.selectedCategory === index
                    materialIcon: modelData.icon
                    releaseAction: () => OnlineWallpaperService.selectCategory(index)
                }
            }
        }
    }

    PagePlaceholder {
        shown: !OnlineWallpaperService.isLoading && gridView.count === 0
        title: "No wallpapers found"
        icon: "image_not_supported"
        anchors.centerIn: parent
    }
}
