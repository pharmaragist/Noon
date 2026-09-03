pragma Singleton
import QtQuick
import Quickshell
import qs.common

Singleton {
    readonly property var opts: Mem.options.desktop.branding.distroInfo
    readonly property string distroName: opts?.name
    readonly property string distroId: opts?.id
    readonly property string distroIcon: opts?.icon ?? "arch-symbolic"
    readonly property string username: Quickshell.env("USER")
    readonly property string userPfp: Paths.standard.home + "/.face"
    readonly property var distroIcons: ({
            arch: "arch-symbolic",
            endeavouros: "endeavouros-symbolic",
            cachyos: "cachyos-symbolic",
            nixos: "nixos-symbolic",
            fedora: "fedora-symbolic",
            linuxmint: "ubuntu-symbolic",
            ubuntu: "ubuntu-symbolic",
            zorin: "ubuntu-symbolic",
            popos: "ubuntu-symbolic",
            debian: "debian-symbolic",
            raspbian: "debian-symbolic",
            kali: "debian-symbolic"
        })

    Component.onCompleted: {
        if (distroId.toLowerCase() !== "unknown")
            return;

        const text = Paths.methods.readFile("/etc/os-release");
        if (!text) return;

        const prettyNameMatch = text.match(/^PRETTY_NAME="(.+?)"/m);
        const nameMatch = text.match(/^NAME="(.+?)"/m);

        const idMatch = text.match(/^ID=(.+)$/m);
        const id = idMatch ? idMatch[1].trim().replace(/"/g, "") : "unknown";

        opts.name = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown");
        opts.id = id;
        opts.icon = distroIcons[id] ?? "arch-symbolic";
    }
}
