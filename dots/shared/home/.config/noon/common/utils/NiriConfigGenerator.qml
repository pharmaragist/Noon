import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

/*
Injects Mem.wm values as plain KDL. Included last so these values win.
*/

QtObject {
    id: root

    readonly property string filePath: Paths.standard.config + "/niri/variables.kdl"
    readonly property var store: Mem.wm
    property string lastWritten: ""

    readonly property string text: `
layout {
    gaps ${store.gaps_out}

    border {
        ${store.borders > 0 ? "on" : "off"}
        width ${store.borders}
    }

    shadow {
        ${store.shadows ? "on" : "off"}
        softness ${store.shadows_range}
        spread ${store.shadows_power}
        offset x=0 y=5
    }
}

cursor {
    xcursor-theme "${store.cursor_theme}"
    xcursor-size ${store.cursor_size}
    hide-when-typing
    hide-after-inactive-ms 3000
}

overview {
    zoom ${store.animation_scale}

    workspace-shadow {
        ${store.shadows ? "on" : "off"}
        softness ${store.shadows_range}
        spread ${store.shadows_power}
        offset x=0 y=10
        color "#00000050"
    }
}

blur {
    ${store.blur ? "on" : "off"}
    passes ${store.blur_passes}
    offset ${store.blur_size}
    noise ${(store.noise / 100)}
}

binds {
    Super+T { spawn-sh r#"${store.terminal}"#; }
    Super+C { spawn-sh r#"${store.editor} ${Paths.shellDir}"#; }
    Super+Return { spawn-sh r#"${store.terminal_alt}"#; }
    Super+E { spawn-sh r#"${store.file_manager}"#; }
    Super+B { spawn-sh r#"${store.browser}"#; }
    Super+Shift+B { spawn-sh r#"${store.browser_alt}"#; }
    Ctrl+Shift+Escape {
        spawn-sh r#"${Paths.shellDir}/scripts/bin/npc call ${store.task_manager}"#;
    }
    Ctrl+Super+Shift+Escape { spawn-sh r#"${store.task_manager_alt}"#; }
}

window-rule {
    match app-id="^.*"
    geometry-corner-radius ${store.rounding}
    clip-to-geometry true
    background-effect {
        blur ${store.blur}
        noise ${store.noise}
        xray ${store.xray}
    }
}
`

    function write() {
        if (!mirrorFile || !mirrorFile.path || root.lastWritten === root.text)
            return;
        root.lastWritten = root.text;
        mirrorFile.setText(root.text);
    }

    Component.onCompleted: mirrorFile.reload()
    onTextChanged: root.write()
    onStoreChanged: root.write()

    readonly property FileView mirrorFile: FileView {
        path: root.filePath
        watchChanges: false
        printErrors: true

        onLoaded: {
            root.lastWritten = mirrorFile.text();
            root.write();
        }

        onLoadFailed: error => {
            if (error === FileViewError.FileNotFound)
                root.write();
        }

        onSaveFailed: error => {
            root.lastWritten = "";
            console.warn("NiriConfigGenerator: failed to write", root.filePath, error);
        }
    }
}
