import QtQuick
import qs.store
import qs.common
import qs.common.widgets
import qs.common.utils

import "layouts"
import "components"

Variants {
    model: Mem.options.bar.behavior.showOnAll ? MonitorsInfo.all : MonitorsInfo.main
    StyledLoader {
        id: loader
        required property var modelData
        shown: true
        source: Qt.resolvedUrl(`layouts/${BarData.currentModeInfo.layout}.qml`)
        onLoaded: this._item.screen = loader.modelData
    }
}
