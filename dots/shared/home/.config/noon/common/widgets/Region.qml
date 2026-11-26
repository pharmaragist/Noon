import QtQuick
import Quickshell

Region {
    property bool enabled: true
    property Item target: null
    x: target?.x ?? 0
    y: target?.y ?? 0
    width: target && enabled ? target?.width : 0
    height: target && enabled ? target?.height : 0
    radius: target?.radius ?? 0
    topLeftRadius: target?.topLeftRadius ?? 0
    topRightRadius: target?.topRightRadius ?? 0
    bottomLeftRadius: target?.bottomLeftRadius ?? 0
    bottomRightRadius: target?.bottomRightRadius ?? 0
}
