// Do the icon names the shell uses actually exist in the icon font?
//
//   BUCHHWIN_ICONS=/tmp/names.txt BUCHHWIN_TOOL=icon-check \
//   QT_QPA_PLATFORM=offscreen qs -p shell
//
// This is not a question a linter can answer: `text: "logout"` is valid QML,
// valid QString, and renders — as the letters l-o-g-o-u-t. Fedora ships
// "Material Icons Round", the older set, and half the names people reach for
// are from "Material Symbols". Measured cost of finding that out on screen:
// one missing icon and one wrong one shipped in the session menu.
//
// The measurement is the width. A resolved ligature is a single glyph, about
// 0.7 em wide; an unresolved name is rendered letter by letter and comes out
// several times wider. At a 100 px font the two are never close: 68–92 px
// against 500 px for `logout` and 700 px for `restart_alt`.
import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"

Scope {
    id: root

    FileView { id: out; path: "/tmp/buchhwin-icon-check.txt" }
    FileView {
        id: input
        path: Quickshell.env("BUCHHWIN_ICONS") || "/tmp/buchhwin-icon-names.txt"
        blockLoading: true
        printErrors: true
    }

    TextMetrics { id: m; font.family: Theme.fontIcon; font.pixelSize: 100 }

    Timer {
        running: true
        interval: 400
        onTriggered: {
            var names = input.text().trim().split("\n").filter(function (n) {
                return n.trim().length > 0
            })
            var s = "icon font: " + Theme.fontIcon + "\n"
            var bad = 0
            for (var i = 0; i < names.length; i++) {
                var n = names[i].trim()
                m.text = n
                var w = m.width
                // 160 px is far above any real glyph and far below any
                // two-letter fallback, so the threshold never has to be tuned.
                if (w < 160) {
                    s += "  ok    " + n + "\n"
                } else {
                    s += "  FAIL  " + n + " — not in this font (" +
                         Math.round(w) + " px, a glyph is ~70)\n"
                    bad++
                }
            }
            s += (bad === 0 ? "all " + names.length + " icon names resolve\n"
                            : bad + " icon name(s) do not exist\n")
            out.setText(s)
            Qt.callLater(Qt.quit)
        }
    }
}
