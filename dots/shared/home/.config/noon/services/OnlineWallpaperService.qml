pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.functions
import qs.services
import "wallpapers"

Singleton {
    id: root

    property string cacheDir: Paths.services.onlineWallThumbs

    property var results: []

    property bool isLoading: false
    property bool hasMore: true
    property string downloadingId: ""
    property int selectedCategory: 0
    property int _currentPage: 1

    readonly property var categories: wallhavenApi.categories

    property string query: ""

    property var _cached: ({})

    property var _xhr: null
    property int _reqSeq: 0

    onQueryChanged: _doFetch(1, true)

    Component.onCompleted: {
        Paths.methods.mkdir(root.cacheDir);
        root._doFetch(1, true);
    }

    function search(query) {
        const next = (query ?? "").trim();
        if (root.query === next)
            return;
        root.query = next;
        root.results = [];
        root._currentPage = 1;
    }
    function _cacheKey(item) {
        return item.id;
    }
    function _ensureCached(item) {
        const key = root._cacheKey(item);
        if (root._cached[key] === true || root._cached[key] === "pending")
            return;
        root._cached[key] = "pending";
        thumbDownloader.createObject(root, {
            cacheKey: key,
            remoteUrl: item.thumbUrl,
            cachePath: root.cacheDir + "/" + key
        });
    }
    function _markCached(cacheKey) {
        root._cached[cacheKey] = true;
        const path = root.cacheDir + "/" + cacheKey;
        root.results = root.results.map(function (it) {
            if (root._cacheKey(it) === cacheKey) {
                const copy = {};
                for (const k in it)
                    copy[k] = it[k];
                copy.thumbUrl = "file://" + path;
                return copy;
            }
            return it;
        });
    }
    function _doFetch(page, reset) {
        if (root._xhr) {
            try { root._xhr.abort(); } catch (e) {}
            root._xhr = null;
        }
        root.isLoading = true;
        const seq = ++root._reqSeq;
        const qAtFetch = root.query;
        const pageAtFetch = page;
        const resetAtFetch = reset;

        const url = wallhavenApi.buildUrl(pageAtFetch, qAtFetch, root.selectedCategory);
        const existing = resetAtFetch ? [] : root.results.slice();

        const xhr = new XMLHttpRequest();
        root._xhr = xhr;
        xhr.open("GET", url);

        xhr.onreadystatechange = function () {
            if (xhr.readyState !== XMLHttpRequest.DONE)
                return;
            if (seq !== root._reqSeq)
                return;
            root._xhr = null;
            root.isLoading = false;
            if (xhr.status !== 200)
                return;
            if (root.query !== qAtFetch)
                return;
            let json;
            try {
                json = JSON.parse(xhr.responseText);
            } catch (e) {
                return;
            }
            const items = wallhavenApi.normalizeResults(json.data ?? json);
            const mapped = items.map(function (it) {
                const copy = {};
                for (const k in it)
                    copy[k] = it[k];
                copy.cacheKey = root._cacheKey(it);
                const cached = root._cached[copy.cacheKey] === true;
                const cachePath = root.cacheDir + "/" + copy.cacheKey;
                if (cached) {
                    copy.thumbUrl = "file://" + cachePath;
                }
                root._ensureCached(copy);
                return copy;
            });
            root.results = pageAtFetch === 1 ? mapped : existing.concat(mapped);
            root.hasMore = wallhavenApi.parseHasMore(json.meta ?? json);
            root._currentPage = pageAtFetch;
        };
        xhr.send();
    }

    function loadMore() {
        if (!root.isLoading && root.hasMore)
            root._doFetch(root._currentPage + 1, false);
    }

    function selectCategory(index) {
        if (root.selectedCategory === index)
            return;
        root.selectedCategory = index;
        root.results = [];
        root._doFetch(1, true);
    }

    function downloadAndApply(item) {
        const info = wallhavenApi.resolveDownloadInfo(item);
        const destPath = Paths.methods.trim(WallpaperService.currentFolderPath + "/" + info.fileName);
        const destUrl = "file://" + destPath;

        root.downloadingId = item.id;
        downloader.command = ["curl", "-L", "-s", "-o", destPath, info.fullUrl];
        downloader._pendingUrl = destUrl;
        downloader.running = true;
    }

    Process {
        id: downloader
        property string _pendingUrl: ""

        onExited: function (code) {
            root.downloadingId = "";
            if (code === 0) {
                WallpaperService.applyWallpaper(_pendingUrl);
                NoonUtils.playSound("message");
                refreshTimer.restart();
            }
        }
    }

    Timer {
        id: refreshTimer
        interval: 800
        onTriggered: {
            if (WallpaperService.wallpaperModel)
                WallpaperService.wallpaperModel.refresh();
        }
    }

    Component {
        id: thumbDownloader

        QtObject {
            id: comp
            property string cacheKey: ""
            property string remoteUrl: ""
            property string cachePath: ""

            property var _proc: Process {
                running: true
                command: ["bash", "-c", `[ -f ${cachePath} ] || curl -s -L '${remoteUrl}' -o '${cachePath}'`]
                onExited: function (code) {
                    if (code === 0) {
                        root._markCached(cacheKey);
                    } else {
                        root._cached[cacheKey] = false;
                    }
                    comp.destroy();
                }
            }
        }
    }

    WallhavenApi {
        id: wallhavenApi
    }
}