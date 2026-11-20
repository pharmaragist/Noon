import QtQuick
import Quickshell.Services.Notifications
import qs.common

RippleButton {
    id: button

    property string buttonText
    property int urgency
    readonly property bool isCritical: urgency === NotificationUrgency.Critical
    implicitWidth: contentItem?.contentWidth + leftPadding + rightPadding
    implicitHeight: 30
    leftPadding: 15
    rightPadding: 15
    buttonRadius: Rounding.small
    colBackground: isCritical ? Colors.colSecondaryContainer : Colors.colSurfaceContainerHighest
    colBackgroundHover: isCritical ? Colors.colSecondaryContainerHover : Colors.colSurfaceContainerHighestHover
    colRipple: isCritical ? Colors.colSecondaryContainerActive : Colors.colSurfaceContainerHighestActive

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: button.buttonText
        color: button.isCritical ? Colors.m3.m3onSurfaceVariant : Colors.m3.m3onSurface
    }
}
