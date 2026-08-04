pragma Singleton

// The active colour palette.
//
// A palette is 26 semantic colour names — see palettes/SCHEMA.md. They are the
// only hand-authored colour data in the project; everything visible is derived
// from them in Theme.qml. Drop a JSON file in palettes/ and it appears
// everywhere, with no code change.
//
// Loading is asynchronous. Anything that reads `colors` before `ready` turns
// true gets the fallback below, never an error and never a blank screen — a
// desktop that cannot draw because a file was slow is not a desktop.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // Bound to the user's choice, not merely documented as such.
    //
    // This was a plain "everforest-dark" until M2, and the comment claimed
    // Config wrote it — nothing did. Changing theme.palette in shell.json was
    // therefore a no-op, and tests/all-palettes.sh passed vacuously: it loaded
    // Everforest eleven times and, because every palette's first accent is one
    // of the 26 names Everforest also defines, never saw the magenta sentinel.
    //
    // It stays a binding rather than a readonly alias so a headless tool can
    // still assign over it — an assignment breaks the binding, which is exactly
    // the escape hatch the old comment wanted.
    property string name: Config.theme.palette || "everforest-dark"

    // Honest readiness: the data is what matters, not the file object's state
    // — and it must be the data for the palette we are asking about NOW.
    //
    // Checking only `_data.colors` had a race: `name` is bound to the config,
    // so it changes from the default to the user's choice a few milliseconds
    // in. Between those two moments the old palette's data is still loaded and
    // `ready` would say true while `name` already named a different palette.
    // Anything that sampled it there wrote one palette's colours under another
    // palette's name.
    readonly property bool ready: !!_data.colors && _loadedName === root.name
    property string _loadedName: ""

    // Why it is not ready, for a tool that has to explain itself rather than
    // exit quietly. Empty while everything is fine.
    property string failure: ""
    readonly property var colors: _data.colors || fallback
    readonly property string family: _data.family || "Everforest"
    readonly property string displayName: _data.display_name || root.name
    readonly property bool dark: _data.dark !== undefined ? _data.dark : true
    readonly property var accents: _data.accents || ["green"]

    property var _data: ({})

    // Everforest Dark, inlined. Not a second source of truth — a raft. If the
    // palette file is missing or malformed the shell still has readable
    // colours, and `ready` stays false so the settings UI can say so.
    readonly property var fallback: ({
        "rosewater": "e69875", "flamingo": "e69875", "pink": "d699b6",
        "mauve": "d699b6", "red": "e67e80", "maroon": "e67e80",
        "peach": "e69875", "yellow": "dbbc7f", "green": "a7c080",
        "teal": "83c092", "sky": "83c092", "sapphire": "7fbbb3",
        "blue": "7fbbb3", "lavender": "d699b6", "text": "d3c6aa",
        "subtext1": "9da9a0", "subtext0": "859289", "overlay2": "7a8478",
        "overlay1": "56635f", "overlay0": "4f585e", "surface2": "475258",
        "surface1": "3d484d", "surface0": "343f44", "base": "2d353b",
        "mantle": "232a2e", "crust": "232a2e"
    })

    // "#rrggbb" for a semantic name, with the fallback behind it so a palette
    // that is missing a key degrades to a colour instead of to `undefined`,
    // which QML would render as black.
    function hex(key) {
        var c = root.colors[key] || root.fallback[key]
        return c ? "#" + c : "#ff00ff"      // magenta: impossible to miss in review
    }

    function color(key) { return Qt.color(hex(key)) }

    // Every palette that ships, for the settings window and `bhctl theme`.
    // Read from disk rather than listed here — a list would go stale the first
    // time somebody adds a file.
    readonly property list<string> available: dir.text().trim().length
        ? dir.text().trim().split("\n") : [root.name]

    FileView {
        id: file
        path: Quickshell.shellPath("theme/palettes/" + root.name + ".json")
        watchChanges: true
        // Loud on purpose. This failing silently is exactly how the whole
        // desktop ran on fallback colours without anyone noticing.
        printErrors: true
        onFileChanged: reload()
        onLoaded: {
            try {
                root._data = JSON.parse(text())
                root._loadedName = root.name
                root.failure = ""
            } catch (e) {
                // A palette that is present but malformed is a different fault
                // from one that is missing, and the difference is what someone
                // needs in order to fix it.
                root._data = ({})
                root._loadedName = ""
                root.failure = "palette '" + root.name + "' is not valid JSON: " + e
            }
        }
        onLoadFailed: {
            root._data = ({})
            root._loadedName = ""
            root.failure = "palette '" + root.name + "' could not be read from " + path
        }
    }

    // Written by the installer (a plain `ls` of the palette folder). Absent on
    // a source checkout, which is normal and not worth a warning on every
    // start — hence printErrors off.
    FileView {
        id: dir
        path: Quickshell.shellPath("theme/palettes/index.txt")
        printErrors: false
    }
}
