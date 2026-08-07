pragma ComponentBehavior: Bound

// Key bindings — all of them, searchable, and the one handle that unfreezes a
// machine.
//
// ⚠️ IT SHOWS RATHER THAN EDITS, AND THAT IS HIS DECISION rather than a corner
// cut. Rebinding needs a key-capture control, an action list checked against
// what niri actually has, and clash reporting — which is as much work as two
// ordinary pages, and it is the step after this one. What it must not be is
// nothing: sixty-three bindings that exist only in a source file are sixty-three
// things you have to read code to discover.
//
// ⚠️ AND "RESET" IS NOT A PROCESS CALL. `bhctl binds reset` exists and does this
// from a terminal, but from here the whole operation is writing an empty list:
// Config.qml treats an empty `binds` as "the built-in set", so emptying it IS
// restoring the defaults. Spawning bhctl to do one assignment would put a second
// writer on shell.json, which is the one thing that file does not have.
//
// ⚠️ THE FROZEN LIST IS A REAL FAILURE THIS PROJECT HAS SEEN. A shell.json once
// carried 63 bindings copied from the defaults of the day, because `binds` used
// to have those defaults inside the adapter — so "the file wins when it says
// anything at all" froze them forever, and every new default afterwards was
// invisible on that machine. Migration 7→8 removes such a copy when it is
// exactly ours; this is the button for when it is not.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../config"
import "../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space3

    // What the FILE says, as opposed to what is in force. Empty is the healthy
    // state and means "the built-in set".
    readonly property int frozen: {
        var b = Config.get("binds")
        return b && b.length ? b.length : 0
    }

    readonly property var shown: {
        var q = search.text.trim().toLowerCase()
        var out = []
        var all = Config.binds
        for (var i = 0; i < all.length; i++) {
            var b = all[i]
            if (q.length === 0
                || String(b.key).toLowerCase().indexOf(q) >= 0
                || String(b.desc).toLowerCase().indexOf(q) >= 0
                || String(b.action).toLowerCase().indexOf(q) >= 0)
                out.push(b)
        }
        return out
    }

    BarText {
        Layout.fillWidth: true
        text: "Key bindings"
        font.pixelSize: Theme.fontSizeSm
        font.weight: Theme.weightSemibold
        color: Theme.fgMuted
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space3

        TextField {
            id: search
            Layout.fillWidth: true
            placeholder: "Search bindings"
            onCancelled: search.text = ""
        }

        BarText {
            text: root.shown.length + " of " + Config.binds.length
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
        }
    }

    // Only when the file has its own copy. A button that says "restore
    // defaults" on a machine already running the defaults is a button that
    // teaches you it does nothing.
    ColumnLayout {
        Layout.fillWidth: true
        visible: root.frozen > 0
        spacing: Theme.space1

        BarText {
            Layout.fillWidth: true
            text: "This machine has its own copy of " + root.frozen
                + " bindings, so new built-in ones do not reach it."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.warn
            wrapMode: Text.WordWrap
        }

        Pill {
            interactive: true
            BarText { text: "Use the built-in bindings"; color: Theme.fg }
            onClicked: {
                Config.set("binds", [])
                Config.flush()
            }
        }

        BarText {
            Layout.fillWidth: true
            text: "Then run `bhctl niri apply` — bindings live in the generated niri config, "
                + "and a shell restart does not rewrite it."
            font.pixelSize: Theme.fontSizeSm
            color: Theme.fgMuted
            wrapMode: Text.WordWrap
        }
    }

    Repeater {
        model: root.shown

        RowLayout {
            id: bindRow
            required property var modelData

            Layout.fillWidth: true
            spacing: Theme.space3

            // The key itself in the monospace face, so Mod+Shift+comma and
            // Mod+Shift+period line up instead of drifting by a character.
            BarText {
                Layout.preferredWidth: Theme.space6 * 6
                text: String(bindRow.modelData.key)
                font.family: Theme.fontMono
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fg
            }
            BarText {
                Layout.fillWidth: true
                text: String(bindRow.modelData.desc)
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                elide: Text.ElideRight
            }
        }
    }

    // One sentence, per the brief — not an empty box.
    BarText {
        Layout.fillWidth: true
        visible: root.shown.length === 0
        text: "No binding matches that."
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }
}
