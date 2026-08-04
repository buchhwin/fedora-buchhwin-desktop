pragma Singleton

// The wallpaper: which images exist, which one is shown.
//
// The folder is listed with FolderListModel — pure QML, no shell command and no
// Process. Thumbnails must set Image.sourceSize so Qt decodes a 4K JPEG at
// thumbnail size instead of decoding it fully and then shrinking it; that is
// the difference between a picker that opens instantly and one that stutters.
//
// ⚠️ This Qt build has NO WebP and NO TIFF plugin (qt6-qtimageformats is not
// installed). A .webp wallpaper fails to load SILENTLY — hence `supported`,
// so the picker can leave it out rather than showing an empty tile.
import QtQuick
import Qt.labs.folderlistmodel
import Quickshell
import "../config"

Singleton {
    id: root

    readonly property string folder: Config.wallpaper.folder
    readonly property string current: Config.wallpaper.current
    readonly property bool available: folder.length > 0 && dir.count > 0

    // Formats this Qt actually has a plugin for. JPEG/PNG/GIF come from
    // qt6-qtbase-gui; AVIF/HEIF/JXL from kf6-kimageformats when installed.
    readonly property var supported: ["jpg", "jpeg", "png", "gif", "avif", "jxl", "webp"]

    readonly property int count: dir.count

    function pathAt(i) {
        var u = dir.get(i, "fileURL")
        return u ? String(u) : ""
    }

    function nameAt(i) {
        var n = dir.get(i, "fileName")
        return n ? String(n) : ""
    }

    function choose(url) {
        Config.wallpaper.current = String(url)
        Config.save()
    }

    FolderListModel {
        id: dir
        // An empty folder setting means "no wallpaper", not "the home
        // directory" — which is what an unset folder would otherwise list.
        folder: root.folder.length ? "file://" + root.folder : ""
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.gif", "*.avif", "*.jxl"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
    }

    readonly property var model: dir
}
