pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.services

Singleton {
    id: root

    property bool commandsReady: false
    readonly property Component procRunnerComponent: PlainStdoutProc {}
    readonly property Component timerComponent: Timer {}

    function requestDialog(dialog, data) {
        if (!dialog)
            return;
        if (data)
            Globals.main.sysDialogs.pendingData = data;
        Globals.main.sysDialogs.mode = dialog;
    }

    function clearDialogs() {
        Globals.main.sysDialogs.pendingData = null;
        Globals.main.sysDialogs.mode = "";
    }

    function searchOnline(query) {
        const dict = {
            "google": "https://www.google.com/search?q=",
            "duckduckgo": "https://duckduckgo.com/?q=",
            "yandex": "https://yandex.com/search/?text=",
            "brave": "https://search.brave.com/search?q=",
            "startpage": "https://www.startpage.com/do/dsearch?query="
        };
        const prefix = dict[Mem.options.networking.searchEngine] ?? dict["google"];
        open(`"${prefix + query}"`);
    }

    function trash(path) {
        const f = Paths.methods.trim(path);
        execDetached(["gio", "trash", `"${f}"`]);
    }

    function open(sth) {
        let thing = sth;

        if (sth.startsWith("file://"))
            thing = Paths.methods.trim(thing);

        execDetached(["gio", "open", `${thing}`]);
    }

    function iconPath(icon, fallback = "image-missing-symbolic") {
        const noon_icon = `noon-${Mem.looks.mode}.png`;
        const qs = ({
                "org.quickshell": noon_icon
            });
        const subs = Object.assign({}, qs, Mem.options.desktop.icons.substitutions);
        const lookup = subs[icon] ?? DesktopEntries.heuristics(icon)?.icon ?? icon;
        return Quickshell.iconPath(lookup, fallback);
    }

    function sudoExec(...args) {
        execDetached(["pkexec", ...content]);
    }

    function stopPlayer() {
        if (player.playbackState === MediaPlayer.PlayingState)
            player.stop();
    }

    function startPlayer(obj) {
        const pack = `/${(obj.pack ?? "ui")}/`;
        const path = Qt.resolvedUrl(Paths.assets + "/sounds") + pack + obj.name + ".ogg";
        const repeats = obj.repeats < 0 ? MediaPlayer.Infinite : (obj?.repeats ?? 1);

        if (player.playbackState === MediaPlayer.PlayingState)
            player.stop();

        player.loops = repeats;
        player.audioOutput.volume = obj?.volume ?? 0.15;
        player.source = path;
        player.play();
    }

    function playSound(sound) {
        if (Mem.ready && Mem.options.desktop.behavior.sounds.enabled && !Mem.states.services.notifications.silent) {
            startPlayer({
                name: sound,
                pack: "ui",
                repeats: 1,
                volume: 0.15
            });
        }
    }

    function wake(name = "Wake Up!", message = "Click Below to Dismiss") {
        startPlayer({
            name: "alarm",
            repeats: -1,
            volume: 1
        });
        requestDialog("assure", {
            title: name,
            description: message,
            acceptText: "OK",
            canDismiss: false,
            canCancel: false,
            onAccepted: () => {
                stopPlayer();
                clearDialogs();
            }
        });
    }

    function toast(obj) {
        const info = {
            id: obj?.id ?? -1,
            title: obj?.header ?? "Noon",
            message: obj?.content ?? "",
            icon: obj?.icon ?? "check",
            shape: obj?.shape ?? "Clover4Leaf",
            status: obj?.status ?? ""
        };

        let currentData = [...Globals.common.toasts.data];
        const itemId = currentData.findIndex(item => item.id === info.id);

        if (itemId !== -1) {
            currentData[itemId] = info;
        } else {
            if (currentData.length >= 5) {
                currentData.shift();
            }
            currentData.push(info);
        }

        Globals.common.toasts.data = currentData;
    }

    function notify(content, title, urgency = "normal") {
        let icon = Paths.assets + "/icons/noon-symbolic.svg";
        let titleStr = title ?? "Noon";
        Quickshell.execDetached(["notify-send", "-i", icon, "-a", titleStr, "-u", urgency, content]);
    }

    function notifyPhone(content) {
        KdeConnectService.pingSelectedDevice(content);
    }

    function execDetached(cmd) {
        let command = cmd;
        if (typeof cmd !== "string")
            command = cmd.join(" ").toString();

        Quickshell.execDetached(["bash", "-c", command]);
    }

    function runInTerminal(command) {
        execDetached(["kitty", "-e", "fish", "-c", command]);
    }

    function checkIfDlp(url) {
        const avList = ["youtube.com", "youtu.be", "facebook.com", "twitter.com", "x.com", "instagram.com", "tiktok.com", "twitch.tv", "reddit.com", "soundcloud.com", "spotify.com", "archive.org", "pornhub.com", "crunchyroll.com", "plex.tv", "imgur.com", "streamable.com", "udemy.com", "coursera.org", "khan academy.org"];
        return avList.some(domain => url.toLowerCase().includes(domain));
    }

    function inlineStdProc(command, callback) {
        let proc = procRunnerComponent.createObject(root, {
            command: Array.isArray(command) ? command : [command],
            callback: callback
        });
        proc.running = true;
    }

    function inlineTimer(callback, delay = Mem.options.hacks.arbitraryRaceConditionDelay) {
        let timer = timerComponent.createObject(root, {
            interval: delay,
            repeat: false
        });
        timer.triggered.connect(() => {
            callback();
            timer.destroy();
        });
        timer.start();
    }

    function isOnlineUrl(url) {
        return url.startsWith("http") || url.startsWith("https" || url.contains("www"));
    }

    function runDownloader(url) {
        if (isOnlineUrl(url)) {
            if (checkIfDlp(url)) {
                Globals.main.sysDialogs.pendingData = url;
                Globals.main.sysDialogs.mode = "dlp";
            }
        }
    }

    function fetchCommands() {
        if (!commandsReady)
            commandLoader.running = true;
    }

    Process {
        id: commandLoader
        running: Mem.ready && Mem.store.misc.systemCommands.length === 0
        command: ["bash", "-c", "compgen -c | sort -u "]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim();
                const all = out.split("\n");
                Mem.store.misc.systemCommands = all;
                root.commandsReady = true;
                console.log("[Noon] fetched Bash commands");
            }
        }
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            volume: 0.15
        }

        property int remainingRepeats: 0

        onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState && remainingRepeats > 1) {
            remainingRepeats--;
            player.play();
        }
    }
}
