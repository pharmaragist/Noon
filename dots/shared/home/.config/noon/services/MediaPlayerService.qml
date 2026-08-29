pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import Quickshell.Services.Mpris

import qs.store
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions

Singleton {
    id: root

    property int selectedPlayerIndex: 0
    readonly property var player: players[selectedPlayerIndex] ?? null
    readonly property bool _playing: player && isPlaying(root.player)
    readonly property var colors: palette.colors

    readonly property string artUrl: player?.trackArtUrl ?? ""
    readonly property string title: player ? TextUtils.cleanMusicTitle(player.trackTitle) : "No Title"
    readonly property string artist: player ? TextUtils.cleanMusicTitle(player.trackArtist) : "No Artist"

    readonly property var players: Mpris?.players?.values.filter(p => {
        return !!p.dbusName && !Mem.beats.options.excludedPlayers.includes(p);
    })

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

    function isPlaying(player) {
        if (player)
            return player.playbackState === MprisPlaybackState.Playing;
    }

    function stopPlayer() {
        root.player.stop();
    }

    function currentTrackProgressRatio(p = root.player) {
        const pos = p?.position ?? 0;
        const len = p?.length ?? 0;
        const ratio = len > 0 ? Math.max(0.0, Math.min(1.0, pos / len)) : 0.0;
        return ratio;
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

    function getIconForPlayer(p, fallback = "music_note") {
        if (!p) return fallback;

        const dic = SymbolData?.mediaMap ?? ({});
        const criteria = ["identity", "desktopEntry", "dbusName"];
        const matches = (str, target) => {
            return str.toLowerCase().includes(target);
        };

        for (const [key, result] of Object.entries(dic)) {
            if (criteria.some(rule => matches(p[rule], key)))
                return result ?? fallback;
        }
    }

    Timer {
        id: positionTimer
        interval: 100
        repeat: true
        running: root.player && root._playing
        onTriggered: root.player.positionChanged()
    }

    SourceDownloader {
        id: coverFetch
        active: root.artUrl.startsWith("http") || root.artUrl.startsWith("https")
        input: root.artUrl
    }

    MaterialColorsGenerator {
        id: palette
        active: root.artUrl.length > 0 && Mem.beats.options.adaptiveTheme
        source: coverFetch.output || root.artUrl
    }
}
