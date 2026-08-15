pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell

Singleton {
    id: root

    function arrayFrom(jsonObj, keyName) {
        if (!jsonObj || !keyName) return;
        var map = [];
        for (const [key, cfg] of Object.entries(jsonObj)) {
            map.push(Object.assign({}, {
                keyName: key
            }, cfg));
        }

        return map;
    }

    function toPlainObject(qtObj) {
        if (qtObj === null || typeof qtObj !== "object")
            return qtObj;

        
        if (Array.isArray(qtObj)) {
            return qtObj.map(item => toPlainObject(item));
        }

        
        if (typeof qtObj.length === "number" && Object.keys(qtObj).every(key => !isNaN(key) || key === "length")) {
            let arr = [];
            for (let i = 0; i < qtObj.length; i++) {
                arr.push(toPlainObject(qtObj[i]));
            }
            return arr;
        }

        const result = ({});
        for (let key in qtObj) {
            if (typeof qtObj[key] !== "function" && !key.startsWith("objectName") && !key.startsWith("children") && !key.startsWith("object") && !key.startsWith("parent") && !key.startsWith("metaObject") && !key.startsWith("destroyed") && !key.startsWith("reloadableId")) {
                result[key] = toPlainObject(qtObj[key]);
            }
        }
        
        return result;
    }

    function applyToQtObject(qtObj, jsonObj) {
        
        if (!qtObj || typeof jsonObj !== "object" || jsonObj === null)
            return;

        
        const isQtArrayLike = obj => {
            return obj && typeof obj === "object" && typeof obj.length === "number" && Object.keys(obj).every(key => !isNaN(key) || key === "length");
        };

        
        if ((Array.isArray(qtObj) || isQtArrayLike(qtObj)) && Array.isArray(jsonObj)) {
            qtObj.length = 0;
            for (let i = 0; i < jsonObj.length; i++) {
                qtObj.push(jsonObj[i]);
            }
            return;
        }

        
        if ((Array.isArray(qtObj) || isQtArrayLike(qtObj)) && !Array.isArray(jsonObj)) {
            qtObj.length = 0;
            return;
        }

        
        if (!(Array.isArray(qtObj) || isQtArrayLike(qtObj)) && Array.isArray(jsonObj)) {
            return jsonObj;
        }

        for (let key in jsonObj) {
            if (!qtObj.hasOwnProperty(key))
                continue;
            const value = qtObj[key];
            const jsonValue = jsonObj[key];
            
            if ((Array.isArray(value) || isQtArrayLike(value)) && Array.isArray(jsonValue)) {
                value.length = 0;
                for (let i = 0; i < jsonValue.length; i++) {
                    value.push(jsonValue[i]);
                }
            } else if (value && typeof value === "object" && !Array.isArray(value) && !isQtArrayLike(value)) {
                const result = applyToQtObject(value, jsonValue);
                if (result !== undefined)
                    qtObj[key] = result;
            } else {
                qtObj[key] = jsonValue;
            }
        }
    }
}
