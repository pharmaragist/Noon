import QtQuick
import QtQuick.Controls
import QtQuick.Controls.Material
import QtQuick.Layouts
import qs.services
import qs.common
import qs.common.functions
import qs.common.widgets

WidgetContainer {
    id: root

    property var calendarLayout: CalendarUtils.getCalendarLayout(viewingDate, monthShift === 0)
    property int monthShift: 0
    property var viewingDate: CalendarUtils.getDateInXMonthsTime(monthShift)
    property var upcomingEvents: getUpcomingEvents(7)
    readonly property string today: DateTimeService.request("d/M/yyyy")
    Component.onCompleted: CalendarService.pull()

    function getTasksOfDate(dateString) {
        const todayEvents = CalendarService.list.filter(e => e.start === dateString);
        const allTasks = TodoService?.list ?? [];
        const tasks = allTasks.map(item => ({
                    content: item?.content ?? "",
                    start: item?.due + '/' + DateTimeService.year ?? "",
                    isTask: true
                })).filter(task => task.start === dateString);
        return [...todayEvents, ...tasks];
    }

    function getUpcomingEvents(daysAhead) {
        let result = [];
        const base = new Date();
        for (let i = 1; i <= daysAhead; i++) {
            const d = new Date(base);
            d.setDate(base.getDate() + i);
            const dateString = d.getDate() + "/" + (d.getMonth() + 1) + "/" + d.getFullYear();
            const tasks = getTasksOfDate(dateString);
            for (const t of tasks)
                result.push({
                    content: t.content,
                    dateLabel: Qt.formatDateTime(d, "ddd d")
                });
        }
        return result;
    }

    small: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.normal
        spacing: 0

        StyledText {
            Layout.fillWidth: true
            text: DateTimeService.request("ddd")
            color: Colors.colPrimary
            font: Fonts.request("main", "verysmall", {
                weight: Font.DemiBold
            })
            horizontalAlignment: Text.AlignHCenter
        }

        Spacer {}

        StyledText {
            Layout.fillWidth: true
            text: DateTimeService.request("d")
            color: Colors.colOnLayer0
            font: Fonts.request("numbers", Fonts.sizes.title)
            horizontalAlignment: Text.AlignHCenter
        }

        StyledText {
            Layout.fillWidth: true
            Layout.topMargin: Padding.tiny
            text: DateTimeService.request("MMM").toUpperCase()
            color: Colors.colOnSurfaceVariant
            font: Fonts.request("main", "verysmall")
            horizontalAlignment: Text.AlignHCenter
        }

        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Padding.tiny
            implicitWidth: 4
            implicitHeight: 4
            visible: root.getTasksOfDate(root.today).length > 0

            Rectangle {
                anchors.fill: parent
                radius: Rounding.full
                color: Colors.colPrimary
            }
        }

        Spacer {}
    }

    normal: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.normal

        MonthCalendar {
            viewingDate: root.viewingDate
            calendarLayout: root.calendarLayout
            window: root.window
            getTasksOfDate: root.getTasksOfDate
            monthShift: root.monthShift
            onShiftMonth: delta => root.monthShift += delta
            onJumpToday: root.monthShift = 0
        }
    }

    large: RowLayout {
        anchors.fill: parent
        anchors.leftMargin: Padding.huge
        anchors.rightMargin: Padding.huge
        spacing: Padding.normal

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: Padding.large
            StyledText {
                Layout.fillWidth: true
                text: DateTimeService.request("dddd")
                color: Colors.colPrimary
                font: Fonts.request("main", Fonts.sizes.small)
            }

            StyledText {
                Layout.fillWidth: true
                text: DateTimeService.request("d")
                color: Colors.colOnLayer0
                font: Fonts.request("numbers", 40)
            }

            StyledText {
                Layout.fillWidth: true
                Layout.topMargin: Padding.tiny
                text: {
                    const n = root.getTasksOfDate(root.today).length;
                    return n + (n === 1 ? " Event Today" : " Events Today");
                }
                color: Colors.colOnSurfaceVariant
                font: Fonts.request("main", Fonts.sizes.verysmall)
            }

            StyledListView {
                radius: 0
                clip: true
                hint: false
                Layout.topMargin: Padding.normal
                Layout.fillWidth: true
                Layout.fillHeight: true
                model: getTasksOfDate(root.today)
                delegate: Item {
                    required property var modelData
                    anchors.right: parent?.right
                    anchors.left: parent?.left
                    height: 55
                    RLayout {
                        anchors.fill: parent

                        ColumnLayout {
                            Layout.fillWidth: true

                            StyledText {
                                text: modelData.content
                                color: Colors.colOnLayer0
                                font: Fonts.request("main", Fonts.sizes.normal)
                                Layout.fillWidth: true
                                truncate: true
                                Layout.rightMargin: Padding.large
                            }
                            StyledText {
                                visible: text.length > 0
                                text: {
                                    if (modelData.isTask)
                                        return "";
                                    const parts = modelData.end.split('/');
                                    return "Ends at " + parts[0] + '/' + parts[1];
                                }
                                color: Colors.colOnSurfaceVariant
                                font: Fonts.request("main", Fonts.sizes.verysmall)
                                Layout.fillWidth: true
                                truncate: true
                            }
                        }
                    }
                }

                StyledText {
                    visible: parent.count === 0
                    text: "No Events Today"
                    anchors.centerIn: parent
                    font.pixelSize: Fonts.sizes.small
                    color: Colors.colSubtext
                }
            }
        }

        MonthCalendar {
            viewingDate: root.viewingDate
            calendarLayout: root.calendarLayout
            window: root.window
            getTasksOfDate: root.getTasksOfDate
            monthShift: root.monthShift
            onShiftMonth: delta => root.monthShift += delta
            onJumpToday: root.monthShift = 0
        }
    }

    xlarge: ColumnLayout {
        anchors.fill: parent
        anchors.margins: Padding.large
        spacing: Padding.large

        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true

            ColumnLayout {
                Layout.leftMargin: Padding.small
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: -Padding.verysmall

                StyledText {
                    text: DateTimeService.request("dddd")
                    color: Colors.colPrimary
                    font: Fonts.request("main", Fonts.sizes.small)
                }

                StyledText {
                    text: DateTimeService.request("d")
                    color: Colors.colOnLayer0
                    font: Fonts.request("numbers", 40)
                }

                StyledText {
                    Layout.topMargin: Padding.tiny
                    text: {
                        const n = root.getTasksOfDate(root.today).length;
                        return n + (n === 1 ? " Event Today" : " Events Today");
                    }
                    color: Colors.colOnSurfaceVariant
                    font: Fonts.request("main", Fonts.sizes.verysmall)
                }

                StyledListView {
                    radius: 0
                    clip: true
                    hint: false
                    Layout.topMargin: Padding.normal
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    model: getTasksOfDate(root.today)
                    delegate: Item {
                        required property var modelData
                        anchors.right: parent?.right
                        anchors.left: parent?.left
                        height: 55
                        RLayout {
                            anchors.fill: parent

                            ColumnLayout {
                                Layout.fillWidth: true

                                StyledText {
                                    text: modelData.content
                                    color: Colors.colOnLayer0
                                    font: Fonts.request("main", Fonts.sizes.normal)
                                    Layout.fillWidth: true
                                    truncate: true
                                    Layout.rightMargin: Padding.large
                                }
                                StyledText {
                                    visible: text.length > 0
                                    text: {
                                        if (modelData.isTask)
                                            return "";
                                        const parts = modelData.end.split('/');
                                        return "Ends at " + parts[0] + '/' + parts[1];
                                    }
                                    color: Colors.colOnSurfaceVariant
                                    font: Fonts.request("main", Fonts.sizes.verysmall)
                                    Layout.fillWidth: true
                                    truncate: true
                                }
                            }
                        }
                    }
                    StyledText {
                        visible: parent.count === 0
                        text: "No Events Today"
                        anchors.centerIn: parent
                        font.pixelSize: Fonts.sizes.small
                        color: Colors.colSubtext
                    }
                }
            }
            MonthCalendar {
                viewingDate: root.viewingDate
                calendarLayout: root.calendarLayout
                window: root.window
                getTasksOfDate: root.getTasksOfDate
                monthShift: root.monthShift
                onShiftMonth: delta => root.monthShift += delta
                onJumpToday: root.monthShift = 0
            }
        }
        Spacer {}
    }

    component MonthCalendar: ColumnLayout {
        id: monthCalendar
        required property var viewingDate
        required property var calendarLayout
        required property var window
        required property var getTasksOfDate
        required property int monthShift
        signal shiftMonth(int delta)
        signal jumpToday

        readonly property int cellSize: 23
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
                    visible: modelData === "today" ? monthCalendar.monthShift !== 0 : true
                    materialIcon: modelData
                    implicitSize: 24
                    colBackground: Colors.colLayer3
                    onClicked: {
                        if (modelData === "today")
                            monthCalendar.jumpToday();
                        else
                            monthCalendar.shiftMonth(modelData === "chevron_right" ? 1 : -1);
                    }
                }
            }

            StyledText {
                leftPadding: Padding.huge
                text: Qt.formatDateTime(monthCalendar.viewingDate, "MMMM")
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
                    window: monthCalendar.window
                    day: monthCalendar.calendarLayout[row][col].day
                    isToday: monthCalendar.calendarLayout[row][col].today
                    dateString: monthCalendar.calendarLayout[row][col].day + "/" + (monthCalendar.viewingDate.getMonth() + 1) + "/" + monthCalendar.viewingDate.getFullYear()
                    hasEvents: monthCalendar.calendarLayout[row][col].today !== -1 && monthCalendar.getTasksOfDate(dateString).length > 0
                    getTasksOfDate: monthCalendar.getTasksOfDate
                    releaseAction: () => CalendarService.pull()
                }
            }
        }
    }
}
