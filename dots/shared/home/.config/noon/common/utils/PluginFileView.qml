import QtQuick
import qs.common
import qs.common.functions

ConfigFileView {
    id: root
    readonly property string basePath: Paths.standard.state + "/plugins/"
    readonly property string cleanPath: Paths.methods.trim(path)
    path: basePath + fileName + ".json"
}
