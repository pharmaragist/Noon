import QtQuick
import qs.common
import qs.common.widgets

RedunduntMultiViewPanel {
    id: root
    path: Qt.resolvedUrl("./")

    tabButtonList: [
        {
            "icon": "list",
            "name": "Processes",
            "component": "pages/ProcessesPage",
            "preloadTable": {
                "searchQuery": searchQuery,
                "expanded": expanded
            }
        },
        {
            "icon": "leaderboard",
            "name": "Resources",
            "component": "pages/ResourcesPage",
            "preloadTable": {
                "searchQuery": searchQuery,
                "expanded": expanded
            }
        }
    ]
}
