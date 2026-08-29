import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.functions

ColumnLayout {
    id: root
    property int monthShift: 0
    readonly property var calendarLayout: CalendarUtils.getCalendarLayout(viewingDate, monthShift === 0)
    readonly property var viewingDate: CalendarUtils.getDateInXMonthsTime(monthShift)
    readonly property string today: DateTimeService.request("d/M/yyyy")

    function shiftMonth(delta) {
        root.monthShift += delta;
    }
    function jumpToday() {
        root.monthShift = 0;
    }

    property alias showHeader: headerRow.visible

    property int cellSize: 23
    readonly property int gridWidth: cellSize * 7
    readonly property int gridHeight: cellSize * 6
    Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    spacing: Padding.tiny
    Layout.fillHeight: false
    Layout.fillWidth: true

    RowLayout {
        id: headerRow
        spacing: Padding.verysmall
        Layout.fillWidth: true

        Repeater {
            model: ["today", "chevron_left", "chevron_right"]
            delegate: RippleButtonWithIcon {
                Layout.alignment: Qt.AlignRight
                required property string modelData
                visible: modelData === "today" ? root.monthShift !== 0 : true
                materialIcon: modelData
                implicitSize: 24
                colBackground: Colors.colLayer3
                onClicked: {
                    if (modelData === "today")
                        root.jumpToday();
                    else
                        root.shiftMonth(modelData === "chevron_right" ? 1 : -1);
                }
            }
        }

        StyledText {
            leftPadding: Padding.huge
            text: Qt.formatDateTime(root.viewingDate, "MMMM")
            color: Colors.colPrimary
            font: Fonts.request("main", Fonts.sizes.small)
        }
    }

    GridLayout {
        Layout.fillHeight: false
        Layout.fillWidth: false
        Layout.alignment: Qt.AlignHCenter | Qt.AlignVCenter
        columns: 7
        rowSpacing: 2
        columnSpacing: 2

        Repeater {
            model: CalendarUtils.weekDays
            delegate: CalendarDayButton {
                day: qsTr(modelData.day)
                isToday: modelData.today
                bold: true
                enabled: false
            }
        }

        Repeater {
            model: 35
            delegate: CalendarDayButton {
                id: dayButton
                readonly property int row: Math.floor(index / 7)
                readonly property int col: index % 7
                window: root.window
                implicitSize: root.cellSize
                day: root.calendarLayout[row][col].day
                isToday: root.calendarLayout[row][col].today
                dateString: root.calendarLayout[row][col].day + "/" + (root.viewingDate.getMonth() + 1) + "/" + root.viewingDate.getFullYear()
                hasEvents: root.calendarLayout[row][col].today !== -1 && CalendarService.getTasksOfDate(dateString).length > 0
                releaseAction: () => CalendarService.pull()
            }
        }
    }
}
