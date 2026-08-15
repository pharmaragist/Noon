pragma Singleton
pragma ComponentBehavior: Bound
import qs.common
import qs.common.utils
import qs.common.functions
import Quickshell
import Qt.labs.platform
import QtQuick





Singleton {
    id: root

    property bool loaded: false
    property var keyringData: ({})

    property var properties: {
        "application": "hyprnoon",
        "explanation": qsTr("For storing API keys and other sensitive information")
    }
    property var propertiesAsArgs: Object.keys(root.properties).reduce(function (arr, key) {
        return arr.concat([key, root.properties[key]]);
    }, [])
    property string keyringLabel: TextUtils.format(qsTr("{0} Safe Storage"), "hyprnoon")

    function setNestedField(path, value) {
        if (!root.keyringData)
            root.keyringData = {};
        let keys = path;
        let obj = root.keyringData;
        let parents = [obj];

        
        for (let i = 0; i < keys.length - 1; ++i) {
            if (!obj[keys[i]] || typeof obj[keys[i]] !== "object") {
                obj[keys[i]] = {};
            }
            obj = obj[keys[i]];
            parents.push(obj);
        }

        
        obj[keys[keys.length - 1]] = value;

        
        for (let i = keys.length - 2; i >= 0; --i) {
            let parent = parents[i];
            let key = keys[i];
            
            parent[key] = Object.assign({}, parent[key]);
        }

        
        root.keyringData = Object.assign({}, root.keyringData);

        saveKeyringData();
    }

    function reload() {
        getData.running = true;
    }

    function saveKeyringData() {
        saveData.stdinEnabled = true;
        saveData.running = true;
    }

    Process {
        id: saveData
        command: ["secret-tool", "store", "--label=" + keyringLabel, ...propertiesAsArgs,]
        onRunningChanged: {
            if (saveData.running) {
                
                saveData.write(JSON.stringify(root.keyringData));
                stdinEnabled = false; 
            }
        }
    }

    Process {
        id: getData
        command: [ 
            "bash", "-c", `echo $(secret-tool lookup 'application' 'hyprnoon')`,]
        stdout: SplitParser {
            onRead: data => {
                if (data.length === 0)
                    return;
                try {
                    root.keyringData = JSON.parse(data);
                    
                } catch (e) {
                    console.error("[KeyringStorage] Failed to get keyring data, reinitializing.");
                    root.keyringData = {};
                    saveKeyringData();
                }
            }
        }
        onExited: (exitCode, exitStatus) => {
            
            if (exitCode !== 0) {
                console.error("[KeyringStorage] Failed to get keyring data, reinitializing.");
                root.keyringData = {};
                saveKeyringData();
            }
            root.loaded = true;
        }
    }
}
