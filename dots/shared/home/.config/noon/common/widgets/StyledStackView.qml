import QtQuick
import QtQuick.Controls

StackView {
    pushEnter: replaceEnter
    pushExit: replaceExit

    popEnter: replaceEnter
    popExit: replaceExit

    replaceEnter: enter
    replaceExit: exit

    property var enter: Transition {
        ParallelAnimation {
            Anim {
                property: "scale"
                from: 0.9
                to: 1
            }
            Anim {
                property: "opacity"
                from: 0
                to: 1
            }
        }
    }
    property var exit: Transition {
        ParallelAnimation {
            Anim {
                property: "scale"
                from: 1
                to: 0.9
            }
            Anim {
                property: "opacity"
                from: 1
                to: 0
            }
        }
    }
}
