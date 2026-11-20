import qs.common
import qs.services
import qs.common.utils

JsonAdapter {
    id: root
    property list<var> models: []
    property string agent: "plan"
    property string effort: ""
    property string model: ""
    property string currentSessionId: ""
    property int recallLimit: 10
    property bool preloadMessages: false
    property string sessionDir: Paths.services.harnessDir
    property JO tokenCount: JO {
        property int input
        property int output
        property int total
    }
}
