import QtQuick
import qs.common
import qs.common.widgets

RedunduntMultiViewPanel {
    id: root
    path: Qt.resolvedUrl("./")

    lazy: false
    tabButtonList: [
        {
            "icon": "window",
            "name": "Group",
            "component": "AppsGrid",
            "preloadTable": {
                "searchQuery": searchQuery,
                "expanded": expanded
            }
        },
        {
            "icon": "list",
            "name": "All",
            "component": "AppsList",
            "preloadTable": {
                "searchQuery": searchQuery,
                "expanded": expanded
            }
        }
    ]
}
