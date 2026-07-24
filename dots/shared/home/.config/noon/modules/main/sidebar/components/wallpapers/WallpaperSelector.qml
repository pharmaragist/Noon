import QtQuick
import Quickshell
import qs.common
import qs.common.functions
import qs.common.widgets
import qs.services

RedunduntMultiViewPanel {
    id: root
    path: Qt.resolvedUrl("./")
    tabButtonList: [
        {
            "icon": "image",
            "name": "Local",
            "component": "LocalWallsContent",
            "preload": "query",
            "preloadData": root.searchQuery
        },
        {
            "icon": "wallpaper",
            "name": "Online",
            "component": "OnlineWallsContent",
            "preload": "query",
            "preloadData": root.searchQuery
        }
    ]
    WallpaperControls {}
}
