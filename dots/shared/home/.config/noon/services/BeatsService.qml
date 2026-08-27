pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io

import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions

Singleton {
    id: root

    readonly property var opts: Mem.beats
    readonly property var currentTrackIndexedInfo: library?.find(t => t.title === MediaPlayerService.title)
    readonly property string tracksDir: Paths.methods.trim(opts.directory ?? Paths.standard.music)
    readonly property var hits: opts?.hits?.feed ?? []
    readonly property var searchResults: opts?.hits?.searchResults ?? []
    readonly property string lyricText: getData(lyricsFile)?.text ?? ""
    readonly property var library: getData(libraryFile)
    readonly property var queue: getData(queueFile)?.queue ?? []
    readonly property var baseCmd: ["python3", Paths.scriptsDir + "/beats_service.py"]
    readonly property bool isLoading: hitsProc.running

    property string hitsQuery: ""
    property int _hitsLimit: opts.options.fetchLimit


    Component.onCompleted: _daemonCmd(["init"])

    function search(query, more = false) {
        hitsQuery = query;
        _hitsLimit = more ? _hitsLimit += 64 : (opts.options.fetchLimit);
        _hitsCmd("search", ["--query", query, "--limit", _hitsLimit]);
    }

    function feed(reset = true) {
        if (reset)
            opts.hits.feed = [];
        const kind = Mem.states.services.beats.discoverMode ? "discover" : "recommend";
        _hitsCmd(kind, ["--limit", opts.options.fetchLimit]);
    }

    function _hitsCmd(kind, extra) {
        hitsProc._kind = kind;
        hitsProc.running = false;
        hitsProc.command = [...baseCmd, kind, ...extra];
        hitsProc.running = true;
    }

    onOptsChanged: if (!!opts)
        _daemonCmd(["refresh-config"])

    function getData(fileView) {
        const data = fileView.data();
        try {
            return JSON.parse(data);
        } catch (e) {
            return []; // empty read before async load finishes is normal at startup
        }
    }


    function fetchLyrics() {
        lyricText = "";
        _daemonCmd(["lyrics-refetch"]);
    }

    function restartDaemon() {
        _daemonCmd(["kill"]);
        Qt.callLater(() => _daemonCmd(["init"]));
    }

    function switchToFolder(folder) {
        opts.directory = folder;
    }

    function playTrackByFile(file) {
        _daemonCmd(["play-by-name", "--name", file]);
    }

    function playTrackByPath(path) {
        _daemonCmd(["play-file", "--file", path]);
    }

    function fetchLibrary() {
        NoonUtils.execDetached([...baseCmd, "fetch"]);
    }

    function playCustomPlaylist(...args) {
        _daemonCmd(["build-playlist", "--list", args.join(",")]);
    }

    function _daemonCmd(args) {
        mainProc.running = false;
        mainProc.command = baseCmd.concat(args);
        mainProc.running = true;
    }

    function previewURL(url) {
        if (!url)
            return;
        _daemonCmd(["preview", "--url", url]);
    }

    function moveQueueItemByMpdIdx(fromMpdIdx, toMpdIdx) {
        _daemonCmd(["queue-move", "--index", fromMpdIdx, "--new-index", toMpdIdx]);
    }

    function addNewFolder() {
        addFolderDialog.open();
    }

    FolderDialog {
        id: addFolderDialog
        title: "Select Folder"
        onAccepted: root.opts.folders.push(Paths.methods.trim(currentFolder))
    }

    Process {
        id: mainProc
        command: [...baseCmd, ""]
        environment: ({
            "BEATS_PORT": opts.port
        })
    }

    Process {
        id: hitsProc
        property string _kind: ""
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const items = JSON.parse(text.trim());
                    const h = opts.hits;
                    if (hitsProc._kind === "search") {
                        h.searchResults = items;
                    } else {
                        const seen = new Set(h.feed.map(t => t.videoId || t.url));
                        h.feed = [...h.feed, ...items.filter(t => !seen.has(t.videoId || t.url))];
                    }
                } catch (e) {}
            }
        }
    }

    FileView {
        id: queueFile
        path: Qt.resolvedUrl(root.tracksDir) + "/.beats/queue.json"
        watchChanges: true
        preload: true
        blockWrites: true
        onFileChanged: queueFile.reload()
    }

    FileView {
        id: lyricsFile
        path: Qt.resolvedUrl(root.tracksDir) + "/.beats/lyrics.json"
        watchChanges: true
        preload: true
        blockWrites: true
        printErrors: false // daemon writes it after first track starts
        onFileChanged: lyricsFile.reload()
    }

    FileView {
        id: libraryFile
        path: Qt.resolvedUrl(root.tracksDir) + "/.beats/library.json"
        watchChanges: true
        preload: true
        blockWrites: true
        onFileChanged: libraryFile.reload()
    }
}
