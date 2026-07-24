pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common
import qs.common.utils

Singleton {
    property string distroName: "Unknown"
    property string distroId: "unknown"
    property string distroIcon: "arch-symbolic"
    property string username: "user"
    property string userPfp: Directories.standard.home + "/.face"

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

    readonly property FileView osView: FileView {
        path: "/etc/os-release"
        onTextChanged: {
            const text = osView.text();
            if (!text)
                return;

            const prettyNameMatch = text.match(/^PRETTY_NAME="(.+?)"/m);
            const nameMatch = text.match(/^NAME="(.+?)"/m);
            distroName = prettyNameMatch ? prettyNameMatch[1] : (nameMatch ? nameMatch[1].replace(/Linux/i, "").trim() : "Unknown");

            const idMatch = text.match(/^ID=(.+)$/m);
            const id = idMatch ? idMatch[1].trim().replace(/"/g, "") : "unknown";
            distroId = id;
            distroIcon = distroIcons[id] ?? "arch-symbolic";

            usernameProc.running = true;
        }
    }

    readonly property Process usernameProc: Process {
        command: ["whoami"]
        stdout: SplitParser {
            onRead: data => username = data.trim()
        }
    }
}
