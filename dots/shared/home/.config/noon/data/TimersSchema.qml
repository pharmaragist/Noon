import qs.common.utils

JsonAdapter {
    property list<var> timers: []
    property list<var> presets: [
        { duration: 1500, icon: "timer", name: "Pomodoro" },
        { duration: 300, icon: "coffee", name: "Short Break" },
        { duration: 900, icon: "bed", name: "Long Break" },
        { duration: 5400, icon: "mindfulness", name: "Deep Work" },
        { duration: 1800, icon: "fitness_center", name: "Exercise" },
        { duration: 600, icon: "self_improvement", name: "Meditation" },
        { duration: 900, icon: "flash_on", name: "Quick Task" },
        { duration: 3600, icon: "groups", name: "Meeting" }
    ]
    property int nextTimerId: 0
}
