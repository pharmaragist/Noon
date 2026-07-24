import QtQuick
import qs.common
import qs.common.functions

ConfigFileView {
    id: root
    readonly property string basePath: Directories.standard.state + "/plugins/"
    readonly property string cleanPath: Directories.methods.trim(path)
    path: basePath + fileName + ".json"
}
