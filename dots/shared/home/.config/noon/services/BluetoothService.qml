pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import org.kde.bluezqt as BluezQt
import qs.common

Singleton {
    id: root

    readonly property BluetoothAdapter adapter: Bluetooth.defaultAdapter
    readonly property bool available: adapter !== null
    readonly property bool enabled: adapter ? adapter.enabled : false
    readonly property bool discovering: adapter ? adapter.discovering : false
    readonly property var allDevices: adapter ? [...adapter.devices.values] : []
    readonly property bool bluetoothEnabled: enabled
    readonly property bool bluetoothConnected: connectedDevices.length > 0
    readonly property string currentDeviceIcon: if (filterConnectedDevices(pairedDevices).length > 0)
        return getDeviceIcon(filterConnectedDevices(pairedDevices)[0])
    else if (connectedDevices.length > 0)
        return "bluetooth_connected"
    else if (enabled)
        return "bluetooth"
    else
        "bluetooth_disabled"

    readonly property var pairedDevices: {
        if (!adapter || !adapter.devices)
            return [];
        return adapter.devices.values.filter(dev => dev && (dev.paired || dev.trusted) && dev.name && dev.name.trim() !== dev.address);
    }

    readonly property var connectedDevices: {
        if (!adapter || !adapter.devices)
            return [];
        return adapter.devices.values.filter(dev => dev && dev.connected && dev.name && dev.name.trim() !== dev.address);
    }

    function startDiscovery() {
        if (adapter && enabled)
            adapter.discovering = true;
    }

    function stopDiscovery() {
        if (adapter)
            adapter.discovering = false;
    }

    function togglePower() {
        if (adapter)
            adapter.enabled = !adapter.enabled;
    }

    readonly property var _iconTerms: {
        "headphone": {
            symbolic: "audio-headphones-symbolic",
            material: "earbuds_2"
        },
        "airpod": {
            symbolic: "audio-headphones-symbolic",
            material: "earbuds_2"
        },
        "arctis": {
            symbolic: "audio-headphones-symbolic",
            material: "earbuds_2"
        },
        "buds": {
            symbolic: "audio-headphones-symbolic",
            material: "earbuds_2"
        },
        "pods": {
            symbolic: "audio-headphones-symbolic",
            material: "earbuds_2"
        },
        "headset": {
            symbolic: "audio-headset-symbolic",
            material: "headset"
        },
        "audio": {
            symbolic: "audio-headset-symbolic",
            material: "headset"
        },
        "mic": {
            symbolic: "audio-headset-symbolic",
            material: "headset"
        },
        "mouse": {
            symbolic: "input-mouse-symbolic",
            material: "mouse"
        },
        "keyboard": {
            symbolic: "input-keyboard-symbolic",
            material: "keyboard"
        },
        "phone": {
            symbolic: "phone-smart-symbolic",
            material: "smartphone"
        },
        "iphone": {
            symbolic: "phone-smart-symbolic",
            material: "smartphone"
        },
        "android": {
            symbolic: "phone-smart-symbolic",
            material: "smartphone"
        },
        "samsung": {
            symbolic: "phone-smart-symbolic",
            material: "smartphone"
        },
        "watch": {
            symbolic: "smartwatch-symbolic",
            material: "watch"
        },
        "speaker": {
            symbolic: "audio-speakers-symbolic",
            material: "speaker"
        },
        "display": {
            symbolic: "video-display-symbolic",
            material: "tv"
        },
        "tv": {
            symbolic: "video-display-symbolic",
            material: "tv"
        }
    }

    function _findIconEntry(device) {
        if (!device)
            return null;
        var search = (device.name + " " + (device.alias || "") + " " + (device.deviceName || "") + " " + (device.icon || "")).toLowerCase();
        for (var term in _iconTerms) {
            if (search.indexOf(term) !== -1)
                return _iconTerms[term];
        }
        return null;
    }

    function getLinuxSymbolicIcon(device) {
        if (!root.enabled)
            return "bluetooth-disabled-symbolic";
        if (!device)
            return "bluetooth-active-symbolic";
        var e = _findIconEntry(device);
        return e ? e.symbolic : "bluetooth-paired-symbolic";
    }

    function getDeviceIcon(device) {
        if (!device)
            return "bluetooth";
        var e = _findIconEntry(device);
        return e ? e.material : "bluetooth";
    }

    function getDeviceStatusIcon(device) {
        if (!device)
            return "";
        if (isDeviceBusy(device))
            return "cached";
        if (device.connected)
            return "Bluetooth_connected";
        if (device.paired)
            return "link";
        if (device.trusted)
            return "shield_with_heart";
        return "restart_alt";
    }

    function getDeviceStatus(device) {
        if (!device)
            return " ";
        if (isDeviceBusy(device))
            return "Busy";
        if (device.connected)
            return "Connected";
        if (device.paired)
            return "Paired";
        if (device.trusted)
            return "Trusted";
        return "Available";
    }

    function isDeviceBusy(device) {
        if (!device)
            return false;
        return device.pairing || device.connecting;
    }

    function filterConnectedDevices(devices) {
        if (!devices)
            return [];
        return devices.filter(dev => dev && dev.connected);
    }

    
    property var _ignored: ({})
    property var _popupDevice: null

    function _isAudio(d) {
        if (!d || !d.name)
            return false;
        var n = d.name.toLowerCase();
        return /head|buds|ear|air|mic|audio|speaker|handsfree/.test(n) && !/keyboard|mouse|ble|BLE/.test(n);
    }

    function _showPopup(d) {
        if (!d || d.paired || !_isAudio(d) || _popupDevice || _ignored[d.address] || bluetoothConnected)
            return;
        _popupDevice = d;
        NoonUtils.requestDialog("ble", {
            acceptText: "Connect",
            device: d,
            onAccepted: () => {
                if (!d.connected)
                    d.connectToDevice();
                _popupDevice = null;
            },
            onDismiss: () => {
                _ignored[d.address] = true;
                _popupDevice = null;
            }
        });
    }

    Connections {
        target: Globals.main.sysDialogs
        function onModeChanged() {
            if (Globals.main.sysDialogs.mode !== "ble" && _popupDevice) {
                _ignored[_popupDevice.address] = true;
                _popupDevice = null;
            }
        }
    }

    onBluetoothConnectedChanged: {
        if (bluetoothConnected && adapter && adapter.discovering)
            adapter.discovering = false;
    }

    Timer {
        interval: 1000
        repeat: true
        running: true
        onTriggered: if (adapter && enabled && !adapter.discovering && !bluetoothConnected)
            adapter.discovering = true
    }

    Connections {
        target: BluezQt.Manager
        function onDeviceAdded(d) {
            _showPopup(d);
        }
        function onDeviceChanged(d) {
            _showPopup(d);
        }
        function onUsableAdapterChanged() {
            if (adapter && enabled && !adapter.discovering && !bluetoothConnected)
                adapter.discovering = true;
        }
    }
}
