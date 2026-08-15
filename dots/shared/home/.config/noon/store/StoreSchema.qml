import qs.common.utils

JsonAdapter {
    property JO misc: JO {
        property list<string> ipcCommands: []
        property list<string> systemCommands: []
    }

    property JO services: JO {
        property JO colors: JO {
            property list<var> palettes: []
        }

        property JO backlight: JO {
            property list<var> devices: []
        }
        property JO cursors: JO {
            property list<string> availableCursors: []
        }
        property JO icons: JO {
            property list<var> availableIconThemes: []
        }
        property JO ambientSounds: JO {
            property list<var> availableSounds: []
        }
    }
}
