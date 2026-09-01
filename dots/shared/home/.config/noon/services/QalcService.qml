pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Noon.Utils

Singleton {
    id: root
    readonly property QalcEngine _engine: QalcEngine {}
    property string result: _engine.result

    function calculate(expression: string, callback: var) {
        _engine.calculate(expression, callback);
    }
}