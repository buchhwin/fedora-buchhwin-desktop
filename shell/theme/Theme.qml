pragma Singleton

// The design tokens. This is the single place a colour, a radius, a spacing
// step, a duration or a font is decided — for the shell AND for every foreign
// application we theme (see tools/render.qml).
//
// Nothing else in the project may contain a literal colour or radius. CI
// enforces that, because "keep it consistent" survives about three weeks
// without a machine checking it.
//
// Everything here is derived from two inputs: the 26-name palette and the
// handful of numbers in Config.look. Change the palette and the whole desktop
// follows, including GTK, Qt, kitty, niri and the greeter.

import QtQuick
import Quickshell
import "../config"
import "."

Singleton {
    id: root

    // ---------------------------------------------------------------- helpers

    // Lightness steps in HSL, not Qt.lighter/darker: those scale VALUE, which
    // on an already-dark surface barely moves and on a saturated accent shifts
    // the hue's apparent colour. A flat lightness delta behaves the same on
    // every palette, which is the whole point of having nine of them.
    function shift(c, delta) {
        var col = Qt.color(c)
        var l = Math.max(0, Math.min(1, col.hslLightness + delta))
        return Qt.hsla(col.hslHue, col.hslSaturation, l, col.a)
    }
    function lighten(c, d) { return shift(c, d) }
    function darken(c, d)  { return shift(c, -d) }

    function alpha(c, a) {
        var col = Qt.color(c)
        return Qt.rgba(col.r, col.g, col.b, a)
    }

    // Perceived brightness, weighted the way an eye actually works — green
    // carries most of it. Used to pick a foreground that stays readable on any
    // accent, including the light palettes where white-on-accent is unreadable.
    function luminance(c) {
        var col = Qt.color(c)
        return Math.sqrt(0.299 * col.r * col.r +
                         0.587 * col.g * col.g +
                         0.114 * col.b * col.b)
    }
    // ⚠️ A NAME, because the renderer has to apply the same rule against a
    // DIFFERENT colour set. Theme is bound to the one active Scheme, so
    // Theme.on() always answers out of the system palette — which is the wrong
    // answer when a single program is being themed neutral grey. The renderer
    // therefore reimplements the choice, and reads the threshold from here so
    // there is one number rather than two that drift.
    readonly property real onThreshold: 0.55
    function on(c) { return luminance(c) > onThreshold ? p("crust") : p("text") }

    function p(key) { return Scheme.color(key) }

    readonly property bool dark: Scheme.dark
    // Elevation moves one way on dark palettes and the other on light ones.
    readonly property real lift: dark ? 0.04 : -0.04

    // ----------------------------------------------------------------- colour

    readonly property color bg:            p("base")
    readonly property color bgDim:         p("mantle")
    readonly property color bgDeep:        p("crust")
    readonly property color surface:       p("surface0")
    readonly property color surfaceHigh:   p("surface1")
    readonly property color surfaceHigher: p("surface2")
    readonly property color overlay:       p("overlay0")
    readonly property color outline:       p("overlay1")
    readonly property color outlineStrong: p("overlay2")

    readonly property color fg:         p("text")
    readonly property color fgMuted:    p("subtext1")
    readonly property color fgDim:      p("subtext0")
    readonly property color fgDisabled: p("overlay2")

    readonly property color accent:       p(Config.theme.accent)
    readonly property color accentFg:     on(accent)
    readonly property color accentHover:  lighten(accent, 0.06)
    readonly property color accentActive: darken(accent, 0.06)
    readonly property color accentAlt:    p("teal")

    readonly property color ok:      p("green")
    readonly property color warn:    p("yellow")
    readonly property color error:   p("red")
    readonly property color info:    p("sapphire")
    readonly property color okFg:    on(ok)
    readonly property color warnFg:  on(warn)
    readonly property color errorFg: on(error)
    readonly property color infoFg:  on(info)

    // Role colours. These carry the translucency, so a component never writes
    // an alpha value itself — that is how six different "panel background"
    // opacities crept into the old stack.
    readonly property real panelOpacity: Config.look.opacityPanel

    // The terminal's own background transparency, written into kitty's config.
    // Separate from panelOpacity on purpose: a panel sits over a wallpaper and
    // wants to stay legible, a terminal sits over whatever is behind it and is
    // read as a foreground object regardless.
    readonly property real terminalOpacity: Config.look.opacityTerminal
    readonly property color barBg:     alpha(bgDeep, panelOpacity)
    readonly property color panelBg:   alpha(bgDeep, panelOpacity + 0.06)
    readonly property color pillBg:    alpha(surface, panelOpacity)
    readonly property color pillHover: alpha(surfaceHigh, panelOpacity + 0.08)
    readonly property color cardBg:    alpha(surface, 0.92)
    readonly property color cardHover: alpha(surfaceHigh, 0.96)
    readonly property color menuBg:    alpha(bgDim, panelOpacity + 0.08)
    readonly property color menuSelBg: accent
    readonly property color menuSelFg: accentFg
    readonly property color scrim:     alpha(bgDeep, 0.55)
    readonly property color shadow:    alpha("#000000", dark ? 0.45 : 0.18)

    // ----------------------------------------------------------------- glass
    //
    // What makes a translucent panel read as a pane of glass rather than as a
    // tinted rectangle is its EDGE, not its middle. The middle is blur, and the
    // compositor already does that — for free, once, via xray. So these four
    // tokens describe a rim and a sheen and nothing else.
    //
    // ⚠️ Deliberately NOT a shader. Refraction needs to sample what lies behind
    // the window, and a layer surface cannot see that — only the compositor
    // can. A shader here would have to draw and blur its own copy of the
    // wallpaper to refract, duplicating the one thing niri already does
    // cheaply, and paying for it every frame on a laptop. A gradient costs one
    // draw and no per-frame work.
    //
    // ⚠️ TWO TOKENS, NOT FOUR. There were a top and a side rim as well, drawn as
    // a gradient ring behind every pane. On screen that reads as a border, and
    // it was reported as one; the reference screenshots have no ring at all,
    // only "a fine lighter line along the bottom edge". They are deleted rather
    // than set to transparent, because a token with no reader is the same debt
    // as a config key with no reader — see GlassPane.qml.
    //
    // What is left is the light bouncing back up through the pane, which is the
    // most recognisable part of the look and the cheapest part to draw.
    readonly property color glassRimBottom: alpha(fg, dark ? 0.18 : 0.26)
    // The sheen lies over the top of the pane and fades out well before the
    // middle. Any further and it stops reading as light and starts reading as
    // a lighter background.
    readonly property color glassSheen:     alpha(fg, dark ? 0.07 : 0.10)

    // ----------------------------------------------------------------- shape

    readonly property int r: Config.look.rounding
    readonly property int radiusXs:   Math.round(r * 0.33)
    readonly property int radiusSm:   Math.round(r * 0.5)
    readonly property int radiusMd:   r
    readonly property int radiusLg:   Math.round(r * 1.33)
    readonly property int radiusXl:   Math.round(r * 1.66)
    readonly property int radiusPill: 999

    readonly property int borderWidth: Config.look.borderWidth

    // One device pixel at scale 1, and the width of the glass rim. It is a
    // token rather than a bare 1 so the tripwire stays honest and so a future
    // "thicker edges" setting has one place to land.
    readonly property int hairline: 1

    // ---------------------------------------------------------------- spacing
    // One 4px grid. No "about ten pixels" anywhere.
    readonly property int space1: 4
    readonly property int space2: 8
    readonly property int space3: 12
    readonly property int space4: 16
    readonly property int space5: 24
    readonly property int space6: 32

    // ------------------------------------------------------------- typography

    readonly property string fontUi:   Config.look.fontUi
    readonly property string fontMono: Config.look.fontMono
    readonly property string fontIcon: Config.look.fontIcon
    readonly property int fontSizePt:  Config.look.fontSize
    // pt -> px at the 96dpi Qt assumes; the compositor handles real scaling.
    readonly property int fontSize:    Math.round(fontSizePt * 4 / 3)
    readonly property int fontSizeSm:  Math.round(fontSize * 0.86)
    readonly property int fontSizeLg:  Math.round(fontSize * 1.15)
    readonly property int fontSizeXl:  Math.round(fontSize * 1.45)
    readonly property int fontSizeDisplay: Math.round(fontSize * 5.2)

    // Four weights, no interpolation. Fedora's quickshell has no
    // DropExpensiveFonts escape hatch, and every distinct variable-font axis
    // value materialises its own rasterised face in memory.
    readonly property int weightNormal:   400
    readonly property int weightMedium:   500
    readonly property int weightSemibold: 600
    readonly property int weightBold:     700

    // ---------------------------------------------------------------- motion
    // Calm: three durations, one curve, no overshoot anywhere. Motion explains
    // a state change; if there is no state change there is no motion.
    // Something that is still there but no longer the thing you are looking at
    // — the launcher's category column while a search is running. A token
    // rather than a number typed where it is needed, for the same reason every
    // colour is: one dimmed thing and another dimmed thing have to match.
    readonly property real dimmed: 0.45

    readonly property bool animate: Config.look.profile !== "minimal"
    readonly property int durFast: animate ? 120 : 0
    readonly property int durBase: animate ? 200 : 0
    readonly property int durSlow: animate ? 320 : 0
    readonly property int easing: Easing.OutCubic

    readonly property bool effects: Config.look.profile !== "minimal"
    readonly property bool blur:    Config.look.blur && effects
    readonly property bool shadows: Config.look.shadows && effects
    readonly property bool glass:   Config.look.glass && effects

    // ------------------------------------------------------------------ misc
    // Hex without alpha, for the foreign config files that cannot take rgba.
    function hex(c) {
        var col = Qt.color(c)
        function h(v) { var s = Math.round(v * 255).toString(16); return s.length < 2 ? "0" + s : s }
        return "#" + h(col.r) + h(col.g) + h(col.b)
    }
    function hexNoHash(c) { return hex(c).substring(1) }
}
