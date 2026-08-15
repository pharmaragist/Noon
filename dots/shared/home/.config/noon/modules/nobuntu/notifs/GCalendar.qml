import qs.services
import qs.common
import qs.common.functions
import qs.common.widgets
import QtQuick
import QtQuick.Layouts

Item {
    
    property int monthShift: 0
    property var viewingDate: CalendarUtils.getDateInXMonthsTime(monthShift)
    property var calendarLayout: CalendarUtils.getCalendarLayout(viewingDate, monthShift === 0)

    Layout.alignment:Qt.AlignHCenter

    implicitWidth: calendarColumn.width
    implicitHeight: calendarColumn.height + 10 * 2

    Keys.onPressed: event => {
        if ((event.key === Qt.Key_PageDown || event.key === Qt.Key_PageUp) && event.modifiers === Qt.NoModifier) {
            if (event.key === Qt.Key_PageDown) {
                monthShift++;
            } else if (event.key === Qt.Key_PageUp) {
                monthShift--;
            }
            event.accepted = true;
        }
    }
    MouseArea {
        anchors.fill: parent
        onWheel: event => {
            if (event.angleDelta.y > 0) {
                monthShift--;
            } else if (event.angleDelta.y < 0) {
                monthShift++;
            }
        }
    }

    ColumnLayout {
        id: calendarColumn
        anchors.centerIn: parent
        spacing: 5

        RowLayout {
            Layout.fillWidth: true
            spacing: 5
            GCalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    monthShift--;
                }
                contentItem: Symbol {
                    text: "chevron_left"
                    iconSize: Fonts.sizes.verylarge
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.colOnLayer1
                }
            }
            StyledText {
                text: viewingDate.toLocaleDateString(Qt.locale(), "MMMM")
                font {
                    pixelSize:Fonts.sizes.large
                }
                horizontalAlignment:Text.AlignHCenter
                Layout.fillWidth:true
                color:Colors.colOnLayer2
            }

            GCalendarHeaderButton {
                forceCircle: true
                downAction: () => {
                    monthShift++;
                }
                contentItem: Symbol {
                    text: "chevron_right"
                    iconSize: Fonts.sizes.verylarge
                    horizontalAlignment: Text.AlignHCenter
                    color: Colors.colOnLayer1
                }
            }
        }

        
        RowLayout {
            id: weekDaysRow
            Layout.alignment: Qt.AlignHCenter
            Layout.fillHeight: false
            spacing: 5
            Repeater {
                model: CalendarUtils.weekDays
                delegate: GCalendarDayButton {
                    day: qsTr(modelData.day)
                    isToday: modelData.today
                    bold: true
                    enabled: false
                }
            }
        }

        
        Repeater {
            id: calendarRows
            model: 6
            delegate: RowLayout {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillHeight: false
                spacing: 5
                Repeater {
                    model: Array(7).fill(modelData)
                    delegate: GCalendarDayButton {
                        day: calendarLayout[modelData][index].day
                        isToday: calendarLayout[modelData][index].today
                    }
                }
            }
        }
    }
}
