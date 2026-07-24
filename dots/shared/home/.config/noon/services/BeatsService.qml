pragma Singleton
pragma ComponentBehavior: Bound
import qs.store
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import QtQuick.Dialogs
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Mpris
import Qt.labs.folderlistmodel
import QtMultimedia
import Noon.Utils

Singleton {
    id: root
    readonly property QtObject colors: palette.colors
    readonly property var daemonOptions: Mem.beats
    readonly property var currentTrackIndexedInfo: library?.find(t => t.title === root.title)
    readonly property string tracksDir: daemonOptions.players.main.musicDirectory
    readonly property string tracksUrl: Qt.resolvedUrl(daemonOptions.players.main.musicDirectory)
    readonly property var library: daemonOptions.players.main.library
    readonly property alias queue: queueFetcher.data

    readonly property int defaultPlayerIndex: getCurrentPlayerIndex()
    property int selectedPlayerIndex: defaultPlayerIndex

    readonly property string artUrl: player ? StringUtils.cleanMusicTitle(player.trackArtUrl) : ""
    readonly property string title: player ? StringUtils.cleanMusicTitle(player.trackTitle) : "No Title"
    readonly property string artist: player ? StringUtils.cleanMusicTitle(player.trackArtist) : "No Artist"

    readonly property var players: Mpris?.players.values ?? []
    readonly property MprisPlayer player: meaningfulPlayers[selectedPlayerIndex] ?? null

    readonly property bool _playing: player && isPlaying(root.player)
    readonly property var baseCmd: ["python3", Directories.scriptsDir + "/beats_daemon.py"]
    readonly property var meaningfulPlayers: {
        const source = root.players;
        if (!source)
            return [];

        const map = new Map();
        for (let i = 0; i < source.length; i++) {
            const p = source[i];
            if (!p || !p.dbusName || p.dbusName === "")
                continue;

            const key = `${p.trackTitle || ""}|${p.trackArtist || ""}`.toLowerCase();
            if (!map.has(key)) {
                map.set(key, p);
            } else {
                const existing = map.get(key);
                if (p.trackArtUrl?.length > 0 && !(existing.trackArtUrl?.length > 0))
                    map.set(key, p);
            }
        }
        return Array.from(map.values());
    }

    onDaemonOptionsChanged: _daemonCmd(["refresh-config"])

    function getCurrentPlayerIndex() {
        const players = meaningfulPlayers;
        const currentlyActivePlayer = players.find(player => isPlaying(player));
        return Math.max(0, players?.indexOf(currentlyActivePlayer)) ?? 0;
    }

    function restartDaemon() {
        NoonUtils.execDetached(["killall", "-9", "mpd"]);
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
        }, 200);
    }

    function isPlaying(player) {
        if (player)
            return player.playbackState === MprisPlaybackState.Playing;
    }

    function playTrackByFile(file) {
        _daemonCmd(["--player", "main", "play-by-name", "--name", `${file}`]);
    }

    function playCustomPlaylist(...args) {
        _daemonCmd(["--player", "main", "build-playlist", "--list", args.join(",")]);
    }

    function _daemonCmd(args) {
        mainProc.running = false;
        mainProc.command = baseCmd.concat(args);
        mainProc.running = true;
    }

    function terminatePlayer() {
        if (root.player)
            NoonUtils.execDetached(["killall", root.player.dbusName]);
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

    function killPreview() {
        _daemonCmd(["--player", "preview", "stop"]);
    }

    function currentTrackProgressRatio(p = root.player) {
        const pos = p?.position ?? 0;
        const len = p?.length ?? 0;
        const ratio = len > 0 ? Math.max(0.0, Math.min(1.0, pos / len)) : 0.0;
        return ratio;
    }

    function moveQueueItemByMpdIdx(fromMpdIdx, toMpdIdx) {
        _daemonCmd(["--player", "main", "queue-move", "--index", `${fromMpdIdx}`, "--new-index", `${toMpdIdx}`]);
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

    function formatTime(seconds) {
        if (!seconds || seconds <= 0)
            return "0:00";
        const mins = Math.floor(seconds / 60);
        const secs = Math.floor(seconds % 60);
        return mins + ":" + (secs < 10 ? "0" : "") + secs;
    }

    function getQueue() {
        if (queueFetcher.running || !root.player.dbusName.includes("mpd"))
            return;
        queueFetcher.running = true;
    }

    function cycleRepeat() {
        const p = root.player;
        if (!p?.canControl)
            return;
        p.loopState = ({
                [MprisLoopState.None]: MprisLoopState.Playlist,
                [MprisLoopState.Playlist]: MprisLoopState.Track,
                [MprisLoopState.Track]: MprisLoopState.None
            })[p.loopState] ?? MprisLoopState.None;
    }

    function openUrl() {
        Qt.openUrlExternally("http://localhost:" + daemonOptions.players.webClient.port);
    }
    function openWebClient() {
        if (!webClientProc.running) {
            webClientProc.running = true;
        } else {
            openUrl();
        }
    }
    function addNewFolder() {
        addFolderDialog.open();
    }

    FolderDialog {
        id: addFolderDialog
        title: "Select Folder"
        onAccepted: {
            root.daemonOptions.folders.push(Directories.methods.trim(currentFolder));
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
        id: webClientProc
        command: [...baseCmd, "serve", "--port", daemonOptions.players.webClient.port]
        onStarted: openUrl()
    }
    Process {
        id: mainProc
        command: [...baseCmd, "--player", "main", ""]
    }

    Fetcher {
        id: libraryFetcher
        command: [...baseCmd, "--player", "main", "library"]
        onDataChanged: if (data)
            daemonOptions.players.main.library = data
    }

    Fetcher {
        id: queueFetcher
        command: [...baseCmd, "queue", "--player", "main"]
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
        active: root._playing && Mem.beats.options.adaptiveTheme
        source: coverFetch.output || root.artUrl
    }
}
