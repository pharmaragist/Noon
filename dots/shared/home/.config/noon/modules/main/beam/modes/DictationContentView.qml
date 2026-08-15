import QtQuick
import QtQuick.Layouts
import Quickshell

import qs.common
import qs.common.widgets
import qs.services

PanelRect {
    id: root
    anchors.fill: parent
    readonly property bool toggled: SpeechService.listening ?? false

    
    
    

    RowLayout {
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.left: parent.left

        spacing: Padding.large
        anchors.leftMargin: Padding.normal
        anchors.rightMargin: Padding.normal

        MaterialShapeWrappedSymbol {
            implicitSize: 35
            text: "graphic_eq"
            iconSize: 13
            colSymbol: root.toggled ? Colors.colOnPrimary : Colors.colOnLayer3
            color: root.toggled ? Colors.colPrimary : Colors.colLayer3
            _shape: "PixelCircle"

            Behavior on color {
                CAnim {}
            }
        }

        LayerRect {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: width / 2
            clip: true
            toggled: root.toggled
            
            Visualizer {
                active: true
                _mode: "Bars"
                color: root.toggled ? Colors.colPrimary : Colors.colLayer3
                visualizerColor: root.toggled ? Colors.colOnPrimary : Colors.colOnLayer3
            }
        }

        RippleButtonWithIcon {
            releaseAction: () => {
                if (SpeechService.isListening) {
                    SpeechService.stop();
                    root.hide();
                } else
                    SpeechService.listen();
            }
            colBackground: SpeechService.listening ? Colors.colPrimaryContainer : Colors.colLayer1
            materialIcon: !SpeechService.listening ? "mic" : "stop"
            buttonRadius: width / 2
            implicitSize: 35
            animateIcon: true
        }
    }
}
