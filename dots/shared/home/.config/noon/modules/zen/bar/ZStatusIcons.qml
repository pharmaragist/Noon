import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.services
import QtNetwork

Rectangle {
    id: root
    property int commonIconSize: 24

    color: Colors.m3.m3surfaceContainer
    Layout.fillHeight: true
    Layout.preferredWidth: content.width + Padding.massive
    RowLayout {
        id: content
        anchors.centerIn: parent
        spacing: Padding.huge

        StyledText {
            visible: AudioService.sink?.audio?.muted ?? false
            color: Colors.m3.m3onSurface
            text: "\uf466"   
            font.pixelSize: root.commonIconSize
            font.family: Fonts.family.monospace
        }
        StyledText {
            color: Colors.m3.m3onSurface
            text: {
                if (NetworkService.manager.ethernet)
                    return "\udb80\udea8";  
                if (!NetworkService.manager.wifiEnabled)
                    return "\udb82\udd2f";  
                if (NetworkService.manager.wifi && (NetworkService.manager.networkName ?? "") !== "") {
                    const strength = NetworkService.manager.networkStrength ?? 0;
                    if (strength > 80)
                        return "\udb82\udd29";  
                    if (strength > 60)
                        return "\udb82\udd28";  
                    if (strength > 40)
                        return "\udb82\udd27";  
                    if (strength > 20)
                        return "\udb82\udd26";  
                    return "\udb82\udd25";                     
                }
                return "\udb82\udd2f";  
            }
            font.pixelSize: root.commonIconSize
            font.family: Fonts.family.monospace
            MouseArea {
                anchors.fill: parent
                cursorShape: Qt.PointingHandCursor
                hoverEnabled: true
                onClicked: NoonUtils.execDetached(Mem.options.apps.networkEthernet)
            }
        }
        StyledText {
            visible: BluetoothService.available
            color: Colors.m3.m3onSurface

            text: {
                const connected = BluetoothService.bluetoothConnected ?? false;
                const enabled = BluetoothService.bluetoothEnabled ?? false;
                if (connected)
                    return "\udb80\udcaf";  
                if (enabled)
                    return "\udb80\udcae";  
                return "\udb80\udcb2";         
            }
            font.pixelSize: root.commonIconSize
            font.family: Fonts.family.monospace
        }
    }
}
