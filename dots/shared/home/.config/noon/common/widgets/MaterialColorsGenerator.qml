import Quickshell
import QtQuick
import qs.common.utils
import qs.common
import Noon.Widgets as Noon

Item {
    id: root
    visible: false
    required property string source
    readonly property var colors: palette.keyColor ? palette.colors : Colors
    property bool dark: Mem.looks.mode !== "light"
    property string scheme: Mem.looks.scheme
    property alias depth: quantizer.depth
    property alias rescaleSize: quantizer.rescaleSize
    property bool active: source.length > 0

    // ImageDecoder resolves data:/base64/CDN/file sources to a cached
    // local file (ColorQuantizer only reads paths). Plain paths pass
    // through; a failed fetch clears output, a pending one keeps stale art.
    Noon.ImageDecoder {
        id: decoder
        source: root?.source ?? ""
         cachePath: Paths.standard.cache + "/media/coverarts"
    }

    ColorQuantizer {
        id: quantizer
        source: decoder?.output ?? ""
        depth: root.depth
        rescaleSize: root.rescaleSize
    }

    ColorsGenerator {
        id: palette
        active: root.active && decoder?.output?.length > 0
        keyColor: quantizer?.colors[0] ?? "black"
        dark: root.dark
        scheme: root.scheme
    }
}
