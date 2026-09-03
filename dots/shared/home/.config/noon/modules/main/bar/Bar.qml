import QtQuick
import qs.data
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
        source: Qt.resolvedUrl(`layouts/${BarData.currentState.layout}.qml`)
        onLoaded: this._item.screen = loader.modelData
    }
}
