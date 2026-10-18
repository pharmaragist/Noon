pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs.common
import qs.common.utils

Singleton {
    id: engine

    readonly property string runtimeDir: {
        const d = Quickshell.env("XDG_RUNTIME_DIR");
        return (d && d.length > 0) ? d : "/run/user/1000";
    }
    readonly property string socketPath: runtimeDir + "/EasyEffectsServer"
    readonly property string plugin: "equalizer"

    property bool connected: false
    property bool ready: false
    property string lastError: ""

    property int numBands: 10
    property real preamp: 0
    property real outputGain: 0
    property int mode: 0
    property bool splitChannels: false
    property bool enabled: true
    property bool globalBypassed: false
    property var bands: []
    property int selectedBand: 0

    property bool interacting: false

    signal refreshed

    readonly property string state: !connected ? "unavailable" : (ready ? "ready" : "loading")
    readonly property bool engineAvailable: connected
    readonly property var profiles: ({
            "Base": [4.0, 2.5, 0.5, -2.0, -2.0, 2.0, 3.5, 5.0, 6.5, 7.5],
            "Treble": [0.0, 0.0, 0.0, 0.0, -1.0, 0.0, 2.0, 5.0, 7.5, 9.0],
            "Punchy Base": [8.5, 7.0, 4.0, 0.0, -1.0, -1.5, 0.0, 0.0, 0.0, 0.0],
            "Bass & Treble": [7.5, 6.5, 3.5, -1.5, -3.0, -2.5, 2.0, 5.0, 7.0, 8.5],
            "Classical": [6.0, 4.5, 2.5, 1.0, -2.5, -2.5, 0.0, 4.0, 5.5, 6.5],
            "Dance": [2.0, 9.0, 7.5, 2.5, -1.0, -4.5, -6.0, -5.5, 2.0, 3.5],
            "Rock": [6.5, 5.5, -3.0, -6.0, -2.0, 3.5, 6.0, 7.5, 7.5, 8.0],
            "Vocals": [-2.0, -1.0, 0.0, -3.0, -4.0, 4.5, 5.5, 4.5, 2.0, 2.0]
        })

    // User-saved presets (AutoEq and friends). Unlike the quick-start `profiles`
    // above these carry full (type, frequency, gain, Q) bands, so they can
    // reproduce parametric corrections and aren't limited to gain shaping.
    readonly property var customPresets: customFile.data?.presets ?? []

    property bool _dirty: false
    property bool _wantBypass: false
    property var _pending: []
    property var _queue: []
    property double _lastSendAt: 0

    onInteractingChanged: {
        if (!interacting)
            settleTimer.restart();
    }

    Timer {
        id: settleTimer
        interval: 600
    }

    Socket {
        id: sock
        path: engine.socketPath

        parser: SplitParser {
            onRead: line => engine._onLine(line)
        }

        onError: e => {
            engine.lastError = "" + e;
        }

        onConnectionStateChanged: engine._onConnectionChanged()
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (!sock.connected)
                sock.connected = true;
        }
    }

    Socket {
        id: bypassSock
        path: engine.socketPath

        parser: SplitParser {
            splitMarker: ""
            onRead: chunk => engine._onBypassChunk(chunk)
        }

        onConnectionStateChanged: {
            if (bypassSock.connected && engine._wantBypass) {
                bypassSock.write("get_global_bypass\n");
                bypassSock.flush();
            }
        }
    }

    Timer {
        interval: 1500
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: {
            if (engine._wantBypass && !bypassSock.connected)
                bypassSock.connected = true;
        }
    }

    Timer {
        interval: 2000
        running: engine.connected && engine.ready && !engine.interacting && !settleTimer.running
        repeat: true
        onTriggered: engine.refresh()
    }

    function init() {
        NoonUtils.execDetached(["easyeffects", " --gapplication-service"]);
    }

    function _send(cmd) {
        if (!sock.connected) {
            _pending.push(cmd);
            return;
        }
        sock.write(cmd + "\n");
        sock.flush();
    }

    function _flushPending() {
        if (!sock.connected || _pending.length === 0)
            return;
        const p = _pending;
        _pending = [];
        for (let i = 0; i < p.length; i++)
            sock.write(p[i] + "\n");
        sock.flush();
    }

    function _onLine(line) {
        const cb = _queue.shift();
        if (cb)
            cb("" + line);
    }

    function _get(prop, channel, cb) {
        const cmd = "get_property:output:" + plugin + ":0:" + (channel ? channel + ":" : "") + prop;
        _queue.push(cb || null);
        _lastSendAt = Date.now();
        _send(cmd);
    }

    function _fmt(v) {
        if (typeof v === "boolean")
            return v ? "true" : "false";
        if (typeof v === "number") {
            if (Math.abs(v - Math.round(v)) < 1e-9)
                return "" + Math.round(v);
            return "" + (Math.round(v * 1000) / 1000);
        }
        return "" + v;
    }

    function _setProp(prop, value, channel) {
        _send("set_property:output:" + plugin + ":0:" + (channel ? channel + ":" : "") + prop + ":" + _fmt(value));
    }

    function _num(v, fallback) {
        const n = parseFloat(v);
        return isFinite(n) ? n : fallback;
    }

    function _mutBand(i, key, value) {
        const b = engine.bands;
        if (!b || i < 0 || i >= b.length)
            return false;
        if (b[i][key] === value)
            return false;
        const next = Object.assign({}, b[i]);
        next[key] = value;
        b[i] = next;
        _dirty = true;
        return true;
    }

    function _commitBands() {
        if (!_dirty)
            return;
        _dirty = false;
        engine.bands = engine.bands.slice();
    }

    function refresh() {
        if (!sock.connected)
            return;
        if (_queue.length > 0) {
            if (Date.now() - _lastSendAt < 4000)
                return;
            _queue = [];
        }
        _get("numBands", "", function (v) {
            let n = parseInt(v, 10);
            if (!(n > 0))
                n = 10;
            engine.numBands = n;
            engine._readState(n);
        });
    }

    function _readState(n) {
        _get("inputGain", "", function (v) {
            const x = engine._num(v, 0);
            if (engine.preamp !== x)
                engine.preamp = x;
        });
        _get("outputGain", "", function (v) {
            const x = engine._num(v, 0);
            if (engine.outputGain !== x)
                engine.outputGain = x;
        });
        _get("mode", "", function (v) {
            const x = parseInt(v, 10) || 0;
            if (engine.mode !== x)
                engine.mode = x;
        });
        _get("splitChannels", "", function (v) {
            const x = (v === "true");
            if (engine.splitChannels !== x)
                engine.splitChannels = x;
        });

        const cur = engine.bands;
        if (!cur || cur.length !== n) {
            const arr = [];
            for (let i = 0; i < n; i++)
                arr.push((cur && cur[i]) ? cur[i] : {
                    type: 1,
                    freq: 1000,
                    gain: 0,
                    q: 1.0,
                    mode: 0,
                    mute: false
                });
            engine.bands = arr;
        }

        for (let i = 0; i < n; i++)
            _readBand(i);

        _get("bypass", "", function (v) {
            const x = (v !== "true");
            if (engine.enabled !== x)
                engine.enabled = x;
            if (engine.selectedBand >= engine.numBands)
                engine.selectedBand = 0;
            engine._commitBands();
            const first = !engine.ready;
            engine.ready = true;
            if (first || engine._dirty === false)
                engine.refreshed();
        });
    }

    function _readBand(i) {
        _get("band" + i + "Type", "left", function (v) {
            engine._mutBand(i, "type", parseInt(v, 10) || 0);
        });
        _get("band" + i + "Frequency", "left", function (v) {
            engine._mutBand(i, "freq", engine._num(v, 1000));
        });
        _get("band" + i + "Gain", "left", function (v) {
            engine._mutBand(i, "gain", engine._num(v, 0));
        });
        _get("band" + i + "Q", "left", function (v) {
            engine._mutBand(i, "q", engine._num(v, 1));
        });
        _get("band" + i + "Mute", "left", function (v) {
            engine._mutBand(i, "mute", v === "true");
        });
        _get("band" + i + "Mode", "left", function (v) {
            engine._mutBand(i, "mode", parseInt(v, 10) || 0);
        });
    }

    function setPreamp(v) {
        preamp = v;
        _setProp("inputGain", v);
    }

    function setEnabled(v) {
        enabled = v;
        _setProp("bypass", !v);
    }

    function setNumBands(n) {
        numBands = n;
        _setProp("numBands", n);
    }

    function setBand(i, key, value) {
        _mutBand(i, key, value);
        _commitBands();
        const prop = ({
                type: "Type",
                freq: "Frequency",
                gain: "Gain",
                q: "Q",
                mode: "Mode",
                mute: "Mute"
            })[key];
        if (!prop)
            return;
        const name = "band" + i + prop;
        _setProp(name, value, "left");
        if (splitChannels)
            _setProp(name, value, "right");
    }

    function toggleBandMute(i) {
        const b = bands[i];
        if (b)
            setBand(i, "mute", !b.mute);
    }

    // --- Custom presets -----------------------------------------------------
    // A custom preset is {name, preamp, source, bands: [{type, freq, gain, q}]}
    // where `type` is an EasyEffects/LSP band type index (1 Bell, 3 Hi-shelf,
    // 5 Lo-shelf — see common/functions/Eq.js).

    function isCustomPreset(name) {
        return customPresets.some(p => p.name === name);
    }

    function getCustomPreset(name) {
        return customPresets.find(p => p.name === name) || null;
    }

    // Quick-start keys first, then saved presets, in one flat list.
    function presetNames() {
        return Object.keys(profiles).concat(customPresets.map(p => p.name));
    }

    function saveCustomPreset(name, preset) {
        if (!name)
            return;
        const next = customPresets.filter(p => p.name !== name);
        next.push({
            name: name,
            preamp: preset?.preamp ?? 0,
            source: preset?.source ?? "",
            bands: preset?.bands ?? []
        });
        customFile.data.presets = next;
    }

    function deleteCustomPreset(name) {
        customFile.data.presets = customPresets.filter(p => p.name !== name);
    }

    // Writes full band geometry, not just gains, so parametric corrections
    // survive. Bands are sorted ascending by filter count from the source.
    // Takes the preset object directly so callers never race the persistence
    // round-trip.
    function applyPresetObject(preset) {
        if (!preset || !preset.bands || preset.bands.length === 0)
            return false;

        const src = preset.bands.slice(0, 32);
        const arr = [];
        setNumBands(src.length);
        setPreamp(Math.round((preset.preamp ?? 0) * 10) / 10);
        for (let i = 0; i < src.length; i++) {
            const b = src[i];
            const type = b.type ?? 1;
            const freq = b.freq ?? 1000;
            const gain = b.gain ?? 0;
            const q = b.q ?? 0.707;
            arr.push({
                type: type,
                freq: freq,
                gain: gain,
                q: q,
                mode: 6,
                mute: false
            });
            setBand(i, "type", type);
            setBand(i, "freq", freq);
            setBand(i, "q", q);
            // APO (DR) is the mode EasyEffects itself uses to import
            // EqualizerAPO/AutoEq biquads, so shelf Q behaves as designed.
            setBand(i, "mode", 6);
            setBand(i, "gain", gain);
        }
        numBands = arr.length;
        bands = arr;
        return true;
    }

    function applyCustomPreset(name) {
        return applyPresetObject(getCustomPreset(name));
    }

    function resetAll() {
        for (let i = 0; i < bands.length; i++)
            setBand(i, "gain", 0);
        setPreamp(0);
    }

    function autoPreamp() {
        let sum = 0;
        for (let i = 0; i < bands.length; i++) {
            const b = bands[i];
            if (b && !b.mute && b.type > 0 && b.gain > 0)
                sum += b.gain;
        }
        setPreamp(Math.max(-36, Math.round(-sum * 10) / 10));
    }

    function _onBypassChunk(chunk) {
        const c = ("" + chunk).trim();
        if (c === "1")
            globalBypassed = true;
        else if (c === "2")
            globalBypassed = false;
    }

    function queryGlobalBypass() {
        _wantBypass = true;
        if (!bypassSock.connected) {
            bypassSock.connected = true;
            return;
        }
        bypassSock.write("get_global_bypass\n");
        bypassSock.flush();
    }

    function setGlobalBypassed(v) {
        globalBypassed = v;
        _send("global_bypass:" + (v ? "1" : "0"));
    }

    function startEngine() {
        NoonUtils.execDetached(["easyeffects", "--service-mode"]);
    }

    function stopEngine() {
        NoonUtils.execDetached(["pkill", "easyeffects"]);
    }

    function _onConnectionChanged() {
        const c = sock.connected;
        if (c === engine.connected)
            return;
        engine.connected = c;
        engine.ready = false;
        _queue = [];

        if (c) {
            _flushPending();
            refresh();
            queryGlobalBypass();
        }
    }

    PluginFileView {
        id: customFile
        fileName: "eq_presets"

        JsonAdapter {
            property list<var> presets: []
        }
    }

    Component.onCompleted: {
        sock.connected = true;
        queryGlobalBypass();
    }
}
