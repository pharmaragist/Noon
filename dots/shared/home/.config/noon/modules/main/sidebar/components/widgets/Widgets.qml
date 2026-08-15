import QtQuick
import qs.store
import qs.common
import qs.common.widgets

RedunduntMultiViewPanel {
    id: root
    path: Qt.resolvedUrl("./")
    tabButtonList: [
        {
            "icon": "widgets",
            "name": "Applets",
            "component": "WidgetsPage",
            "preloadTable": {
                "expanded": root.expanded
            }
        },
        {
            "icon": "rss_feed",
            "name": "RSS",
            "component": "FeedsPage",
            "preloadTable": {
                "expanded": root.expanded
            }
        },
    ]
}
