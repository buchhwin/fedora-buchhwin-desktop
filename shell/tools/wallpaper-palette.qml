// Derive a palette from the current wallpaper and put it where Scheme looks.
//
//   BUCHHWIN_TOOL=wallpaper-palette QT_QPA_PLATFORM=offscreen qs -p shell
//
// It writes `theme/palettes/wallpaper.json` — the same folder every shipped
// palette lives in — so Scheme finds it through the path it already has. An
// earlier attempt gave Scheme a second, user-first search path instead; that
// broke loading for ALL palettes twice over and was reverted. Writing where the
// reader already looks needs no reader changes at all, which is the whole point.
//
// ⚠️ The quantiser emits once with the PREVIOUS image's colours when a new
// source is set. Reading on the first `colorsChanged` therefore records the
// wrong picture's palette — measured, and it looked like twelve wallpapers
// producing six schemes. So the value is read after a wait, not on the signal.
//
// The result is refused rather than applied when it would be unreadable: the
// same two checks a hand-written palette faces, so a wallpaper that cannot make
// a usable scheme leaves the current one alone.

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../config"
import "../common"

Scope {
    id: root

    property string report: ""
    function note(s) { report += s + "\n"; log.setText(report) }

    FileView { id: log; path: "/tmp/buchhwin-wallpaper-palette.log" }
    FileView { id: out; blockLoading: true; printErrors: false }

    readonly property string target:
        Quickshell.shellPath("theme/palettes/wallpaper.json")

    ColorQuantizer {
        id: quant
        // 64 is plenty: the seed is a hue, and a hue does not get truer with
        // more pixels. Measured at ~40 ms for a 6000x3750 image.
        rescaleSize: 64
        depth: 4
    }

    // Contrast, the way dump-tokens checks it — the one number that decides
    // whether a scheme is readable at all.
    function luminance(hex) {
        function ch(v) {
            v = v / 255
            return v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4)
        }
        var r = ch(parseInt(hex.substring(0, 2), 16))
        var g = ch(parseInt(hex.substring(2, 4), 16))
        var b = ch(parseInt(hex.substring(4, 6), 16))
        return 0.2126 * r + 0.7152 * g + 0.0722 * b
    }

    function usable(pal) {
        var c = pal.colors
        if (c.base === c.text)
            return "background and text are the same colour"
        if (Math.abs(luminance(c.base) - luminance(c.text)) < 0.25)
            return "background and text do not contrast enough"
        if (!c.blue || !c.red || !c.green)
            return "the palette is missing a colour"
        return ""
    }

    WaitFor {
        condition: Config.settled

        onTimedOut: {
            note("ABORT: the configuration never settled")
            Qt.callLater(Qt.quit)
        }

        onReady: {
            var wp = String(Config.wallpaper.current)
            if (!wp.length) {
                note("ABORT: no wallpaper is set (wallpaper.current is empty)")
                Qt.callLater(Qt.quit)
                return
            }
            note("buchhwin wallpaper-palette — " + wp)
            quant.source = wp
            settle.start()
        }
    }

    Timer {
        id: settle
        interval: 1800
        onTriggered: {
            if (!quant.colors || quant.colors.length === 0) {
                note("ABORT: no colours came back — is the format supported? " +
                     "(this Qt has no WebP and no TIFF plugin)")
                Qt.callLater(Qt.quit)
                return
            }

            var pal = FromImage.build(quant.colors, Scheme.dark, "wallpaper")
            if (!pal) {
                note("ABORT: could not build a palette")
                Qt.callLater(Qt.quit)
                return
            }

            var why = usable(pal)
            if (why.length) {
                // Leaving the previous scheme in place is the right answer: an
                // unreadable desktop is worse than one that did not change.
                note("REFUSED: " + why)
                note("  the current palette is left alone")
                Qt.callLater(Qt.quit)
                return
            }

            out.path = root.target
            out.setText(JSON.stringify(pal, null, 2) + "\n")
            note("  seed #" + pal.colors.blue +
                 "  surface #" + pal.colors.base +
                 "  text #" + pal.colors.text)
            note("  wrote " + root.target)
            note("done — set theme.palette to \"wallpaper\" to use it")
            Qt.callLater(Qt.quit)
        }
    }
}
