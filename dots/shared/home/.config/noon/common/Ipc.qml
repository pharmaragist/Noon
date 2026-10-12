pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common

// Local-first IPC router. NpcHandler registers each target here on
// creation, so Ipc.call reaches any handler in-process: no socket, no spawn.
// Targets owned by another instance (or not loaded) fall back to npc.
Singleton {
    property var targets: ({})
    // Bumped on every (un)registration so `commands` re-evals instead of caching.
    property int epoch: 0

    function register(target, obj) {
        if (target && obj) {
            targets[target] = obj;
            epoch++;
        }
    }

    function unregister(target, obj) {
        if (targets[target] === obj) {
            delete targets[target];
            epoch++;
        }
    }

    // Live command list, rebuilt from the registry on every membership change.
    // Never cached, never shelled out for.
    readonly property var commands: buildCommands(epoch)

    // Base-class slots that enumerate as functions but are not IPC commands.
    readonly property var ipcBuiltins: ["onSignalTriggered", "postReload", "destroy", "deleteLater", "toString", "destroyed", "parentChanged"]

    function buildCommands() {
        const out = [];
        for (const target in targets) {
            const obj = targets[target];
            for (const name in obj) {
                if (name.endsWith("Changed"))
                    continue;
                if (ipcBuiltins.indexOf(name) !== -1)
                    continue;
                if (typeof obj[name] !== "function")
                    continue;
                out.push(target + " " + name);
            }
        }
        out.sort();
        return out;
    }

    // Quote-aware split: sidebar reveal 'foo bar' -> 3 parts, quotes stripped.
    function split(request) {
        const out = [];
        let cur = "", quote = "";
        for (const ch of request) {
            if (quote) {
                if (ch === quote)
                    quote = "";
                else
                    cur += ch;
            } else if (ch === '"' || ch === "'") {
                quote = ch;
            } else if (ch === " " || ch === "\t") {
                if (cur) {
                    out.push(cur);
                    cur = "";
                }
            } else {
                cur += ch;
            }
        }
        if (cur)
            out.push(cur);
        return out;
    }

    function call(parts) {
        if (!parts || parts.length < 2)
            return;
        const target = parts[0], fn = parts[1];
        const obj = targets[target];
        if (obj && typeof obj[fn] === "function") {
            obj[fn].apply(obj, parts.slice(2));
            return;
        }

        // it with real argv, no shell round-trip, no quoting games.
        Quickshell.execDetached([(Paths.scriptsDir + "/npc"), "call", ...parts.map(String)]);
    }
}
