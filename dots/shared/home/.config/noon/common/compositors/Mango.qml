pragma ComponentBehavior: Bound

/*
* Mango backend. Tags are per monitor, not global workspaces: no names, special
* tag, Hyprland lua dispatch, focus grab, night light or animations. IPC allows
* one watch per socket, so each stream owns a connection. Focus comes from the
* shared Wayland toplevel manager instead of a third socket.
*/

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs.common
import qs.common.utils

AbstractCompositor {
    id: root

    readonly property string socketPath: Quickshell.env("MANGO_INSTANCE_SIGNATURE") ?? ""
    readonly property var activeTop: ToplevelManager.activeToplevel
    readonly property var transformMap: ({
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
        property var monitors: []
        property var rawClients: []
        property var workspaces: []
        property var activeWorkspace: ({
                                           id: 1,
                                           name: "1"
                                       })
        property var keyboardLayouts: ["English (US)"]
        property string currentKeyboardLayout: "English (US)"
    }

    readonly property var focusedWindow: root.windowList.find(w => w.focused)
    readonly property string focusedMonitorName: focusedWindow?.monitor ?? root.activeTop?.screen?.name ?? ""

    monitors: data.monitors
    windowList: root.mapClients()
    workspaces: data.workspaces
    windowByAddress: root.mapByAddress(root.windowList)
    activeWorkspace: data.activeWorkspace
    focusedWorkspace: data.activeWorkspace
    focusedMonitor: root.monitorFor(root.focusedMonitorName) ?? (data.monitors.length ? data.monitors[0] :
                                                                                        null)
    currentKeyboardLayout: data.currentKeyboardLayout
    keyboardLayouts: data.keyboardLayouts
    keyboardLayoutShortName: (data.currentKeyboardLayout || "").substring(0, 2).toUpperCase()

    function makeWs(id) {
        return {
            id: id,
            name: String(id)
        };
    }

    function parsed(line) {
        try {
            return JSON.parse(line);
        } catch (e) {
            return null;
        }
    }

    function mmsg(cmd) {
        Quickshell.execDetached(["mmsg", "dispatch", cmd]);
    }

    function dispatch(cmd) {
        mmsg(cmd);
    }

    function switchKeyboardLayout() {
        mmsg("switch_keyboard_layout");
    }

    function focusWs(ws) {
        const s = String(ws).trim();
        if (s === "special")
            return mmsg("view," + (data.monitors[0]?.tagNum ?? 9) + ",0");
        const rel = s.match(/^r?([+-]\d+)$/);
        if (rel)
            return mmsg(parseInt(rel[1], 10) > 0 ? "viewtoright" : "viewtoleft");
        const id = parseInt(s, 10);
        if (id > 0)
            mmsg("view," + id + ",0");
    }

    function monitorFor(screen) {
        const name = screen?.name ?? screen;
        const mons = data.monitors;
        return mons.find(m => m.name === name) ?? mons.find(m => m.active) ?? (mons.length ? mons[0] : null);
    }

    function windowForToplevel(t) {
        if (!t)
            return null;
        const wins = root.windowList;
        return wins.find(w => w.pid && w.pid === t.pid) ?? wins.find(w => w.class === t.appId && w.title
                                                                          === t.title) ?? null;
    }

    function focusWindow(address) {
        if (address)
            mmsg("focusid client," + address);
    }

    function moveWindowToTag(address, tag) {
        if (address)
            mmsg("tag," + tag + ",0 client," + address);
    }

    function closeWindow(address) {
        if (address)
            mmsg("killclient client," + address);
    }

    function activeTag(m) {
        return m.active_tags?.[0] ?? m.tags?.find(t => t.is_active)?.index ?? 1;
    }

    function readMonitors(line) {
        const msg = root.parsed(line);
        if (!msg)
            return;
        const raw = msg.monitors ?? [];
        data.monitors = raw.map(m => ({
            name: m.name,
            active: !!m.active,
            x: m.x ?? 0,
            y: m.y ?? 0,
            width: m.width ?? 0,
            height: m.height ?? 0,
            scale: m.scale ?? 1,
            transform: root.transformMap[m.transform] ?? 0,
            activeWorkspace: makeWs(root.activeTag(m)),
            tagNum: m.tag_num ?? 9
        }));

        const focused = raw.find(m => m.active) ?? raw[0];
        if (focused) {
            data.activeWorkspace = makeWs(root.activeTag(focused));
            if (focused.keyboardlayout) {
                data.currentKeyboardLayout = focused.keyboardlayout;
                data.keyboardLayouts = [focused.keyboardlayout];
            }
        }

        const activeIds = new Set();
        for (const m of raw)
            for (const id of m.active_tags ?? [])
                activeIds.add(id);

        const counts = new Map();
        for (const m of raw)
            for (const t of m.tags ?? [])
                if (t.client_count > 0 || activeIds.has(t.index))
                    counts.set(t.index, t.client_count ?? 0);

        data.workspaces = [...counts].sort((a, b) => a[0] - b[0]).map(([id, clients]) => ({
            id: id,
            name: String(id),
            monitor: focused?.name ?? "",
            windows: clients,
            occupied: clients > 0,
            active: activeIds.has(id)
        }));
    }

    function focusedClient() {
        const active = root.activeTop;
        if (!active)
            return null;
        const byApp = data.rawClients.filter(c => c.appid === active.appId);
        const byTitle = data.rawClients.filter(c => c.title === active.title);
        return byApp.find(c => c.title === active.title) ?? (byApp.length === 1 ? byApp[0] : null) ?? (
                    byTitle.length === 1 ? byTitle[0] : null);
    }

    function mapClients() {
        const focused = root.focusedClient();
        return data.rawClients.map(c => ({
            address: String(c.id),
            pid: c.pid,
            workspace: makeWs(c.tags?.[0] ?? 1),
            class: c.appid ?? "",
            title: c.title ?? "",
            monitor: c.monitor,
            at: [c.x ?? 0, c.y ?? 0],
            size: [c.width ?? 0, c.height ?? 0],
            mapped: !!c.is_visible,
            floating: !!c.is_floating,
            focused: focused ? c.id === focused.id : false,
            xwayland: !!c.is_xwayland
        }));
    }

        function mapByAddress(windows) {
        const byAddress = {};
        for (const w of windows)
        byAddress[w.address] = w;
        return byAddress;
    }

        function readClients(line) {
        const msg = root.parsed(line);
        if (!msg)
        return;
        data.rawClients = msg.clients ?? [];
    }

        function startWatch(sock, stream) {
        if (!sock.connected)
        return;
        sock.write("watch " + stream + "\n");
        sock.flush();
    }

        Socket {
        id: monitorSocket
        path: root.socketPath
        connected: true
        Component.onCompleted: root.startWatch(monitorSocket, "all-monitors")
        onConnectedChanged: root.startWatch(monitorSocket, "all-monitors")
        onError: e => console.warn("Mango monitors:", e)
        parser: SplitParser {
        onRead: line => root.readMonitors(line)
    }
    }

        Socket {
        id: clientSocket
        path: root.socketPath
        connected: true
        Component.onCompleted: root.startWatch(clientSocket, "all-clients")
        onConnectedChanged: root.startWatch(clientSocket, "all-clients")
        onError: e => console.warn("Mango clients:", e)
        parser: SplitParser {
        onRead: line => root.readClients(line)
    }
    }

        MangoConfigGenerator {
        id: configGenerator
    }

        Timer {
        interval: 2000
        running: root.socketPath !== ""
        repeat: true
        onTriggered: {
        if (!monitorSocket.connected)
        monitorSocket.connected = true;
        if (!clientSocket.connected)
        clientSocket.connected = true;
    }
    }
    }
