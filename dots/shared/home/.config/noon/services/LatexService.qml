pragma Singleton
pragma ComponentBehavior: Bound

import qs.common.functions
import qs.common
import QtQuick
import Quickshell

Singleton {
    id: root

    property list<string> processedHashes: []
    property string latexOutputPath: Paths.methods.trim(Paths.services.latex)
    property bool available: false
    property var _renderer: null

    signal renderFinished(string hash, string imagePath)

    Component.onCompleted: {
        const component = Qt.createComponent(Qt.resolvedUrl("LatexRendererBridge.qml"));
        if (component.status !== Component.Ready) {
            console.warn("[LatexService] renderer unavailable:", component.errorString());
            return;
        }
        root._renderer = component.createObject(null, {
            "cacheDir": root.latexOutputPath,
            "foreground": Colors.colOnLayer1
        });
        if (root._renderer === null) {
            console.warn("[LatexService] failed to create renderer");
            return;
        }
        root.available = true;
        root._renderer.cached.connect((hash, filePath) => {
            if (root.processedHashes.includes(hash)) {
                root.renderFinished(hash, filePath);
            }
        });
    }

    function requestRender(expression) {
        if (!expression || !root._renderer)
            return ["", false];
        const hash = root._renderer.hashFor(expression);

        if (!root.processedHashes.includes(hash)) {
            root.processedHashes.push(hash);

            if (_renderer.isCached(expression)) {
                root.renderFinished(hash, `${root.latexOutputPath}/${hash}.png`);
                return [hash, true];
            }

            _renderer.preRender(expression);
            return [hash, false];
        }

        return [hash, _renderer.isCached(expression)];
    }

    function cleanFormula(input) {
        if (!input)
            return "";
        return input.replace(/^\$\$[\s\S]*?\$\$/gm, m => m.slice(2, -2).trim()).replace(/\\\(/g, '').replace(/\\\)/g, '').replace(/\\\[/g, '').replace(/\\\]/g, '').replace(/^\$|\$$/gm, '').trim();
    }
}
