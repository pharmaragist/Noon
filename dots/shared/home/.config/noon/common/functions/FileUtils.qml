pragma Singleton
pragma ComponentBehavior: Bound
import Quickshell
import Quickshell.Io
import qs.common
import Noon.Protocols

Singleton {
    id: root

    function trim(str) {
        str = String(str);
        return str.startsWith("file://") ? str.slice(7) : str;
    }

    function fileNameForPath(str) {
        if (typeof str !== "string")
            return "";
        const trimmed = trim(str);
        return trimmed.split(/[\\/]/).pop();
    }

    function trimFileExt(str) {
        if (typeof str !== "string")
            return "";
        const trimmed = trim(str);
        const lastDot = trimmed.lastIndexOf(".");
        if (lastDot > -1 && lastDot > trimmed.lastIndexOf("/")) {
            return trimmed.slice(0, lastDot);
        }
        return trimmed;
    }

    function parentDirectory(str) {
        if (typeof str !== "string")
            return "";
        const trimmed = trim(str);
        const parts = trimmed.split(/[\\/]/);
        if (parts.length <= 1)
            return "";
        parts.pop();
        return parts.join("/");
    }

    function folderNameForPath(str) {
        if (typeof str !== "string")
            return "";
        const trimmed = trim(str);

        const noTrailing = trimmed.endsWith("/") ? trimmed.slice(0, -1) : trimmed;
        if (!noTrailing)
            return "";
        return noTrailing.split(/[\\/]/).pop();
    }

    function getEscapedFileName(path) {
        const trimmed = trim(path);

        const fileName = trimmed.split(/[\/\\]/).pop();

        return encodeURIComponent(fileName);
    }

    function getEscapedFileNameWithoutExtension(path) {
        const trimmed = trim(path);
        const fileName = trimmed.split(/[\/\\]/).pop();
        const lastDotIndex = fileName.lastIndexOf(".");
        const nameWithoutExtension = lastDotIndex !== -1 ? fileName.slice(0, lastDotIndex) : fileName;
        return encodeURIComponent(nameWithoutExtension);
    }

    function getEscapedFileExtension(path) {
        const trimmed = trim(path);
        const fileName = trimmed.split(/[\/\\]/).pop();
        const lastDotIndex = fileName.lastIndexOf(".");
        const extension = lastDotIndex !== -1 && lastDotIndex < fileName.length - 1 ? fileName.slice(lastDotIndex + 1) : "";
        return encodeURIComponent(extension);
    }

    function insertTextBeforeExtension(path, insertText) {
        if (!path || typeof path !== "string")
            return "";
        const hasFileProtocol = path.startsWith("file://");
        const trimmed = hasFileProtocol ? path.slice(7) : path;
        const parts = trimmed.split(/[\/\\]/);
        const fileName = parts.pop();
        if (!fileName)
            return "";
        const lastDotIndex = fileName.lastIndexOf(".");
        const nameWithoutExt = lastDotIndex !== -1 ? fileName.slice(0, lastDotIndex).replace(/\s+$/, "") : fileName;
        const ext = lastDotIndex !== -1 ? fileName.slice(lastDotIndex) : "";
        const newFileName = nameWithoutExt + insertText + ext;
        const newPath = [...parts, newFileName].join("/");
        return hasFileProtocol ? "file://" + newPath : newPath;
    }

    function fileExists(filePath) {
        if (!filePath) {
            return false;
        }

        let pathToCheck = filePath;
        if (typeof filePath === "object" && filePath.toString()) {
            pathToCheck = filePath.toString();
        } else if (typeof filePath !== "string") {
            console.warn("fileExists: Invalid input type:", typeof filePath);
            return false;
        }

        let trimmed = pathToCheck;
        if (pathToCheck.startsWith("file://")) {
            trimmed = pathToCheck.substring(7);
        } else if (pathToCheck.startsWith("file:///")) {
            trimmed = pathToCheck.substring(8);
        }

        try {
            const exists = Paths.methods.fileExists(trimmed);
            return exists;
        } catch (error) {
            return false;
        }
    }

    function isFile(filePath) {
        if (typeof filePath !== "string")
            return false;
        const p = trim(filePath);
        if (/[\\/]$/.test(p))
            return false;
        const base = p.split(/[\\/]/).pop() ?? "";
        return base.includes(".") && !base.startsWith(".");
    }

    function isDirectory(filePath) {
        return typeof filePath === "string" && !isFile(filePath);
    }

    function collapsePath(path) {
        if (!path)
            return;
        return path.trim().replace(/^file:\/\/\/home\/[^\/]+/, "~");
    }

    function expandPath(filePath) {
        if (!filePath)
            return;
        if (filePath.startsWith("~")) {
            return Paths.standard.home + filePath.substring(1);
        }
    }

    function mkdir(dirs) {
        if (!dirs)
            return;
        if (Array.isArray(dirs)) {
            const clean = dirs.map(d => trim(d));
            const stringified = clean.join("' '");
            NoonUtils.execDetached(`mkdir -p '${stringified}'`);
        } else
            NoonUtils.execDetached(`mkdir -p '${trim(dirs)}'`);
    }

    function copyItem(item, target) {
        NoonUtils.execDetached(`cp ${trim(item)} ${trim(target)}`);
    }

    function moveItem(item, target) {
        const fileName = getEscapedFileName(item);
        NoonUtils.execDetached(`mv ${trim(item)} ${trim(target)}/${fileName}`);
    }

    function createFileWith(path, content) {
        NoonUtils.execDetached(["echo", `"${content}"`, ">", trim(path)]);
    }

    function createLink(file, dist) {
        if (!file || !dist)
            return;
        NoonUtils.execDetached(["ln", "-sf", `${Paths.methods.trim(file)}`, `${Paths.methods.trim(dist)}`]);
    }

    function readFile(fileUrl) {
        return FileProtocols.readText(fileUrl);
    }

    function exists(path) {
        var p = path;
        if (p.startsWith('/'))
            "file://" + p;

        return FileProtocols.exists(p);
    }
}
