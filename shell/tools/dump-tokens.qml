// Headless: print every token for the active palette.
//
//   QT_QPA_PLATFORM=offscreen qs -p shell/tools/dump-tokens.qml
//
// Used by CI ("every token resolves for every palette") and by anyone asking
// "where does this colour come from". Writes to /tmp/buchhwin-tokens.txt
// because console.log does not reach stdout under quickshell's default log
// rules — a tool that logs its findings reports nothing at all.

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../config"

Scope {
    id: root
    property string buf: ""
    function say(s) { buf += s + "\n"; out.setText(buf) }

    FileView { id: out; path: "/tmp/buchhwin-tokens.txt" }

    function row(name, value) {
        var pad = "                        ".substring(0, Math.max(0, 22 - name.length))
        say("  " + name + pad + value)
    }

    Component.onCompleted: {
        // Scheme loading is asynchronous; give it a beat rather than reading
        // an empty object and reporting a fallback as if it were the palette.
        settle.start()
    }

    Timer {
        id: settle
        interval: 600
        onTriggered: {
            say("palette      " + Scheme.name + "  (" + Scheme.displayName + ", family " +
                Scheme.family + ", dark=" + Scheme.dark + ", ready=" + Scheme.ready + ")")
            say("accent       " + Config.theme.accent)
            say("")
            say("SURFACE")
            row("bg", Theme.hex(Theme.bg));                 row("bgDim", Theme.hex(Theme.bgDim))
            row("bgDeep", Theme.hex(Theme.bgDeep));         row("surface", Theme.hex(Theme.surface))
            row("surfaceHigh", Theme.hex(Theme.surfaceHigh))
            row("surfaceHigher", Theme.hex(Theme.surfaceHigher))
            row("overlay", Theme.hex(Theme.overlay));       row("outline", Theme.hex(Theme.outline))
            say("")
            say("CONTENT")
            row("fg", Theme.hex(Theme.fg));                 row("fgMuted", Theme.hex(Theme.fgMuted))
            row("fgDim", Theme.hex(Theme.fgDim));           row("fgDisabled", Theme.hex(Theme.fgDisabled))
            say("")
            say("ACCENT + STATUS")
            row("accent", Theme.hex(Theme.accent));         row("accentFg", Theme.hex(Theme.accentFg))
            row("accentHover", Theme.hex(Theme.accentHover))
            row("accentActive", Theme.hex(Theme.accentActive))
            row("ok", Theme.hex(Theme.ok));                 row("warn", Theme.hex(Theme.warn))
            row("error", Theme.hex(Theme.error));           row("info", Theme.hex(Theme.info))
            row("errorFg", Theme.hex(Theme.errorFg));       row("warnFg", Theme.hex(Theme.warnFg))
            say("")
            say("ROLES (with alpha)")
            row("barBg", String(Theme.barBg));              row("panelBg", String(Theme.panelBg))
            row("pillBg", String(Theme.pillBg));            row("pillHover", String(Theme.pillHover))
            row("cardBg", String(Theme.cardBg));            row("scrim", String(Theme.scrim))
            row("shadow", String(Theme.shadow))
            say("")
            say("SHAPE / SPACING")
            row("radius xs..pill", [Theme.radiusXs, Theme.radiusSm, Theme.radiusMd,
                                    Theme.radiusLg, Theme.radiusXl, Theme.radiusPill].join(" "))
            row("borderWidth", Theme.borderWidth)
            row("space 1..6", [Theme.space1, Theme.space2, Theme.space3,
                               Theme.space4, Theme.space5, Theme.space6].join(" "))
            say("")
            say("TYPOGRAPHY / MOTION")
            row("fontUi", Theme.fontUi);                    row("fontMono", Theme.fontMono)
            row("fontIcon", Theme.fontIcon)
            row("sizes sm/base/lg/xl", [Theme.fontSizeSm, Theme.fontSize,
                                        Theme.fontSizeLg, Theme.fontSizeXl].join(" "))
            row("display size", Theme.fontSizeDisplay)
            row("weights", [Theme.weightNormal, Theme.weightMedium,
                            Theme.weightSemibold, Theme.weightBold].join(" "))
            row("durations", [Theme.durFast, Theme.durBase, Theme.durSlow].join(" "))
            row("effects/blur/shadow", [Theme.effects, Theme.blur, Theme.shadows].join(" "))
            say("")
            say("SANITY")
            // Two things that must never be true, checked here so a bad palette
            // fails a test instead of just looking slightly wrong.
            var bad = []
            if (Theme.hex(Theme.bg) === Theme.hex(Theme.fg)) bad.push("bg == fg")
            if (Math.abs(Theme.luminance(Theme.bg) - Theme.luminance(Theme.fg)) < 0.25)
                bad.push("bg/fg contrast too low")
            if (Theme.hex(Theme.accent) === "#ff00ff") bad.push("accent missing from palette")
            say(bad.length ? "  FAIL: " + bad.join(", ") : "  ok: contrast and accent resolve")
            Qt.callLater(Qt.quit)
        }
    }
}
