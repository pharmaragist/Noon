pragma Singleton
pragma ComponentBehavior: Bound
import qs.common
import Quickshell
import Quickshell.Services.UPower
import QtQuick

Singleton {
    id: root
    readonly property bool available: UPower.displayDevice.isLaptopBattery
    readonly property var chargeState: UPower.displayDevice.state
    readonly property bool conservativeMode:!(!available || isPluggedIn || !Mem.options.battery.autoConservativeMode)
    readonly property bool isCharging: chargeState === UPowerDeviceState.Charging
    readonly property bool isPluggedIn: isCharging || chargeState == UPowerDeviceState.PendingCharge
    readonly property real percentage: UPower.displayDevice?.percentage ?? 1
    readonly property bool allowAutomaticSuspend: Mem.options.battery.automaticSuspend
    readonly property bool isLow: available && (percentage <= Mem.options.battery.low / 100)
    readonly property bool isCritical: available && (percentage <= Mem.options.battery.critical / 100)
    readonly property bool isSuspending: available && (percentage <= Mem.options.battery.suspend / 100)

    readonly property bool isLowAndNotCharging: isLow && !isCharging
    readonly property bool isCriticalAndNotCharging: isCritical && !isCharging
    readonly property bool isSuspendingAndNotCharging: allowAutomaticSuspend && isSuspending && !isCharging

    readonly property real energyRate: UPower.displayDevice.changeRate
    readonly property real energy: UPower.displayDevice.energy
    readonly property real energyCapacity: UPower.displayDevice.energyCapacity
    readonly property string model: UPower.displayDevice.model
    readonly property real timeToEmpty: UPower.displayDevice.timeToEmpty
    readonly property real timeToFull: UPower.displayDevice.timeToFull
    readonly property bool useLegacyBatteryIcons: Mem.options.bar.statusIcons?.useLegacyBatteryIcons ?? false
    readonly property string materialIcon: {
        if (!root.available || root.isPluggedIn)
            return useLegacyBatteryIcons ? "electric_bolt" : "battery_android_bolt";

        const p = root.percentage * 100;
        const prefix = useLegacyBatteryIcons ? "battery_" : "battery_android_";
        const suffix = useLegacyBatteryIcons ? "_bar" : "";

        if (p <= 2)
            return `${prefix}alert`;

        let level = 0;
        if (p > 5)   level = 1;
        if (p > 14)  level = 2;
        if (p > 28)  level = 3;
        if (p > 42)  level = 4;
        if (p > 56)  level = 5;
        if (p > 70)  level = 6;

        if (p > 95)
            return useLegacyBatteryIcons ? (root.isPluggedIn ? "battery_charging_full" : "battery_full") : "battery_android_full";

        return `${prefix}${level}${suffix}`;
    }

    Connections {
        target: PowerProfiles
        function onDegradationReasonChanged() {
            const reason = PowerProfiles.degradationReason;
            if (reason === PerformanceDegradationReason.HighTemperature)
                NoonUtils.toast({
                    id: 3,
                    content: "High Temperature",
                    icon: "emergency_heat",
                    status: "warn"
                });
            if (reason === PerformanceDegradationReason.LapDetected)
                NoonUtils.toast({
                    id: 3,
                    content: "Move the laptop away from your body",
                    icon: "heat",
                    status: "warn"
                });
        }
    }

    onIsLowAndNotCharging: if (isLowAndNotCharging)
        NoonUtils.playSound("power_low")
    onIsChargingChanged: if (isCharging) {
        NoonUtils.playSound("power_plugged");
        NoonUtils.toast({
            id: 3,
            content: "Charging",
            icon: "battery_charging_full",
            status: "success"
        });
    } else {
        NoonUtils.playSound("power_unplugged");
        NoonUtils.toast({
            id: 3,
            content: "Discharging",
            icon: "battery_error"
        });
    }
    onIsLowAndNotChargingChanged: {
        if (available && isLowAndNotCharging)
            NoonUtils.toast({
                id: 3,
                content: "Low Battery Plug in your device",
                icon: "battery_error",
                status: "warn"
            });
    }

    onIsCriticalAndNotChargingChanged: {
        if (available && isCriticalAndNotCharging)
            NoonUtils.toast({
                id: 3,
                content: "Critical Battery Percentage",
                icon: "battery_error",
                status: "error"
            });
    }

    onIsSuspendingAndNotChargingChanged: {
        if (available && isSuspendingAndNotCharging) {
            NoonUtils.execDetached(`systemctl suspend`);
        }
    }
    // property var _conservativeSnapshot
    // readonly property var conservativeOptions: [
    //     {
    //         target: Mem.options.appearance.transparency,
    //         prop: "enabled"
    //     },
    //     {
    //         target: Mem.hypr,
    //         prop: "blur"
    //     },
    //     {
    //         target: Mem.hypr,
    //         prop: "unblur_apps",
    //         off: true_conservativeSnapshot
    //     }
    // ]
    // onConservativeModeChanged: {
    //     if (root.conservativeMode) {
    //         root._conservativeSnapshot = root.conservativeOptions.map(o => o.target[o.prop]);
    //         root.conservativeOptions.forEach(o => o.target[o.prop] = o.off || false);
    //     } else if (root._conservativeSnapshot) {
    //         root.conservativeOptions.forEach((o, i) => o.target[o.prop] = root._conservativeSnapshot[i]);
    //         root._conservativeSnapshot = null;
    //     }
    // }
}
