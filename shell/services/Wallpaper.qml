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

    // ⚠️ The role is `fileUrl`, NOT `fileURL`. Qt 6 renamed it, and asking for
    // the old name does not fail — it returns `undefined`, which becomes the
    // empty string here. Measured: every image in a folder of twelve came back
    // as "", so choosing a wallpaper would have stored nothing at all and the
    // picker would have looked merely unresponsive.
    function pathAt(i) {
        var u = dir.get(i, "fileUrl")
        return u ? String(u) : ""
    }

    function nameAt(i) {
        var n = dir.get(i, "fileName")
        return n ? String(n) : ""
    }

    // Where a given image sits in the listing, or 0 when it is not in the
    // folder at all — a wallpaper set by hand to a file somewhere else is
    // perfectly legal, and the picker should still open somewhere sensible
    // rather than refuse to place its cursor.
    function indexOf(url) {
        var want = String(url)
        for (var i = 0; i < dir.count; i++)
            if (root.pathAt(i) === want)
                return i
        return 0
    }

    // Choosing writes ONE key, and that is the whole persistence story: the
    // image on screen, the derived palette and every foreign application's
    // colours are all downstream of it, on this start and on the next one.
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
