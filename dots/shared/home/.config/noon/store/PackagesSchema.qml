import qs.common
import qs.common.utils

JsonAdapter {
    id: root
    property var list: [
        {
            "name": "ai",
            "icon": "cognition_2",
            "description": "Commonly used dependencies for AI runtime",
            "type": "python",
            "dependencies": ["numpy", "onnxruntime", "faster_whisper"]
        },
        {
            "name": "google",
            "icon": "auto_awesome",
            "description": "For Oauth, Tasks, Calendar",
            "type": "python",
            "dependencies": ["requests_oauth2client", "urllib3"]
        },
        {
            "name": "misc",
            "icon": "misc",
            "description": "For some tertiary features and Qol",
            "type": "python",
            "dependencies": ["feedparser"]
        },
        {
            "name": "image",
            "icon": "image",
            "type": "fetch",
            "description": "Wallpaper and images depth manipulations as u2net",
            "mirrors": {
                "https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2net.onnx": "~/.u2net/u2net.onnx",
                "https://github.com/microsoft/onnxruntime/releases/download/v1.24.4/onnxruntime-linux-x64-1.24.4.tgz": "~/.u2net/libonnxruntime.so.1.24.4"
            }
        },
        {
            "name": "stt",
            "icon": "transcribe",
            "description": "Dependencies for Speech Service",
            "type": "python",
            "dependencies": ["numpy", "piper-tts", "sounddevice", "faster_whisper"],
            "postInstallCommands": [[Directories.scriptsDir + "/stt_service.py", "--stt"]]
        }
    ]
}
