import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell.Widgets
import qs.common
import qs.common.widgets




Item {
    id: root

    
    property bool enabled: true
    property bool toggled: false
    property bool autoToggle: true 
    property string primaryText: "Primary"
    property string primaryIcon: "expand_more"
    property string secondaryIcon: "expand_more"
    property real buttonRadius: 99
    property real buttonSmallRadius: 8
    property real buttonHeight: 45
    property int transitionDuration: 200
    property int buttonWide: 100
    property int buttonShrinked: buttonHeight
    
    property bool primaryPressed: false
    property bool secondaryPressed: false
    property color secondaryBgColor: {
        if (!enabled)
            return Colors.colSecondaryContainer;

        if (secondaryPressed)
            return Colors.colSecondaryContainerActive;

        if (secondaryMouseArea.containsMouse)
            return Colors.colSecondaryContainerHover;

        return Colors.colSecondaryContainer;
    }

    
    signal primaryClicked()
    signal secondaryClicked()

    
    implicitWidth: content.width
    implicitHeight: buttonHeight
    
    opacity: enabled ? 1 : 0.38
    
    focus: true
    Keys.onPressed: {
        if (event.key === Qt.Key_Return || event.key === Qt.Key_Space) {
            if (autoToggle)
                root.toggled = !root.toggled;

            root.primaryClicked();
            event.accepted = true;
        }
    }
    
    Accessible.role: Accessible.ButtonMenu
    Accessible.name: primaryText
    Accessible.description: "Split button with primary action: " + primaryText + " and secondary action"
    Accessible.onPressAction: primaryMouseArea.clicked()

    RowLayout {
        id: content

        anchors.fill: parent
        spacing: 3

        
        Rectangle {
            id: primaryButton

            Layout.fillHeight: true
            Layout.preferredWidth: !secondaryPressed ? buttonWide : buttonShrinked 
            height: buttonHeight
            topLeftRadius: buttonRadius
            bottomLeftRadius: buttonRadius
            topRightRadius: buttonSmallRadius
            bottomRightRadius: buttonSmallRadius
            color: {
                if (!enabled)
                    return Colors.colSecondaryContainer;

                if (primaryPressed)
                    return Colors.colSecondaryContainerActive;

                if (primaryMouseArea.containsMouse)
                    return Colors.colSecondaryContainerHover;

                return Colors.colSecondaryContainer;
            }

            StyledRectangularShadow {
                target: parent
            }
            

            RowLayout {
                anchors.centerIn: parent
                spacing: 4

                Symbol {
                    id: primaryIconLabel

                    text: root.primaryIcon
                    color: Colors.colOnSecondaryContainer
                    fill: 1
                    font.pixelSize: Fonts.sizes.huge

                    Behavior on color {
                        CAnim {
                        }

                    }

                }
                

                StyledText {
                    id: primaryTextLabel

                    visible: !secondaryPressed
                    text: root.primaryText
                    color: Colors.colOnSecondaryContainer
                    font.pixelSize: 18

                    Behavior on color {
                        ColorAnimation {
                            duration: transitionDuration
                        }

                    }

                }

            }

            
            MouseArea {
                id: primaryMouseArea

                anchors.fill: parent
                enabled: root.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: primaryPressed = true
                onReleased: primaryPressed = false
                onClicked: {
                    if (autoToggle)
                        root.toggled = !root.toggled;

                    root.primaryClicked();
                }
            }

            Behavior on Layout.preferredWidth {
                Anim {
                }

            }
            

            
            Behavior on color {
                ColorAnimation {
                    duration: transitionDuration
                }

            }

        }

        
        Rectangle {
            id: secondaryButton

            Layout.fillHeight: true
            Layout.preferredWidth: secondaryPressed ? buttonWide : buttonShrinked 
            height: buttonHeight
            topLeftRadius: buttonSmallRadius
            bottomLeftRadius: buttonSmallRadius
            topRightRadius: buttonRadius
            bottomRightRadius: buttonRadius
            
            color: {
                if (!enabled)
                    return Colors.colSecondaryContainer;

                if (secondaryPressed)
                    return Colors.colSecondaryContainerActive;

                if (secondaryMouseArea.containsMouse)
                    return Colors.colSecondaryContainerHover;

                return Colors.colSecondaryContainer;
            }

            StyledRectangularShadow {
                target: parent
            }

            
            Symbol {
                id: secondaryIconLabel

                anchors.centerIn: parent
                text: root.secondaryIcon
                color: Colors.colOnSecondaryContainer
                font.pixelSize: buttonHeight * 0.5
                
                rotation: {
                    if (secondaryPressed)
                        return 180;

                    if (secondaryMouseArea.containsMouse)
                        return 90;

                    return 0;
                }

                
                Behavior on rotation {
                    NumberAnimation {
                        duration: transitionDuration
                        easing.type: Easing.OutCubic
                    }

                }

                Behavior on color {
                    ColorAnimation {
                        duration: transitionDuration
                    }

                }

            }

            
            MouseArea {
                id: secondaryMouseArea

                anchors.fill: parent
                enabled: root.enabled
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onPressed: secondaryPressed = true
                onReleased: secondaryPressed = false
                onClicked: {
                    root.secondaryClicked();
                }
            }

            Behavior on Layout.preferredWidth {
                Anim {
                }

            }
            

            
            Behavior on color {
                CAnim {
                }

            }

        }

    }

}
