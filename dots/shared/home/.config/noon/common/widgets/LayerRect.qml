import QtQuick
import qs.common
import qs.common.widgets
import qs.common.functions

StyledRect {
    id: root
    clip: true
    property bool toggled: false
    property color colBackground: this.colors.colLayer1
    property color activeColor: toggled ? this.colors.colPrimary : this.colors.colLayer1
    color: activeColor
}
