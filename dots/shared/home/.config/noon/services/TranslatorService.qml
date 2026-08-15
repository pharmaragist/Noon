pragma Singleton
pragma ComponentBehavior: Bound
import QtQuick
import Quickshell
import qs.common.utils
import qs.common.functions
import qs.common





Singleton {
    id: service

    
    property string translatedText: ""
    property list<string> languages: []
    property bool isTranslating: false

    
    property string targetLanguage: Mem.options.services.translator.targetLanguage ?? "en"
    property string sourceLanguage: Mem.options.services.translator.sourceLanguage ?? "auto"

    
    property string _currentInputText: ""
    property var _translationCallback: null

    
    Component.onCompleted: {
        loadLanguages();
    }

    


    function loadLanguages() {
        getLanguagesProc.running = true;
    }

    




    function translate(text, callback) {
        if (!text || text.trim().length === 0) {
            service.translatedText = "";
            if (callback)
                callback("");
            return;
        }

        service._currentInputText = text.trim();
        service._translationCallback = callback;
        service.isTranslating = true;

        
        translateProc.running = false;
        translateProc.buffer = "";
        translateProc.running = true;
    }

    




    function setTargetLanguage(lang, retranslate) {
        service.targetLanguage = lang;
        if (retranslate && service._currentInputText.length > 0) {
            translate(service._currentInputText, service._translationCallback);
        }
    }

    




    function setSourceLanguage(lang, retranslate) {
        service.sourceLanguage = lang;
        if (retranslate && service._currentInputText.length > 0) {
            translate(service._currentInputText, service._translationCallback);
        }
    }
    function play(text: string) {
        NoonUtils.execDetached(["trans", "-p", text]);
    }
    
    Process {
        id: translateProc
        command: ["bash", "-c", `trans -no-theme -no-bidi` + ` -source '${TextUtils.shellSingleQuoteEscape(service.sourceLanguage)}'` + ` -target '${TextUtils.shellSingleQuoteEscape(service.targetLanguage)}'` + ` -no-ansi '${TextUtils.shellSingleQuoteEscape(service._currentInputText)}'`]
        property string buffer: ""

        stdout: SplitParser {
            onRead: data => {
                translateProc.buffer += data + "\n";
            }
        }

        onExited: (exitCode, exitStatus) => {
            
            const sections = translateProc.buffer.trim().split(/\n\s*\n/);

            
            const result = sections.length > 1 ? sections[1].trim() : "";
            service.translatedText = result;
            service.isTranslating = false;

            
            if (service._translationCallback) {
                service._translationCallback(result);
            }
        }
    }

    
    Process {
        id: getLanguagesProc
        command: ["trans", "-list-languages", "-no-bidi"]
        property list<string> bufferList: ["auto"]
        running: false

        stdout: SplitParser {
            onRead: data => {
                getLanguagesProc.bufferList.push(data.trim());
            }
        }

        onExited: (exitCode, exitStatus) => {
            
            let langs = getLanguagesProc.bufferList.filter(lang => lang.trim().length > 0 && lang !== "auto").sort((a, b) => a.localeCompare(b));
            langs.unshift("auto");
            service.languages = langs;
            getLanguagesProc.bufferList = [];
        }
    }
}
