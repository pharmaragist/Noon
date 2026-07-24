import "../common"
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Hyprland
import qs.common
import qs.common.widgets
import qs.services

Item {
     id:root
     Layout.preferredHeight: 65
     Layout.fillWidth: true
     RLayout {
         anchors.fill: parent
         anchors.bottomMargin: XPadding.small
         anchors.rightMargin: XPadding.large
         Spacer {}
         spacing: XPadding.normal
         RowLayout {
             spacing: XPadding.small
             XButton {
                 colBackground: XColors.colors.colWarning
                 colBackgroundHover: XColors.colors.colWarningHover
                 colBackgroundActive: XColors.colors.colWarningActive
                 colBorder: "white"
                 Text {
                     font: Fonts.request("mono", 28)
                      anchors.centerIn: parent
                      text: ""
                      color: XColors.colors.colOnWarning
                 }
             }
             XText {
                 text: "Log Off"
                 font.pixelSize: XFonts.sizes.large
             }
         }
         RowLayout {
             spacing: XPadding.small
             XButton {
                 colBackground: XColors.colors.colCritical
                 colBackgroundHover: XColors.colors.colCriticalHover
                 colBackgroundActive: XColors.colors.colCriticalHover
                 colBorder: "white"
                 Text {
                     font: Fonts.request("mono", 28)
                      anchors.centerIn: parent
                      text: "󰤁"
                      color: XColors.colors.colOnCritical
                 }
             }
             XText {
                 text: "Shut Down"
                 font.pixelSize: XFonts.sizes.large
             }
         }

     }
 }
