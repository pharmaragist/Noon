import QtQuick
import Quickshell

Region {
    property bool enabled: true
    property Item target: null
    x: target?.x ?? 0
    y: target?.y ?? 0
    width: target && enabled ? target?.width : 0
    height: target && enabled ? target?.height : 0
}
