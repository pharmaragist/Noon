import QtQuick
import qs.common
import qs.common.widgets
import qs.services

StyledRect {
    id: root
    color: "transparent"
    property real fill: 0

    StyledLoader {
        anchors.centerIn: parent
        readonly property var options: {
            "distro": distroComp,
            "symbol": symbolComp,
            "profile": profileComp
        }
        sourceComponent: options[Mem.options.desktop.branding.logo] ?? symbolComp
    }

    readonly property Component profileComp: ClippingShape {
        toggled: root.fill > 0
        implicitSize: 38
        source: SysInfoService?.userPfp
        _shape: "Clover4Leaf"
    }


    readonly property Component symbolComp: Symbol {
        icon: Mem.options.desktop.branding.materialSymbol ?? "spark"
        iconSize: 22
        color: Colors.colPrimary
        fill: root.fill
    }

    readonly property Component distroComp: CustomIcon {
        anchors.centerIn: parent
        implicitSize: root.implicitSize - Padding.huge
        source: SysInfoService.distroIcon
        colorize: true
        color: Colors.colPrimary
    }
}
