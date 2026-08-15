import QtQuick
import qs.common
import qs.common.widgets

Loader {
    id: root

    property bool shown: true
    property alias behavior: fadeAnim
    property alias animationDuration: fadeAnim.duration
    property alias fade: opacityBehavior.enabled
    property var _item: ready ? item : null
    property var binds: null
    
    
    
    readonly property bool ready: item && item !== null
    signal loading
    opacity: shown ? 1 : 0
    visible: opacity > 0
    active: opacity > 0

    onLoaded: {
        loading();
        if (!!binds)
            bind(binds);
    }
    function bind(tp) {
        if (!tp || !ready)
            return;
        for (const [key, value] of Object.entries(tp)) {
            if (key in item)
                item[key] = Qt.binding(value);
        }
    }

    function reload() {
        if (!root.active)
            return;
        root.active = false;
        root.active = true;
    }

    function sanitizeSource(basePath, component) {
        return basePath + component + ".qml";
    }

    function debouncedReload(delay = 100) {
        NoonUtils.inlineTimer(() => {
            root.reload();
        }, delay);
    }

    Behavior on opacity {
        id: opacityBehavior

        Anim {
            id: fadeAnim
        }
    }
}
