pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Noon.Utils

import qs.common.utils

Singleton {
    id: root
    readonly property var stats: watcher.stats
    readonly property ResourcesWatcher watcher: ResourcesWatcher {
        updateInterval: 3500
        diskUpdateInterval: 600000
    }
}
