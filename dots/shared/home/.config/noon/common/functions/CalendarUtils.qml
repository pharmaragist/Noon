pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell

Singleton {
    id: root

    
    readonly property var weekDays: [
        { day: "M", today: 0 },
        { day: "T", today: 0 },
        { day: "W", today: 0 },
        { day: "T", today: 0 },
        { day: "F", today: 0 },
        { day: "S", today: 0 },
        { day: "S", today: 0 }
    ]

    function checkLeapYear(year) {
        return year % 400 == 0 || (year % 4 == 0 && year % 100 != 0);
    }

    function getMonthDays(month, year) {
        const leapYear = checkLeapYear(year);
        if ((month <= 7 && month % 2 == 1) || (month >= 8 && month % 2 == 0))
            return 31;
        if (month == 2 && leapYear) return 29;
        if (month == 2 && !leapYear) return 28;
        return 30;
    }

    function getNextMonthDays(month, year) {
        const leapYear = checkLeapYear(year);
        if (month == 1 && leapYear) return 29;
        if (month == 1 && !leapYear) return 28;
        if (month == 12) return 31;
        if ((month <= 7 && month % 2 == 1) || (month >= 8 && month % 2 == 0))
            return 30;
        return 31;
    }

    function getPrevMonthDays(month, year) {
        const leapYear = checkLeapYear(year);
        if (month == 3 && leapYear) return 29;
        if (month == 3 && !leapYear) return 28;
        if (month == 1) return 31;
        if ((month <= 7 && month % 2 == 1) || (month >= 8 && month % 2 == 0))
            return 30;
        return 31;
    }

    function getDateInXMonthsTime(x) {
        var currentDate = new Date(); 
        if (x == 0) return currentDate; 

        var targetMonth = currentDate.getMonth() + x; 
        var targetYear = currentDate.getFullYear(); 

        
        targetYear += Math.floor(targetMonth / 12);
        targetMonth = ((targetMonth % 12) + 12) % 12;

        
        var targetDate = new Date(targetYear, targetMonth, 1);

        return targetDate;
    }

    function getCalendarLayout(dateObject, highlight) {
        if (!dateObject) dateObject = new Date();
        const weekday = (dateObject.getDay() + 6) % 7; 
        const day = dateObject.getDate();
        const month = dateObject.getMonth() + 1;
        const year = dateObject.getFullYear();
        const weekdayOfMonthFirst = (weekday + 35 - (day - 1)) % 7;
        const daysInMonth = getMonthDays(month, year);
        const daysInNextMonth = getNextMonthDays(month, year);
        const daysInPrevMonth = getPrevMonthDays(month, year);

        
        var monthDiff = weekdayOfMonthFirst == 0 ? 0 : -1;
        var toFill, dim;
        if (weekdayOfMonthFirst == 0) {
            toFill = 1;
            dim = daysInMonth;
        } else {
            toFill = daysInPrevMonth - (weekdayOfMonthFirst - 1);
            dim = daysInPrevMonth;
        }
        var calendar = [...Array(6)].map(() => Array(7));
        var i = 0,
            j = 0;
        while (i < 6 && j < 7) {
            calendar[i][j] = {
                day: toFill,
                today:
                    toFill == day && monthDiff == 0 && highlight ? 1 : monthDiff == 0 ? 0 : -1
            };
            
            toFill++;
            if (toFill > dim) {
                
                monthDiff++;
                if (monthDiff == 0) dim = daysInMonth;
                else if (monthDiff == 1) dim = daysInNextMonth;
                toFill = 1;
            }
            
            j++;
            if (j == 7) {
                j = 0;
                i++;
            }
        }
        return calendar;
    }
}
