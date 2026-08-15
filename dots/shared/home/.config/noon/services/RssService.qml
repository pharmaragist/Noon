pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io
import qs.common
import qs.common.utils

Singleton {
    id: root

    readonly property string rssUrls: rssView.data.feeds.join(",")
    readonly property string rssTtl: String(rssView.data.ttl)
    readonly property var targets: rssView.data.targets ?? []
    readonly property bool isLoading: refreshProc.running
    readonly property bool isReady: Array.isArray(targets) && targets.length > 0

    function loadRss() {
        refreshProc.running = false;
        refreshProc.running = true;
    }

    Process {
        id: refreshProc
        command: ["python", Directories.scriptsDir + "/rss_service.py", "--urls", root.rssUrls, "--ttl", root.rssTtl, "--file", Directories.methods.trim(rssView.path), "--image-cache-path", Directories.methods.trim(Directories.standard.cache) + "/media/rss_images"]
        running: false
    }

    Component.onCompleted: root.loadRss()

    Timer {
        interval: 900000
        running: !isLoading
        repeat: true
        onTriggered: root.loadRss()
    }

    ConfigFileView {
        id: rssView
        state: false
        parentDir: "user/"
        fileName: "feed"
        JsonAdapter {
            property int ttl: 900
            property list<string> feeds: ["https://www.reddit.com/r/unixporn.rss", "https://www.reddit.com/r/hyprland.rss"]
            property list<var> targets: []
        }
    }
}
