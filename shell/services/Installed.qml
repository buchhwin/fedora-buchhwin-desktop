pragma Singleton

// What is actually installed on this machine: cursor themes, fonts, keyboard
// layouts.
//
// ⚠️ IT EXISTS BECAUSE A TEXT BOX IS THE WRONG QUESTION. The settings window
// asked you to TYPE a cursor theme, and his report was short: "bei den cursorn    english-ok: the report, quoted
// gibt es aktuell keine auswahl nur eine texteingabe was falsch ist". He is       english-ok: the report, quoted
// right, and the proof is in the defaults: `cursor.theme` ships as
// "Breeze_Dark", and this machine has Adwaita, breeze_cursors, Breeze_Light and
// McMojave-cursors — no Breeze_Dark at all. A field you type into cannot tell
// you that; a list cannot avoid telling you.
//
// ⚠️ NOTHING RUNS UNTIL SOMETHING ASKS. `scan()` is called by the settings
// pages that need it, once per shell life. An idle desktop must not be listing
// fonts, and `fc-list` on a machine with 133 families is not free.
//
// ⚠️ ONE PROCESS, NOT FOUR. Each of these is a one-line shell command; spawning
// four processes to answer one question is the shape this project keeps finding
// in its own code (a `ps` per row, a render per key). The answers are separated
// by markers instead.
import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    readonly property bool ready: root._done
    property bool _done: false
    property bool _running: false

    // Sorted, de-duplicated, and empty until asked.
    property var cursorThemes: []
    property var fonts: []
    property var monoFonts: []
    property var keyboardLayouts: []
    property var keyboardVariants: []

    function scan() {
        if (root._done || root._running)
            return
        root._running = true
        proc.running = true
    }

    Process {
        id: proc
        // ⚠️ The cursor directories are the DIRECTORIES THAT CONTAIN a
        // `cursors` folder — that is what makes a theme a cursor theme rather
        // than an icon theme, and it is why `Adwaita` appears here while most
        // of /usr/share/icons does not.
        //
        // `:spacing=100` is fontconfig's own word for monospaced. Asking it
        // beats keeping a list of names that would be wrong on the next
        // machine.
        command: ["sh", "-c", `
            echo "--cursors"
            for d in /usr/share/icons "$HOME/.icons" "$HOME/.local/share/icons"; do
                [ -d "$d" ] || continue
                find "$d" -maxdepth 2 -name cursors -type d 2>/dev/null
            done | sed 's|/cursors$||' | while read -r p; do basename "$p"; done | sort -u
            echo "--fonts"
            fc-list : family 2>/dev/null | tr ',' '\\n' | sed 's/^ *//; s/ *$//' \\
                | grep -v '^$' | sort -u
            echo "--mono"
            fc-list :spacing=100 : family 2>/dev/null | tr ',' '\\n' | sed 's/^ *//; s/ *$//' \\
                | grep -v '^$' | sort -u
            echo "--layouts"
            awk '/^! layout/{f=1;next} /^!/{f=0} f&&NF{print $1}' \\
                /usr/share/X11/xkb/rules/base.lst 2>/dev/null | sort -u
            echo "--variants"
            awk '/^! variant/{f=1;next} /^!/{f=0} f&&NF{print $1}' \\
                /usr/share/X11/xkb/rules/base.lst 2>/dev/null | sort -u
            echo "--end"
        `]
        stdout: StdioCollector { id: collected }

        onExited: function (code) {
            root._running = false
            var buckets = { "cursors": [], "fonts": [], "mono": [],
                            "layouts": [], "variants": [] }
            var cur = ""
            var lines = String(collected.text || "").split("\n")
            for (var i = 0; i < lines.length; i++) {
                var ln = lines[i]
                if (ln.indexOf("--") === 0) {
                    cur = ln.substring(2)
                    continue
                }
                if (cur.length > 0 && buckets[cur] !== undefined && ln.length > 0)
                    buckets[cur].push(ln)
            }
            root.cursorThemes = buckets.cursors
            root.fonts = buckets.fonts
            root.monoFonts = buckets.mono
            root.keyboardLayouts = buckets.layouts
            root.keyboardVariants = buckets.variants
            // ⚠️ `_done` even on a non-zero exit, and even on an empty answer.
            // A machine without fontconfig is a machine where the list stays
            // empty and the field stays typable — retrying forever would be a
            // process that never stops on exactly the machine that can least
            // afford one.
            root._done = true
        }
    }
}
