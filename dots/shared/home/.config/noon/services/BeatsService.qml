pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Dialogs
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris

import Noon.Utils
import qs.store
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions

Singleton {
    id: root

    readonly property var opts: Mem.beats
    readonly property var currentTrackIndexedInfo: library?.find(t => t.title === root.title)
    readonly property string tracksDir: Paths.methods.trim(opts.directory || Paths.standard.music)
    readonly property string tracksUrl: Qt.resolvedUrl(opts.directory)
    readonly property var library: libraryFetcher?.data ?? []
    readonly property var queue: queueFetcher?.data ?? []


    property int selectedPlayerIndex: 0
    readonly property bool _playing: player && isPlaying(root.player)
    readonly property var player: players[selectedPlayerIndex] ?? null
    readonly property var colors: palette.colors
    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property string title: player ? TextUtils.cleanMusicTitle(player.trackTitle) : "No Title"
    readonly property string artist: player ? TextUtils.cleanMusicTitle(player.trackArtist) : "No Artist"

    readonly property var players: Mpris?.players?.values
    readonly property var baseCmd: ["python3", Paths.scriptsDir + "/beats_service.py"]

    Component.onCompleted: _daemonCmd(["init"])
    onOptsChanged: if (!!opts) _daemonCmd(["refresh-config"])
    onPlayersChanged: root.selectedPlayerIndex = root.playerIndex()

    function playerIndex() {
        if (!players || players.length === 0)
            return 0;
        const baets = players.findIndex(p => /noon/.test(p?.dbusName.toLowerCase()));
        if (baets >= 0)
        return baets;
        const playingIndex = players.findIndex(p => p.isPlaying);
        return playingIndex >= 0 ? playingIndex : 0;
    }

    function restartDaemon() {
        _daemonCmd(["kill"]);
        Qt.callLater(() => _daemonCmd(["init"]));
    }

    function refreshTracks() {
        if (fetchTrackProc.running)
            return;
        fetchTrackProc.command = [...baseCmd, "fetch"];
        fetchTrackProc.running = true;
    }

    function fetchLibrary() {
        if (libraryFetcher.running)
            return;
        refreshTracks();
        NoonUtils.inlineTimer(() => {
            libraryFetcher.running = true;
        }, 400);
    }

    function isPlaying(player) {
        if (player)
            return player.playbackState === MprisPlaybackState.Playing;
    }

    function switchToFolder(folder) {
        Mem.beats.directory = folder;
    }

    function playTrackByFile(file) {
        _daemonCmd(["play-by-name", "--name", `${file}`]);
    }

    function playCustomPlaylist(...args) {
        _daemonCmd(["build-playlist", "--list", args.join(",")]);
    }

    function _daemonCmd(args) {
        mainProc.running = false;
        mainProc.command = baseCmd.concat(args);
        mainProc.running = true;
    }

    function stopPlayer() {
        root.player.stop();
    }

    function previewURL(url) {
        if (!url)
            return;
        NoonUtils.toast({
            id: 2,
            header: "Beats",
            icon: "music_note",
            shape: "Bun",
            content: "Your Track is Playing Soon !"
        });
        NoonUtils.execDetached(["mpv", `${decodeURI(url)}`]);
    }

    function currentTrackProgressRatio(p = root.player) {
        const pos = p?.position ?? 0;
        const len = p?.length ?? 0;
        const ratio = len > 0 ? Math.max(0.0, Math.min(1.0, pos / len)) : 0.0;
        return ratio;
    }

    function moveQueueItemByMpdIdx(fromMpdIdx, toMpdIdx) {
        _daemonCmd(["queue-move", "--index", `${fromMpdIdx}`, "--new-index", `${toMpdIdx}`]);
        moveQueueTimer.restart();
    }

    function moveQueueItem(fromUiIndex, toUiIndex) {
        const q = queue;
        if (!q || fromUiIndex < 0 || fromUiIndex >= q.length || toUiIndex < 0 || toUiIndex >= q.length)
            return;
        const fromMpdIdx = q[fromUiIndex]?.index;
        const toMpdIdx = q[toUiIndex]?.index;
        if (fromMpdIdx == null || toMpdIdx == null)
            return;
        moveQueueItemByMpdIdx(fromMpdIdx, toMpdIdx);
    }

    function getQueue() {
        if (queueFetcher.running)
            return;
        if (!root.players.some(p => /noon/.test(p.dbusName)))
            return;
        queueFetcher.running = true;
    }

    function cycleRepeat(p = root.player) {
        if (!p?.canControl)
            return;
        p.loopState = ({
                [MprisLoopState.None]: MprisLoopState.Playlist,
                [MprisLoopState.Playlist]: MprisLoopState.Track,
                [MprisLoopState.Track]: MprisLoopState.None
            })[p.loopState] ?? MprisLoopState.None;
    }

    function openUrl() {
        NoonUtils.execDetached(["gio", "open", "http://localhost:" + opts.webClientPort]);
    }

    function openWebClient() {
        NoonUtils.execDetached([...baseCmd, "serve", "--port", opts.webClientPort])
        NoonUtils.inlineTimer(()=> {
                openUrl();
        },200)
    }

    function addNewFolder() {
        addFolderDialog.open();
    }

    FolderDialog {
        id: addFolderDialog
        title: "Select Folder"
        onAccepted: {
            root.opts.folders.push(Paths.methods.trim(currentFolder));
            Qt.callLater(fetchLibrary);
        }
    }

    Timer {
        id: positionTimer
        interval: 100
        repeat: true
        running: root.player && root._playing
        onTriggered: root.player.positionChanged()
    }

    Process {
        id: mainProc
        command: [...baseCmd, ""]
    }

    Fetcher {
        id: libraryFetcher
        command: [...baseCmd, "library"]
    }

    Fetcher {
        id: queueFetcher
        command: [...baseCmd, "queue"]
    }

    Timer {
        id: moveQueueTimer
        interval: 350
        onTriggered: getQueue()
    }

    Process {
        id: fetchTrackProc
    }

    FileSystemWatcher {
        folder: root.tracksUrl
        onContentsChanged: {
            console.log("[BEATS]: contentChanged");
            root.fetchLibrary();
        }
    }

    SourceDownloader {
        id: coverFetch
        active: root.artUrl.startsWith("http") || root.artUrl.startsWith("https")
        input: root.artUrl
    }

    PaletteGenerator {
        id: palette
        active: root.artUrl.length > 0 && Mem.beats.options.adaptiveTheme
        source: coverFetch.output || root.artUrl
    }
}
