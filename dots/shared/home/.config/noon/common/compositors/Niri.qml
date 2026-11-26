pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common.utils
import qs.common

AbstractCompositor {
    id: root
    readonly property string socketPath: Quickshell.env("NIRI_SOCKET") ?? ""
    readonly property var activeTop: ToplevelManager.activeToplevel
    readonly property var transformMap: ({
            "normal": 0,
            "90": 1,
            "180": 2,
            "270": 3,
            "flipped": 4,
            "flipped-90": 5,
            "flipped-180": 6,
            "flipped-270": 7
        })

    QtObject {
        id: data
        property var wsById: ({})
        property var winById: ({})
        property var rawOutputs: []
        property string outputsSig: ""
        property string workspacesSig: ""
        property string monitorsSig: ""
        property string windowsSig: ""
        property var monitors: []
        property var workspaces: []
        property var windowList: []
        property var windowByAddress: ({})
        property var activeWorkspace: ({
                id: 1,
                name: "1"
            })
        property var keyboardLayouts: []
        property var layoutNames: []
        property string currentKeyboardLayout: ""
        property int layoutIndex: 0
        property string focusedMonitorName: ""
    }

    monitors: data.monitors
    windowList: data.windowList
    workspaces: data.workspaces
    windowByAddress: data.windowByAddress
    activeWorkspace: data.activeWorkspace
    focusedWorkspace: data.activeWorkspace
    focusedMonitor: monitorFor(data.focusedMonitorName) ?? (data.monitors.length ? data.monitors[0] : null)
    currentKeyboardLayout: data.currentKeyboardLayout
    keyboardLayouts: data.keyboardLayouts
    keyboardLayoutShortName: (data.currentKeyboardLayout || "").substring(0, 2).toUpperCase()

    function parsed(line) {
        try {
            return JSON.parse(line);
        } catch (e) {
            return null;
        }
    }

    function writeLine(text, socket) {
        if (!root.socketPath || !socket || !socket.connected)
            return;
        socket.write(text + "\n");
        socket.flush();
    }

    function request(name) {
        root.writeLine(JSON.stringify(name), requestSocket);
    }

    function action(name, args) {
        const wrapper = {};
        wrapper[name] = args ?? {};
        root.writeLine(JSON.stringify({
            Action: wrapper
        }), requestSocket);
    }

    function syncLayouts() {
        data.keyboardLayouts = data.layoutNames.slice();
        data.currentKeyboardLayout = data.layoutNames[data.layoutIndex] ?? "";
    }

    function readKeyboardLayouts(layouts) {
        data.layoutNames = Array.isArray(layouts?.names) ? layouts.names.slice() : [];
        data.layoutIndex = layouts?.current_idx ?? 0;
        root.syncLayouts();
    }

    function scheduleRebuild() {
        if (!rebuildTimer.running)
            rebuildTimer.start();
    }

    function rebuild() {
        const rawWs = Object.values(data.wsById);
        const rawWin = Object.values(data.winById);

        const active = root.activeTop;
        const byApp = active ? rawWin.filter(w => w.app_id === active.appId) : [];
        const byTitle = active ? rawWin.filter(w => w.title === active.title) : [];
        const focusedWin = active
            ? (byApp.find(w => w.title === active.title)
                ?? (byApp.length === 1 ? byApp[0] : null)
                ?? (byTitle.length === 1 ? byTitle[0] : null))
            : null;
        const focusedWinId = focusedWin?.id ?? null;

        const counts = {};
        for (const w of rawWin)
            counts[w.workspace_id] = (counts[w.workspace_id] ?? 0) + 1;

        rawWs.sort((a, b) => {
            const byOutput = String(a.output ?? "").localeCompare(String(b.output ?? ""));
            return byOutput || ((a.idx ?? 0) - (b.idx ?? 0));
        });

        const list = rawWs.map((ws, index) => {
            const count = counts[ws.id] ?? 0;
            return {
                id: index + 1,
                niriId: ws.id,
                name: ws.name ?? String(ws.id),
                idx: ws.idx,
                monitor: ws.output ?? "",
                windows: count,
                occupied: count > 0,
                active: !!ws.is_active,
                focused: !!ws.is_focused,
                urgent: !!ws.is_urgent,
                activeWindow: ws.active_window_id ?? null
            };
        });

        const focused = list.find(ws => ws.focused)
            ?? list.find(ws => ws.monitor === data.focusedMonitorName && ws.active)
            ?? list.find(ws => ws.active)
            ?? null;
        if (focused?.monitor)
            data.focusedMonitorName = focused.monitor;

        const wsSig = JSON.stringify(list);
        if (wsSig !== data.workspacesSig) {
            data.workspacesSig = wsSig;
            data.workspaces = list;
            data.activeWorkspace = focused ?? ({
                    id: 1,
                    name: "1"
                });
        }

        const activeByOutput = {};
        const wsByNiriId = {};
        for (const ws of list) {
            wsByNiriId[ws.niriId] = ws;
            if (ws.active && ws.monitor)
                activeByOutput[ws.monitor] = ws;
        }

        if (focusedWin?.workspace_id) {
            const monitor = wsByNiriId[focusedWin.workspace_id]?.monitor;
            if (monitor)
                data.focusedMonitorName = monitor;
        }

        const monitors = data.rawOutputs.map(o => {
            const logical = o.logical ?? {};
            const name = o.name ?? "";
            const transform = typeof logical.transform === "string"
                ? (root.transformMap[logical.transform] ?? 0)
                : (Number(logical.transform) || 0);
            return {
                name: name,
                make: o.make ?? "",
                model: o.model ?? "",
                active: true,
                x: logical.x ?? 0,
                y: logical.y ?? 0,
                width: logical.width ?? 0,
                height: logical.height ?? 0,
                scale: logical.scale ?? 1,
                transform: transform,
                vrr: !!o.vrr_enabled,
                activeWorkspace: activeByOutput[name] ?? null,
                tagNum: 10,
                reserved: [0, 0, 0, 0]
            };
        });

        const monSig = JSON.stringify(monitors);
        if (monSig !== data.monitorsSig) {
            data.monitorsSig = monSig;
            data.monitors = monitors;
        }

        const monitorByOutput = {};
        for (const m of monitors)
            monitorByOutput[m.name] = m;

        const winList = rawWin.map(w => {
            const ws = wsByNiriId[w.workspace_id];
            const monitor = monitorByOutput[ws?.monitor ?? ""] ?? null;
            const layout = w.layout ?? {};
            const tilePos = Array.isArray(layout.tile_pos_in_workspace_view)
                ? layout.tile_pos_in_workspace_view
                : [0, 0];
            const tileSize = Array.isArray(layout.tile_size) ? layout.tile_size : [0, 0];
            return {
                address: String(w.id),
                pid: w.pid ?? null,
                workspace: {
                    id: ws?.id ?? 0,
                    name: ws?.name ?? String(w.workspace_id ?? ""),
                    niriId: w.workspace_id ?? null
                },
                class: w.app_id ?? "",
                title: w.title ?? "",
                monitor: ws?.monitor ?? "",
                at: [
                    Math.round((tilePos[0] ?? 0) + (monitor?.x ?? 0)),
                    Math.round((tilePos[1] ?? 0) + (monitor?.y ?? 0))
                ],
                size: [Math.round(tileSize[0] ?? 0), Math.round(tileSize[1] ?? 0)],
                mapped: true,
                floating: !!w.is_floating,
                focused: w.id === focusedWinId,
                urgent: !!w.is_urgent,
                xwayland: false
            };
        });

        const winSig = JSON.stringify(winList);
        if (winSig !== data.windowsSig) {
            data.windowsSig = winSig;
            const byAddress = {};
            for (const win of winList)
                byAddress[win.address] = win;
            data.windowList = winList;
            data.windowByAddress = byAddress;
        }
    }

    function readOutputs(value) {
        let list = [];
        if (Array.isArray(value)) {
            list = value.slice();
        } else if (value && typeof value === "object") {
            for (const name of Object.keys(value)) {
                const output = Object.assign({}, value[name]);
                if (!output.name)
                    output.name = name;
                list.push(output);
            }
        }

        const outputs = list.filter(o => o.logical);
        const sig = JSON.stringify(outputs);
        if (sig === data.outputsSig)
            return;
        data.outputsSig = sig;
        data.rawOutputs = outputs;
        root.scheduleRebuild();
    }

    function readEvent(line) {
        const msg = root.parsed(line);
        if (!msg)
            return;

        if (msg.Err !== undefined) {
            console.warn("Niri IPC error:", JSON.stringify(msg.Err));
            return;
        }

        let payload = msg.Ok !== undefined ? msg.Ok : msg;
        if (typeof payload === "string")
            return;
        if (payload?.Event !== undefined)
            payload = payload.Event;
        if (payload?.Outputs !== undefined) {
            root.readOutputs(payload.Outputs);
            return;
        }
        if (payload?.KeyboardLayouts !== undefined) {
            root.readKeyboardLayouts(payload.KeyboardLayouts);
            return;
        }

        const key = Object.keys(payload ?? {})[0];
        if (!key)
            return;
        const body = payload[key] ?? {};

        switch (key) {
        case "ConfigLoaded":
            root.request("Outputs");
            root.request("KeyboardLayouts");
            break;
        case "WorkspacesChanged":
            {
                const map = {};
                for (const ws of Array.isArray(body.workspaces) ? body.workspaces : [])
                    map[ws.id] = ws;
                data.wsById = map;
                root.scheduleRebuild();
                break;
            }
        case "WorkspaceActivated":
            {
                const target = data.wsById[body.id];
                const output = target?.output;
                for (const ws of Object.values(data.wsById)) {
                    if (ws.output === output)
                        ws.is_active = ws.id === body.id;
                    if (body.focused)
                        ws.is_focused = ws.id === body.id;
                }
                if (body.focused && output)
                    data.focusedMonitorName = output;
                root.scheduleRebuild();
                break;
            }
        case "WorkspaceActiveWindowChanged":
            {
                const ws = data.wsById[body.workspace_id];
                if (ws) {
                    ws.active_window_id = body.active_window_id ?? null;
                    root.scheduleRebuild();
                }
                break;
            }
        case "WorkspaceUrgencyChanged":
            {
                const ws = data.wsById[body.id];
                if (ws) {
                    ws.is_urgent = !!body.urgent;
                    root.scheduleRebuild();
                }
                break;
            }
        case "WindowsChanged":
            {
                const map = {};
                for (const w of Array.isArray(body.windows) ? body.windows : [])
                    map[w.id] = w;
                data.winById = map;
                root.scheduleRebuild();
                break;
            }
        case "WindowOpenedOrChanged":
            {
                const win = body.window;
                if (win) {
                    data.winById[win.id] = Object.assign(data.winById[win.id] ?? {}, win);
                    root.scheduleRebuild();
                }
                break;
            }
        case "WindowClosed":
            delete data.winById[body.id];
            root.scheduleRebuild();
            break;
        case "WindowUrgencyChanged":
            {
                const w = data.winById[body.id];
                if (w) {
                    w.is_urgent = !!body.urgent;
                    root.scheduleRebuild();
                }
                break;
            }
        case "WindowLayoutsChanged":
            {
                let touched = false;
                for (const change of body.changes ?? []) {
                    if (Array.isArray(change) && change.length === 2) {
                        const w = data.winById[change[0]];
                        if (w) {
                            w.layout = change[1];
                            touched = true;
                        }
                    }
                }
                if (touched)
                    root.scheduleRebuild();
                break;
            }
        case "KeyboardLayoutsChanged":
            root.readKeyboardLayouts(body.keyboard_layouts);
            break;
        case "KeyboardLayoutSwitched":
            data.layoutIndex = body.idx ?? 0;
            root.syncLayouts();
            break;
        default:
            break;
        }
    }

    function wsRef(value) {
        if (value && typeof value === "object") {
            if (value.niriId !== undefined && value.niriId !== null)
                return {
                    Id: Number(value.niriId)
                };
            if (value.id !== undefined && value.id !== null) {
                const match = data.workspaces.find(ws => ws.id === value.id);
                if (match)
                    return {
                        Id: Number(match.niriId)
                    };
            }
            if (value.name)
                return {
                    Name: String(value.name)
                };
            return null;
        }

        const s = String(value ?? "").trim();
        if (s === "special")
            return null;

        const relative = s.match(/^r?([+-]\d+)$/);
        const num = relative ? parseInt(relative[1], 10) : (s.match(/^\d+$/) ? parseInt(s, 10) : NaN);
        if (!isNaN(num)) {
            const synthetic = data.workspaces.find(ws => ws.id === num);
            if (synthetic)
                return {
                    Id: Number(synthetic.niriId)
                };
            if (data.wsById[num])
                return {
                    Id: num
                };
            return {
                Index: Math.max(1, num)
            };
        }

        const named = Object.values(data.wsById).find(ws => ws.name === s);
        return named ? {
            Id: named.id
        } : {
            Name: s
        };
    }

    function switchKeyboardLayout() {
        root.action("SwitchLayout", {
            layout: "Next"
        });
    }

    function focusWs(ws) {
        const s = String(ws ?? "").trim();
        if (/^r?[+-]\d+$/.test(s)) {
            const delta = parseInt(s.replace(/^r/, ""), 10);
            root.action(delta > 0 ? "FocusWorkspaceDown" : "FocusWorkspaceUp");
            return;
        }
        if (s === "special") {
            root.action("FocusWorkspacePrevious");
            return;
        }
        const ref = root.wsRef(ws);
        if (ref)
            root.action("FocusWorkspace", {
                reference: ref
            });
    }

    function monitorFor(screen) {
        const name = screen?.name ?? screen;
        const mons = data.monitors;
        return mons.find(m => m.name === name) ?? mons.find(m => m.active) ?? (mons.length ? mons[0] : null);
    }

    function windowForToplevel(t) {
        if (!t)
            return null;
        const wins = data.windowList;
        const pid = t.pid ?? t.processId ?? null;
        return (pid ? wins.find(w => w.pid === pid) : null)
            ?? wins.find(w => w.class && w.class === t.appId && w.title === t.title)
            ?? null;
    }

    function focusWindow(address) {
        if (address)
            root.action("FocusWindow", {
                id: Number(address)
            });
    }

    function moveWindowToTag(address, tag) {
        if (String(tag ?? "").trim() === "special") {
            root.action("MoveWindowToWorkspaceUp");
            return;
        }
        const ref = root.wsRef(tag);
        if (!ref)
            return;
        root.action("MoveWindowToWorkspace", {
            window_id: address ? Number(address) : null,
            reference: ref,
            focus: true
        });
    }

    function closeWindow(address) {
        if (address)
            root.action("CloseWindow", {
                id: Number(address)
            });
    }

    Connections {
        target: ToplevelManager

        function onActiveToplevelChanged() {
            root.scheduleRebuild();
        }
    }

    Timer {
        id: rebuildTimer
        interval: 16
        repeat: false
        onTriggered: root.rebuild()
    }

    Socket {
        id: eventSocket
        path: root.socketPath
        connected: true
        onConnectedChanged: {
            if (eventSocket.connected)
                root.writeLine(JSON.stringify("EventStream"), eventSocket);
        }
        onError: e => console.warn("Niri event stream:", e)
        parser: SplitParser {
            onRead: line => root.readEvent(line)
        }
    }

    Socket {
        id: requestSocket
        path: root.socketPath
        connected: true
        onConnectedChanged: {
            if (requestSocket.connected) {
                root.request("Outputs");
                root.request("KeyboardLayouts");
            }
        }
        onError: e => console.warn("Niri IPC:", e)
        parser: SplitParser {
            onRead: line => root.readEvent(line)
        }
    }

    NiriConfigGenerator {
        id: mirror
    }

    Timer {
        interval: 2000
        running: root.socketPath !== ""
        repeat: true
        onTriggered: {
            if (!eventSocket.connected)
                eventSocket.connected = true;
            if (!requestSocket.connected)
                requestSocket.connected = true;
            if (eventSocket.connected && requestSocket.connected)
                root.request("Outputs");
        }
    }
}
