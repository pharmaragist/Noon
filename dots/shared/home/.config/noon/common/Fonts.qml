pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.store
import qs.common
import qs.common.utils
import qs.common.functions

Singleton {
    id: root

    property QtObject methods: TextUtils
    readonly property var family: fontsView.data.family
    readonly property var sizes: fontsView.data.sizes

    function request(name, size, props = {}) {
        if (!name || !size)
            return;
        const _size = typeof size === "string" ? Fonts.sizes[size] : size;
        const presets = fontsView.data.presets;
        const final = Object.assign({}, presets[name], {
            "pixelSize": parseInt(_size)
        }, props);
        return Qt.font(final);
    }

    function getStretch(horizontal = 0.6, vertical = 1) {
        return [
            {
                "type": "scale",
                "xScale": horizontal,
                "yScale": vertical
            }
        ];
    }

    function pickGlobalFont() {
        fontDialog.open();
    }

    function changeSystemFont(fontVar) {
        Quickshell.execDetached([Paths.scriptsDir + "/sync_sys_fonts.sh", "--family", fontVar.family, "--size", 10]);
        Mem.hypr.font_main = fontVar.family;
        Mem.options.appearance.fonts.main = fontVar.family;
    }

    FontDialog {
        id: fontDialog
        onSelectedFontChanged: Fonts.changeSystemFont(fontDialog.selectedFont)
    }

    ConfigFileView {
        id: fontsView
        state: false
        parentDir: "user/"
        fileName: "fonts"
        FontsSchema {}
    }
}
