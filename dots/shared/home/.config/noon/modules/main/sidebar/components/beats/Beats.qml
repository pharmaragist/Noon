import QtQuick
import qs.common
import qs.common.widgets
import "pages"

RedunduntMultiViewPanel {
    id: root
    path: Qt.resolvedUrl("./")
    readonly property string currentPagePath: "pages/" + (Mem.beats.options.homePageStyle ?? "MaterialNoon")
    tabButtonList: [
        {
            // Queue ?
            "icon": "music_note",
            "name": "Home",
            "preload": "expanded",
            "preloadData": root.expanded,
            "component": root.currentPagePath
        },
        {
            "icon": "list",
            "name": "Local",
            "preload": "expanded",
            "preloadData": root.expanded,
            "component": "pages/LocalTracksPage"
        },
        {
            "icon": "for_you",
            "name": "Feed",
            "preload": "expanded",
            "preloadData": root.expanded,
            "component": "pages/HitsPage"
        }
        // {
        //     "icon": "tune",
        //     "name": "EQ",
        //     "preload": "expanded",
        //     "preloadData": root.expanded,
        //     "component": "pages/EQPage"
        // },
        ,
    ]
}
