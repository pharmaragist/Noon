pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

// Thin QML adapter over scripts/store_service.py. The store only knows the
// Noon-Plugins GitHub index: list plugins, install one, done.
Singleton {
    id: root

    property var plugins: []
    property var pending: ({})
    property string outbox: ""
    property bool ready: false
    property bool loading: false
    property string error: ""
    property string installing: ""

    readonly property var groups: {
        const seen = ({});
        const out = [];
        for (const plugin of plugins) {
            const group = plugin && plugin.group ? plugin.group : "";
            if (group && !seen[group]) {
                seen[group] = true;
                out.push(group);
            }
        }
        out.sort();
        return out;
    }

    function send(method, params, cb) {
        const id = Date.now().toString(36) + Math.random().toString(36).slice(2, 6);
        if (cb)
            pending[id] = cb;

        const line = JSON.stringify({
            id,
            method,
            params: params || {}
        }) + "\n";

        if (proc.running && ready) {
            proc.write(line);
        } else {
            outbox += line;
            proc.running = true;
        }
        return id;
    }

    function refresh(cb) {
        loading = true;
        error = "";
        send("list", {
            force: true
        }, (res, err) => {
            loading = false;
            if (err) {
                error = err.message || "Store unreachable";
                if (cb)
                    cb(null, err);
                return;
            }
            plugins = res && Array.isArray(res.plugins) ? res.plugins : [];
            if (cb)
                cb(plugins, null);
        });
    }

    function ensure(cb) {
        if (plugins.length) {
            if (cb)
                cb(plugins, null);
            return;
        }
        refresh(cb);
    }

    function install(plugin, cb) {
        if (!plugin || !plugin.id || installing)
            return;

        installing = plugin.id;
        send("install", {
            id: plugin.id
        }, (res, err) => {
            installing = "";
            if (err) {
                if (cb)
                    cb(null, err);
                return;
            }
            plugins = plugins.map(p => p && p.id === plugin.id ? Object.assign({}, p, {
                installed: true
            }) : p);
            if (cb)
                cb(res, null);
        });
    }

    function groupIcon(group) {
        switch (group) {
        case "sidebar":
            return "view_sidebar";
        case "dock":
            return "dock";
        case "beam":
            return "terminal";
        case "palettes":
            return "palette";
        case "widgets":
            return "widgets";
        default:
            return "extension";
        }
    }

    function handleLine(data) {
        let message;
        try {
            message = JSON.parse(data);
        } catch (e) {
            return;
        }

        const cb = pending[message.id];
        if (!cb)
            return;

        delete pending[message.id];
        if (message.error)
            cb(null, message.error);
        else
            cb(message.result, null);
    }

    Process {
        id: proc
        running: true
        stdinEnabled: true
        command: ["python3", "-u", Paths.scriptsDir + "/store_service.py"]
        stdout: SplitParser {
            onRead: data => root.handleLine(data)
        }
        onStarted: {
            root.ready = true;
            if (root.outbox) {
                proc.write(root.outbox);
                root.outbox = "";
            }
        }
        onExited: {
            root.ready = false;
            for (const id of Object.keys(root.pending))
                root.pending[id](null, {
                    message: "Store service stopped"
                });
            root.pending = ({});
            root.installing = "";
        }
    }
}
