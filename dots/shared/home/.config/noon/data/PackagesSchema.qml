import qs.common
import qs.common.utils

JsonAdapter {
    id: root
    property var list: [
        {
            "name": "image",
            "icon": "image",
            "type": "fetch",
            "description": "Wallpaper and images depth manipulations as u2net",
            "mirrors": {
                "https://github.com/danielgatis/rembg/releases/download/v0.0.0/u2net.onnx": "~/.u2net/u2net.onnx",
                "https://github.com/microsoft/onnxruntime/releases/download/v1.24.4/onnxruntime-linux-x64-1.24.4.tgz": "~/.u2net/libonnxruntime.so.1.24.4"
            }
        }
    ]
}
