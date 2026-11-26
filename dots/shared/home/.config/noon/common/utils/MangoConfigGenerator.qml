import QtQuick
import Quickshell
import Quickshell.Io
import qs.common

/*
Injects Mem.wm values as plain TOML. Sourced before binds and last so both
variables and visual overrides win.
*/

QtObject {
    id: root

    readonly property string filePath: Paths.standard.config + "/mango/variables.toml"
    readonly property var store: Mem.wm
    readonly property string ipc: store.ipc || Paths.shellDir + "/scripts/bin/npc call"
    property string lastWritten: ""

    readonly property string text: `
# Generated from Mem.wm. Sourced before binds and last so these values win.

[var]
term = '${store.terminal}'
term_alt = '${store.terminal_alt}'
editor = '${store.editor}'
files = '${store.file_manager}'
browser = '${store.browser}'
browser_alt = '${store.browser_alt}'
shell_dir = '${Paths.shellDir}'
scripts = '${Paths.shellDir}/scripts'
ipc = '${ipc}'

[env]
TERMINAL = '${store.terminal}'
BROWSER = '${store.browser}'
EDITOR = '${store.editor}'
FILE_MANAGER = '${store.file_manager}'

[global]
gap_inner_horizontal = ${store.gaps_in}
gap_inner_vertical = ${store.gaps_in}
gap_outer_horizontal = ${store.gaps_out}
gap_outer_vertical = ${store.gaps_out}
border_px = ${store.borders}
border_radius = ${store.rounding}
focused_opacity = ${store.applications_opacity}
unfocused_opacity = ${store.applications_opacity}
shadows = ${store.shadows ? 1 : 0}
layer_shadows = ${store.shadows ? 1 : 0}
shadows_size = ${store.shadows_range}
shadows_blur = ${store.shadows_power}
blur = ${store.blur ? 1 : 0}
blur_layer = ${store.blur ? 1 : 0}
blur_optimized = ${store.new_optimizations ? 1 : 0}
blur_params_num_passes = ${store.blur_passes}
blur_params_radius = ${store.blur_size}
blur_params_noise = ${(store.noise / 100)}
zoom_initial_ratio = ${store.animation_scale}
zoom_end_ratio = ${store.animation_scale}
cursor_theme = '${store.cursor_theme}'
cursor_size = ${store.cursor_size}
allow_tearing = ${store.allow_tearing ? 1 : 0}
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
            console.warn("MangoConfigGenerator: failed to write", root.filePath, error);
        }
    }
}
