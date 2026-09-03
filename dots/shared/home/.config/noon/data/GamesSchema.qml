import qs.common
import qs.common.utils

JsonAdapter {
    property JO options: JO {
        property bool adaptiveTheme: false
        property list<string> launchEnv: ["__NV_PRIME_RENDER_OFFLOAD=1", "__GLX_VENDOR_LIBRARY_NAME=nvidia"]
    }
    property list<var> list: []
    property string gameModeCommand: ""
}
