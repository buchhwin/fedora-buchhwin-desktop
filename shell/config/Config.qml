pragma Singleton

// The one place user settings live: ~/.config/buchhwin/shell.json.
//
// One file, one writer. The settings window writes through this adapter and
// nothing else touches the file, so there is no second format to keep in sync
// and no daemon in the middle. niri's own config.kdl is GENERATED from these
// values (see tools/render.qml) — it is an output, never an input.
//
// Every key has a default here. A missing file, a truncated file or a key that
// does not exist yet all resolve to the same working desktop, which is what
// makes it safe to add settings later without a migration for every one.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property alias look: adapter.look
    readonly property alias theme: adapter.theme
    readonly property alias surfaces: adapter.surfaces
    readonly property alias notch: adapter.notch
    readonly property alias bar: adapter.bar
    readonly property alias dock: adapter.dock

    readonly property bool loaded: file.loaded

    function save() { file.writeAdapter() }

    FileView {
        id: file
        path: Quickshell.env("XDG_CONFIG_HOME")
              ? Quickshell.env("XDG_CONFIG_HOME") + "/buchhwin/shell.json"
              : Quickshell.env("HOME") + "/.config/buchhwin/shell.json"
        watchChanges: true
        // Atomic: a settings write that is interrupted must not leave a
        // half-written file that the next start refuses to parse.
        atomicWrites: true
        onFileChanged: reload()
        // A parse failure must NOT overwrite the user's file with defaults.
        printErrors: true

        JsonAdapter {
            id: adapter

            property JsonObject theme: JsonObject {
                property string palette: "everforest-dark"
                property string accent: "green"
                // "" = follow `palette`; a name here switches on a schedule later.
                property string lightPalette: "everforest-light"
            }

            property JsonObject look: JsonObject {
                property int rounding: 12          // every radius derives from this
                property int borderWidth: 0        // 0: no window borders anywhere
                property int gapsIn: 6
                property int gapsOut: 10
                property real opacityActive: 1.0
                property real opacityInactive: 0.96
                property real opacityPanel: 0.88   // translucency the blur sits behind
                property bool blur: true
                property bool shadows: true
                property string fontUi: "Inter"
                property string fontMono: "JetBrainsMono Nerd Font"
                property string fontIcon: "Material Symbols Rounded"
                property int fontSize: 11          // pt
                // full | minimal — minimal turns motion and effects off wholesale
                property string profile: "full"
            }

            // Every surface can be switched off on its own, and limited to
            // named monitors. An empty list means "all screens".
            property JsonObject surfaces: JsonObject {
                property bool notifications: true
                property bool osd: true
                property bool dock: false
            }

            property JsonObject bar: JsonObject {
                property bool enabled: true
                property int height: 34
                property list<string> monitors: []
            }

            property JsonObject notch: JsonObject {
                property bool enabled: true
                property int flare: 14             // the concave shoulder radius
                property int collapsedWidth: 150
                property int expandedHeight: 135
                property int minExpandedWidth: 619
                property list<string> monitors: []
            }

            property JsonObject dock: JsonObject {
                property int iconSize: 40
                property list<string> pinned: []
                property list<string> monitors: []
            }
        }
    }
}
