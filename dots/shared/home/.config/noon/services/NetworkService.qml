pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Networking
import qs.common
import qs.common.utils

Singleton {
    id: root

    // Kept for compatibility with existing call sites (NetworkService.manager.*).
    readonly property var manager: root

    readonly property var wifiDevice: _device(DeviceType.Wifi)
    readonly property var wiredDevice: _device(DeviceType.Wired)

    readonly property var activeWifiNetwork: {
        const dev = wifiDevice;
        if (dev === null || !dev.connected)
            return null;
        const list = dev.networks.values;
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].connected)
                return list[i];
        }
        return null;
    }

    readonly property var activeNetwork: {
        if (activeWifiNetwork !== null)
            return activeWifiNetwork;
        if (wiredDevice !== null && wiredDevice.hasLink && wiredDevice.network)
            return wiredDevice.network;
        return null;
    }

    readonly property bool wifiEnabled: Networking.wifiEnabled
    readonly property bool wifi: activeWifiNetwork !== null
    readonly property bool ethernet: wiredDevice !== null && wiredDevice.connected

    readonly property string wifiStatus: {
        const dev = wifiDevice;
        if (dev === null)
            return "disconnected";
        if (dev.connected)
            return "connected";
        if (dev.state === ConnectionState.Connecting || dev.state === ConnectionState.Disconnecting)
            return "connecting";
        return "disconnected";
    }

    readonly property string networkName: activeNetwork !== null ? activeNetwork.name : ""
    readonly property int networkStrength: activeWifiNetwork !== null ? Math.round(activeWifiNetwork.signalStrength * 100) : 0
    readonly property string networkStrengthText: networkStrength + "%"

    readonly property string materialSymbol: {
        if (ethernet)
            return "lan";
        if (!wifiEnabled)
            return "signal_wifi_off";
        if (wifiStatus === "connecting")
            return "signal_wifi_statusbar_not_connected";
        if (wifiStatus !== "connected")
            return "wifi_find";
        if (networkStrength < 25)
            return "signal_wifi_0_bar";
        if (networkStrength < 50)
            return "network_wifi_1_bar";
        if (networkStrength < 75)
            return "network_wifi_2_bar";
        if (networkStrength < 90)
            return "network_wifi_3_bar";
        return "signal_wifi_4_bar";
    }

    readonly property var wifiNetworks: {
        const dev = wifiDevice;
        if (dev === null)
            return [];
        const list = dev.networks.values;
        const active = activeWifiNetwork;
        const out = [];
        for (let i = 0; i < list.length; ++i) {
            const net = list[i];
            if (!net || !net.name)
                continue;
            const strength = Math.round(net.signalStrength * 100);
            const secured = net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Unknown;
            out.push({
                "ssid": net.name,
                "active": active !== null && active.name === net.name,
                "strength": strength,
                "strength_text": strength + "%",
                "security": secured ? "WPA" : "",
                "security_text": secured ? "Secured" : "Open",
                "saved": net.known
            });
        }
        out.sort((a, b) => (b.active - a.active) || (b.strength - a.strength));
        return out;
    }

    property int updateInterval: 1000

    property string ipAddress: "0.0.0.0"

    readonly property string downloadSpeedText: _fmtSpeed(_dl)
    readonly property string uploadSpeedText: _fmtSpeed(_ul)

    property real _dl: 0
    property real _ul: 0
    property string _statsIface: ""
    property real _lastRx: 0
    property real _lastTx: 0
    property bool _seeded: false
    property string _ipBuffer: ""

    function _device(type) {
        const list = Networking.devices.values;
        for (let i = 0; i < list.length; ++i) {
            if (list[i].type === type)
                return list[i];
        }
        return null;
    }

    function _ifaceName() {
        if (activeWifiNetwork !== null && wifiDevice !== null)
            return wifiDevice.name;
        if (wiredDevice !== null && wiredDevice.connected)
            return wiredDevice.name;
        return "";
    }

    function _resetStats() {
        root._statsIface = "";
        root._seeded = false;
        root._dl = 0;
        root._ul = 0;
        root._lastRx = 0;
        root._lastTx = 0;
    }

    function _parseNetDev(text, iface) {
        if (!text || !iface)
            return null;
        const lines = text.split("\n");
        for (let i = 2; i < lines.length; ++i) {
            const line = lines[i];
            const colon = line.indexOf(":");
            if (colon < 0)
                continue;
            if (line.slice(0, colon).trim() !== iface)
                continue;
            const cols = line.slice(colon + 1).trim().split(/\s+/);
            return {
                "rx": Number(cols[0]) || 0,
                "tx": Number(cols[8]) || 0
            };
        }
        return null;
    }

    function _sampleSpeed() {
        const iface = _ifaceName();
        if (!iface) {
            _resetStats();
            return;
        }
        const sample = _parseNetDev(netDev.text(), iface);
        if (!sample)
            return;
        if (_seeded && iface === _statsIface) {
            const seconds = Math.max(updateInterval, 1) / 1000;
            _dl = Math.max(0, sample.rx - _lastRx) / seconds;
            _ul = Math.max(0, sample.tx - _lastTx) / seconds;
        } else {
            _dl = 0;
            _ul = 0;
            _seeded = true;
        }
        _statsIface = iface;
        _lastRx = sample.rx;
        _lastTx = sample.tx;
    }

    function _fmtSpeed(bps) {
        const units = ["B/s", "KB/s", "MB/s", "GB/s"];
        let i = 0;
        while (bps >= 1024 && i < 3) {
            bps /= 1024;
            ++i;
        }
        return bps.toFixed(1) + " " + units[i];
    }

    function _wifiNetwork(ssid) {
        const dev = wifiDevice;
        if (dev === null)
            return null;
        const list = dev.networks.values;
        for (let i = 0; i < list.length; ++i) {
            if (list[i] && list[i].name === ssid)
                return list[i];
        }
        return null;
    }

    function toggleWifi() {
        Networking.wifiEnabled = !Networking.wifiEnabled;
    }

    function enableWifi(enabled) {
        Networking.wifiEnabled = enabled;
    }

    function rescanWifi() {
        if (wifiDevice !== null)
            wifiDevice.scannerEnabled = true;
        scanStop.restart();
    }

    function connectToWifiNetwork(ssid, password) {
        const net = _wifiNetwork(ssid);
        if (net === null)
            return;
        const secured = net.security !== WifiSecurityType.Open && net.security !== WifiSecurityType.Unknown;
        if (secured && password && password.length > 0)
            net.connectWithPsk(password);
        else
            net.connect();
    }

    function disconnectWifiNetwork() {
        if (activeWifiNetwork !== null)
            activeWifiNetwork.disconnect();
    }

    function forgetWifiNetwork(ssid) {
        const net = _wifiNetwork(ssid);
        if (net !== null)
            net.forget();
    }

    onWifiDeviceChanged: {
        if (wifiDevice !== null && wifiEnabled)
            wifiDevice.scannerEnabled = true;
    }

    onActiveNetworkChanged: {
        _resetStats();
        if (activeNetwork !== null && !ipProc.running)
            ipProc.running = true;
    }

    Timer {
        interval: root.updateInterval
        repeat: true
        running: root._ifaceName() !== ""
        onTriggered: netDev.reload()
    }

    Timer {
        id: scanStop
        interval: 8000
        repeat: false
        onTriggered: if (root.wifiDevice !== null)
            root.wifiDevice.scannerEnabled = false
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.wifiEnabled && root.wifiDevice !== null
        onTriggered: if (root.wifiDevice !== null && !root.wifiDevice.scannerEnabled)
            root.wifiDevice.scannerEnabled = true
    }

    Timer {
        interval: 15000
        repeat: true
        running: root.activeNetwork !== null
        onTriggered: if (!ipProc.running)
            ipProc.running = true
    }

    FileView {
        id: netDev

        path: "/proc/net/dev"
        preload: true
        printErrors: false

        onLoaded: root._sampleSpeed()
    }

    Process {
        id: ipProc

        command: ["ip", "-4", "-o", "addr", "show", "scope", "global"]

        stdout: SplitParser {
            onRead: line => {
                root._ipBuffer += line + "\n";
            }
        }

        onStarted: root._ipBuffer = ""

        onExited: {
            const match = root._ipBuffer.match(/\binet\s+(\d+\.\d+\.\d+\.\d+)\//);
            root.ipAddress = match ? match[1] : "0.0.0.0";
            root._ipBuffer = "";
        }
    }
}
