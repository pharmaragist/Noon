


import QtQuick
import Quickshell
import qs.common
import qs.common.functions

Image {
    id: root

    required property var fileModelData

    asynchronous: true
    fillMode: Image.PreserveAspectFit
    source: {
        if (!fileModelData.fileIsDir)
            return NoonUtils.iconPath("application-x-zerosize");

        if ([Paths.standard.documents, Paths.standard.downloads, Paths.standard.music, Paths.standard.pictures, Paths.standard.videos].some((dir) => {
            return Paths.methods.trim(dir) === fileModelData.filePath;
        }))
            return NoonUtils.iconPath(`folder-${fileModelData.fileName.toLowerCase()}`);

        return NoonUtils.iconPath("inode-directory");
    }
    onStatusChanged: {
        if (status === Image.Error)
            source = NoonUtils.iconPath("error");

    }

    Process {
        running: !fileModelData.fileIsDir
        command: ["file", "--mime", "-b", fileModelData.filePath]

        stdout: StdioCollector {
            onStreamFinished: {
                const mime = text.split(";")[0].replace("/", "-");
                root.source = Images.validImageTypes.some((t) => {
                    return mime === `image-${t}`;
                }) ? fileModelData.fileUrl : NoonUtils.iconPath(mime);
            }
        }

    }

}
