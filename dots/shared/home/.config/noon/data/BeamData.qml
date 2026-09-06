pragma Singleton
import QtQuick
import Quickshell

import qs.common
import qs.common.widgets
import qs.common.utils
import qs.services

Singleton {
    id: root

    property string query: ""
    property string activeHint: ""
    property var suggestedApp: null
    property string activeState: defaultState
    property string activeSubState: ""
    property var registry: rebuildRegistry()

    readonly property string defaultState: Mem.options.beam.behavior?.defaultState ?? "launch"
    readonly property string cleanQuery: query.substring(activeState === defaultState ? 0 : config?.prefix?.length)
    readonly property var config: registry[activeState]
    readonly property var subConfig: config?.subStates ? config.subStates[activeSubState] : null
    readonly property var rawBeamPlugins: PluginsManager?.beamPlugins
    readonly property list<string> availableAnimationStyles: ["slidebottom", "expo", "springPop", "glide"]
    readonly property int dynamicWidth: getDynamicWidth()

    onQueryChanged: {
        if (query && query.length === 0) {
            reset();
            return;
        }
        const pair = Object.entries(registry).find(([, c]) => c.prefix === query[0]) ?? [];
        const [key, cfg] = pair;
        const remainder = query.substring(1);
        activeState = key || defaultState;
        activeSubState = !cfg?.subStates || !remainder ? "" : Object.keys(cfg.subStates).find(k => cfg.subStates[k].prefix && remainder.startsWith(cfg.subStates[k].prefix)) ?? Object.keys(cfg.subStates)[0] ?? "";
    }

    onRawBeamPluginsChanged: rebuildRegistry()

    readonly property var mainContent: {
        "ai": {
            prefix: "^",
            description: "Sends Query to AI",
            icon: "thread_unread",
            shape: "Ghostish",
            placeholder: "You Can Ask Me Any Thing ..",
            showHint: false,
            hinter: () => "",
            executor: () => {
                Harness.sendUserMessage(query);
                revealSidebar("API");
            }
        },
        "calc": {
            prefix: "=",
            icon: "calculate",
            description: "Calculate math expressions",
            shape: "Hexagon",
            placeholder: "Calculate ..",
            showHint: true,
            autoComplete: true,
            hinter: () => {
                if (cleanQuery.length > 0) {
                    QalcService.calculate(cleanQuery, result => {
                        if (activeState === "calc")
                            activeHint = result;
                    });
                }
                return activeHint;
            },
            executor: () => {
                if (QalcService.result)
                    ClipboardService.copy(QalcService.result);
            }
        },
        "note": {
            prefix: ",",
            icon: "stylus",
            description: "Note Query",
            shape: "Slanted",
            placeholder: "Note ..",
            showHint: false,
            hinter: () => "",
            executor: () => {
                const separator = Mem.options.beam.behavior.addSeparatorForNotes ? "\n - - - " : "";
                NotesService.note(cleanQuery + separator);
                revealSidebar("Notes");
            }
        },
        "launch": {
            prefix: ".",
            icon: "rocket_launch",
            shape: "Pentagon",
            description: "Launch An Application",
            placeholder: "Launch App ..",
            showHint: true,
            hinter: () => {
                if (cleanQuery === "") {
                    suggestedApp = null;
                    return "";
                }
                const allApps = [...DesktopEntries.applications.values];
                const q = cleanQuery.toLowerCase();
                let bestMatch = null;
                let bestScore = 0;
                for (let app of allApps) {
                    const name = (app.name || "").toLowerCase();
                    const genericName = (app.genericName || "").toLowerCase();
                    let score = 0;
                    if (name.startsWith(q))
                        score = 100 + (100 - name.length);
                    else if (name.includes(q))
                        score = 50;
                    if (genericName.startsWith(q))
                        score = Math.max(score, 90);
                    else if (genericName.includes(q))
                        score = Math.max(score, 45);
                    const acronym = name.split(/\s+/).map(w => w[0]).join("").toLowerCase();
                    if (acronym === q)
                        score = Math.max(score, 95);
                    if (score > bestScore) {
                        bestScore = score;
                        bestMatch = app;
                    }
                }
                suggestedApp = bestMatch;
                return bestMatch ? bestMatch.name : "";
            },
            executor: () => {
                if (suggestedApp) {
                    const entry = DesktopEntries.byId(suggestedApp.id);
                    if (entry)
                        entry.execute();
                }
            }
        },
        "timer": {
            prefix: "~",
            icon: "hourglass",
            shape: "Clover8Leaf",
            description: "Creates a timer in friendly format, eg: 10m",
            placeholder: "How Long ..",
            showHint: false,
            hinter: () => "",
            executor: () => {
                const parts = cleanQuery.trim().split(/\s+/);
                const name = cleanQuery.includes(":") ? "Alarm" : "FocusTimer";
                const duration = TimerService.parseTimeString(parts[0]);
                const rest = parts.slice(1)?.join(" ") || name;

                if (duration > 0)
                    TimerService.addTimer(rest, duration, true, true);
                else if (cleanQuery.includes(":"))
                    TimerService.wake(parts[0], rest);

                revealSidebar("Timers");
            }
        },
        "todo": {
            prefix: "/",
            description: "Create New task",
            icon: "task_alt",
            shape: "Cookie4Sided",
            placeholder: "Any plans ..?",
            showHint: false,
            hinter: () => "",
            executor: () => {
                TodoService.addTask(cleanQuery);
                revealSidebar("Todo");
            }
        },
        "search": {
            prefix: "?",
            description: "Search Online with Query",
            icon: "search",
            shape: "PixelCircle",
            placeholder: "Wanna Search Google ..?",
            showHint: true,
            hinter: () => {
                // TODO CATCH COMMANDS AND HINT THEM ALSO FUZZY SEARCH 'EM
                if (!subConfig && Mem.store.search.data.length > 0) {
                    const q = cleanQuery.toLowerCase();
                    for (let site of Mem.store.search.data) {
                        if (site.toLowerCase().startsWith(q))
                            return site;
                    }
                }
                return "";
            },
            executor: () => {
                const searchUrl = subConfig?.searchQuery || Mem.options.networking.searchEngine;
                const searchText = subConfig ? cleanQuery.substring(subConfig.prefix.length) : cleanQuery;
                if (!subConfig.exec)
                    NoonUtils.searchOnline(searchText);
                else
                    subConfig.exec(searchText);
            },
            subStates: {
                "search": {
                    prefix: "",
                    icon: "search",
                    searchQuery: Mem.options.networking.searchEngine,
                    shape: "PixelCircle"
                },
                "yt_music": {
                    prefix: "/m",
                    description: "Search In Youtube Music Directly",
                    icon: "music_note",
                    shape: "Bun",
                    exec: query => {
                        BeatsService.search(query);
                        Globals.main.sidebar.setTab(2);
                        revealSidebar("Beats");
                    }
                },
                "youtube": {
                    prefix: "/y",
                    description: "Search In Youtube",
                    icon: "play_arrow",
                    shape: "Pill",
                    exec: query => {
                        const link = `https://www.youtube.com/results?search_query=${encodeURIComponent(query)}`;
                        NoonUtils.open(`"${link}"`);
                    }
                },
                "spotify": {
                    prefix: "/s",
                    description: "Search In Spotify Directly",
                    icon: "music_cast",
                    searchQuery: "https://open.spotify.com/search/",
                    shape: "Cookie7Sided"
                }
            }
        },
        "download": {
            prefix: "-",
            description: "Downloads with yt-dlp",
            icon: "download",
            shape: "Arrow",
            placeholder: "Download ..?",
            showHint: false,
            hinter: () => "",
            executor: () => {
                const raw = cleanQuery.trim();
                const prefix = subConfig?.prefix ?? "";
                const query = prefix && raw.startsWith(prefix + " ") ? raw.substring(prefix.length).trim() : raw;
                if (subConfig?.exec)
                    subConfig.exec(query);
            },
            subStates: {
                "video": {
                    prefix: "v",
                    description: "handle video links",
                    icon: "play_arrow",
                    shape: "PixelCircle",
                    exec: query => DlpService.request({
                            url: query,
                            video: true,
                            directory: Paths.standard.downloads,
                            toast: true
                        })
                },
                "audio": {
                    prefix: "m",
                    description: "handle music links",
                    icon: "music_note",
                    shape: "PixelCircle",
                    exec: query => DlpService.request({
                            url: query,
                            audio: true,
                            directory: BeatsService.tracksDir,
                            toast: true
                        })
                },
                "audio_search": {
                    prefix: "?m",
                    description: "search and match query for audio",
                    icon: "music_note",
                    shape: "PixelCircle",
                    exec: query => DlpService.request({
                            title: query,
                            audio: true,
                            directory: BeatsService.tracksDir
                        })
                }
            }
        }
    }
    readonly property var oldContent: {
        "commands": {
            prefix: ";",
            description: "Execute Bash Commands",
            icon: "keyboard_return",
            shape: "Oval",
            placeholder: "Command Master ..",
            showHint: true,
            hinter: () => {
                if (Mem.store.misc.systemCommands.length < 1)
                    NoonUtils.fetchCommands();
                const q = cleanQuery.toLowerCase();
                for (let cmd of Mem.store.misc.systemCommands) {
                    if (cmd.toLowerCase().startsWith(q))
                        return cmd;
                }
                return "";
            },
            executor: () => Quickshell.execDetached(["bash", "-c", cleanQuery])
        },
        "translate": {
            prefix: ">",
            icon: "translate",
            description: "Translate Query",
            shape: "Arrow",
            placeholder: "Translate ..?",
            showHint: true,
            autoComplete: true,
            hinter: () => {
                if (cleanQuery.length > 0) {
                    TranslatorService.translate(cleanQuery, result => {
                        if (activeState === "translate")
                            activeHint = result;
                    });
                }
                return activeHint;
            },
            executor: () => {
                if (TranslatorService.translatedText)
                    ClipboardService.copy(TranslatorService.translatedText);
            }
        },
        "ipc": {
            prefix: "!",
            description: "Launch ipc command",
            icon: "moon_stars",
            shape: "Pentagon",
            placeholder: "Just Order ..?",
            showHint: true,
            hinter: () => {
                const q = cleanQuery.toLowerCase();
                for (let cmd of Ipc.commands) {
                    if (cmd.toLowerCase().startsWith(q))
                        return cmd;
                }
                return "";
            },
            executor: () => Ipc.call(Ipc.split(cleanQuery))
        }
    }

    readonly property var applets: [
        {
            name: "music",
            visible: MediaPlayerService.players.length > 0,
            path: "applets/Music"
        },
        {
            name: "weather",
            visible: WeatherService.isReady,
            path: "applets/Weather"
        }
    ]
    readonly property var sizes: Sizes.beam
    readonly property var contentMap: {
        "default": getDefaultBeamOptions(),
        "dictate": {
            timeout: false,
            size: sizes.dictate,
            overlay: "DictationOverlay",
            component: "DictationContentView"
        },
        "shot": {
            timeout: false,
            size: sizes.screenshot,
            overlay: "ScreenShotOverlay",
            component: "ScreenShotContentView"
        },
        "drop": {
            dim: true,
            radius: 64,
            size: sizes.drop,
            component: "DropContentView"
        },
        "music": {
            dim: true,
            transparent: true,
            radius: 0,
            timeout: false,
            size: sizes.music,
            component: "MusicContentView"
        },
        "hints": {
            dim: true,
            radius: 48,
            timeout: false,
            size: sizes.hints,
            component: "HintsContentView"
        },
        "weather": {
            dim: true,
            radius: 48,
            timeout: false,
            size: sizes.weather,
            component: "WeatherContentView"
        },
        "appearance": {
            dim: false,
            radius: Rounding.full,
            timeout: false,
            size: sizes.appearance,
            target: "Globals.main.showBgOverview",
            when: !Globals.topLevel?.activated && Globals.main.beam.show && Globals.main.beam.reason === "appearance",
            component: "AppearanceContentView"
        }
    }

    function reset() {
        query = "";
        activeSubState = "";
        suggestedApp = null;
        activeState = defaultState;
    }
    function getDynamicWidth(size = [470, 100]) {
        return Math.max(getHint().length, query.length) > 25 ? size?.[1] : size?.[0];
    }

    function getIcon() {
        if (subConfig)
            return subConfig.icon;
        return config?.icon || "question_mark";
    }

    function getShape() {
        if (subConfig)
            return MaterialShape.Shape[subConfig?.shape];
        return MaterialShape.Shape[config?.shape];
    }

    function getHint() {
        if (!config.showHint) {
            activeHint = "";
            return "";
        }
        NoonUtils.inlineTimer(() => {
            activeHint = config?.hinter ? config.hinter() : "";
        }, 50);
        return activeHint;
    }

    function buildPlugins() {
        const raw = rawBeamPlugins;
        if (!raw || Object.keys(raw).length === 0)
            return {};

        const ctx = {
            get cleanQuery() {
                return root.cleanQuery;
            },
            get activeState() {
                return root.activeState;
            },
            get activeHint() {
                return root.activeHint;
            },
            set activeHint(v) {
                root.activeHint = v;
            },
            exec: cmd => Quickshell.execDetached(["bash", "-c", cmd.replace(/\$q/g, root.cleanQuery)]),
            shell: (cmd, cb) => {
                if (root.cleanQuery === shellRunner.lastQuery)
                    return;
                shellRunner.lastQuery = root.cleanQuery;
                shellRunner.run(cmd, cb);
            }
        };

        const wrap = fn => fn ? new Function("ctx", `with(ctx){ return (${fn.replace(/%q/g, "ctx.cleanQuery")}) }`)(ctx) : null;

        const result = {};
        for (let key in raw) {
            const p = raw[key];
            const isEnabled = p.enabled === undefined ? true : p.enabled === true;
            if (!isEnabled)
                continue;
            result[key] = Object.assign({}, p, {
                hinter: wrap(p.hinter) ?? (() => ""),
                executor: wrap(p.executor) ?? (() => {})
            });
        }
        return result;
    }

    function rebuildRegistry() {
        let plugins = buildPlugins();
        let original = [mainContent, plugins];
        if (Mem.options.beam.behavior.enableOldContent)
            original.push(root.oldContent);
        registry = Object.assign({}, ...original);
    }

    function executeCommand() {
        if (cleanQuery.length > 0 && !!config?.executor) {
            config.executor();
        }
    }

    function revealSidebar(cat) {
        Ipc.call(["sidebar", "reveal", cat]);
    }

    function autocomplete(hintText) {
        if (!hintText)
            return query;

        const prefix = config?.prefix || "";

        if (config?.autoComplete ?? false)
            return query;

        return prefix + hintText;
    }
    readonly property var availableDefaultThemes: {
        "default": {
            "component": "BeamContentView",
            "ignoreRadiusComplement": false,
            "size": Qt.size(root.dynamicWidth, Sizes.beam.normal.height),
            "radius": Rounding.silly
        },
        "alternate": {
            "component": "BeamAlternateView",
            "transparent": true,
            "popupRadius": Rounding.huge,
            "ignoreRadiusComplement": true,
            "size": Qt.size(getDynamicWidth([450, 1100]), Sizes.beam.normal.height + Padding.huge)
        }
    }

    function getDefaultBeamOptions() {
        const current = Mem.options.beam.appearance?.theme ?? "default";
        return availableDefaultThemes[(current ?? "default")];
    }
    Process {
        id: shellRunner

        property string data: ""
        property var pendingCb: null
        property string lastQuery: ""

        function run(cmd, cb) {
            if (running)
                running = false;
            data = "";
            pendingCb = cb ?? null;
            command = ["bash", "-c", cmd.replace(/\$q/g, root.cleanQuery)];
            running = true;
        }

        stdout: SplitParser {
            onRead: data => shellRunner.data += data + "\n"
        }

        onExited: {
            const out = data.trim();
            root.activeHint = out;
            if (pendingCb)
                pendingCb(out);
            pendingCb = null;
            data = "";
        }
    }
}
