pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import QtMultimedia
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils
import qs.common.widgets
import qs.common.functions
import qs.modules.apps
import qs.services

Singleton {
    id: root

    property bool commandsReady: false
    readonly property Component procRunnerComponent: PlainStdoutProc {}
    readonly property Component timerComponent: Timer {}

    function spawnApp(name, propTable = {}) {
        const component = Qt.createComponent(Qt.resolvedUrl("../modules/apps/" + TextUtils.capitalizeFirstLetter(name) + ".qml"));
        if (component.status !== Component.Ready) {
            console.error("spawnApp: cannot load " + name + ": " + component.errorString());
            return null;
        }
        return component.createObject(root, propTable ?? {});
    }
    function runSystemUpdate() {
        execDetached([Paths.scriptsDir + "/distro_update.sh"]);
    }
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
    function noteSite(s) {
        const all = Mem.store.services.search.history;
        if (all.indexOf(s) === -1)
            Mem.store.services.search.history = [...all, TextUtils.getBaseUrl(s)];
    }
    function searchOnline(query) {
        if (/www|http|https/.test(query)) {
            noteSite(query);
            open(query);
            return;
        }
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
        execDetached(["pkexec", ...args]);
    }

    function stopPlayer() {
        if (player.playbackState === MediaPlayer.PlayingState)
            player.stop();
    }

    function startPlayer(obj) {
        const name = obj.name;
        const pack = Mem.options.desktop?.behavior?.sounds?.soundPack ?? "freedesktop";
        const info = Mem.store.services.sounds.availableSounds.find(i => i.name === pack);
        const path = (info?.path ?? "/usr/share/sounds/freedesktop") + "/stereo/" + name + ".oga";
        const repeats = obj.repeats < 0 ? MediaPlayer.Infinite : (obj?.repeats ?? 1);

        if (player.playbackState === MediaPlayer.PlayingState)
            player.stop();
        player.loops = repeats;
        player.audioOutput.volume = obj?.volume ?? 0.1;
        player.source = "file://" + path;
        Qt.callLater(() => {
            player.play();
        });
    }

    function playSound(sound, opts = {}) {
        if (Mem.ready && Mem.options.desktop.behavior.sounds.enabled && !Mem.states.services.notifications.silent) {
            const name = (typeof sound === "function") ? sound() : sound;
            startPlayer(Object.assign({}, {
                name: name,
                repeats: 1,
                volume: 0.01
            }, opts));
        }
    }

    function wake(name = "Wake Up!", message = "Click Below to Dismiss") {
        startPlayer({
            name: "alarm-clock-elapsed",
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
        if (Array.isArray(cmd))
            Quickshell.execDetached(["bash", "-c", cmd.join(' ')]);
        else
            Quickshell.execDetached(["bash", "-c", String(cmd)]);
    }

    function runInTerminal(command) {
        execDetached(["kitty", "-e", "fish", "-c", command]);
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

    function isProcRunning(proc, callback) {
        inlineStdProc(["pidof", proc], out => {
            callback(out.length > 0);
        });
    }

    function isOnlineUrl(url) {
        return url.startsWith("http") || url.startsWith("https" || url.contains("www"));
    }

    function runDownloader(url) {
        if (isOnlineUrl(url)) {
            Globals.main.beam.payload = url;
            Globals.main.beam.show = true;
            Globals.main.beam.reason = "dlp";
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

    Fetcher {
        id: soundFetch
        running: true
        command: [Paths.scriptsDir + "/get_sounds.sh"]
        onDataChanged: if (data)
            Mem.store.services.sounds.availableSounds = data
    }

    MediaPlayer {
        id: player
        audioOutput: AudioOutput {
            volume: Mem.options.desktop.behavior.sounds.level ?? 0.15
        }

        property int remainingRepeats: 0

        onPlaybackStateChanged: if (playbackState === MediaPlayer.StoppedState && remainingRepeats > 1) {
            remainingRepeats--;
            player.play();
        }
    }
}
