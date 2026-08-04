pragma Singleton

// Build a palette out of a wallpaper.
//
// The output is an ordinary palette — the same 26 semantic names every
// hand-written one has — so nothing downstream needs to know where it came
// from. That is the whole reason this is cheap to add: Theme.qml, the renderer,
// GTK, Qt, kitty and niri all keep working unchanged.
//
// Three decisions, each of which is the difference between a scheme you would
// use and one you would switch off after a day:
//
//  * The seed is the most CHROMATIC colour, not the most frequent. Measured on
//    a real photograph: the frequent colours come back as #6f5848, #4e4037,
//    #baaa9c — near-grey browns, because most of a photo is sky, wall or
//    shadow. A scheme built on those is mud.
//  * Surfaces are a tonal ramp at the seed's HUE with the seed's chroma cut
//    hard. Tinted greys read as "themed"; the seed colour used as a background
//    reads as a mistake.
//  * Meaning stays put. Error is red, warning is yellow, success is green —
//    pulled a little towards the image so they belong, never replaced by it.
//    A forest wallpaper must not make the error colour green.
//
// Whether the result is READABLE is not decided here. The caller runs the same
// SANITY checks a hand-written palette faces (bg == fg, contrast, missing
// accent) and refuses the wallpaper if it fails, rather than applying an
// unreadable desktop.

import QtQuick
import Quickshell

Singleton {
    id: root

    // --------------------------------------------------------------- colour
    // Hue in degrees, saturation and lightness 0..1. Qt.hsla() takes 0..1 hue.
    function _hsl(c) {
        var r = c.r, g = c.g, b = c.b
        var max = Math.max(r, g, b), min = Math.min(r, g, b)
        var l = (max + min) / 2
        var d = max - min
        if (d === 0)
            return { h: 0, s: 0, l: l }
        var s = l > 0.5 ? d / (2 - max - min) : d / (max + min)
        var h
        if (max === r) h = ((g - b) / d + (g < b ? 6 : 0)) / 6
        else if (max === g) h = ((b - r) / d + 2) / 6
        else h = ((r - g) / d + 4) / 6
        return { h: h, s: s, l: l }
    }

    function _mix(a, b, t) {
        return Qt.rgba(a.r + (b.r - a.r) * t,
                       a.g + (b.g - a.g) * t,
                       a.b + (b.b - a.b) * t, 1)
    }

    function _hex(c) {
        function h(v) {
            var s = Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)
            return s.length < 2 ? "0" + s : s
        }
        return h(c.r) + h(c.g) + h(c.b)
    }

    // A tone at the seed's hue: chroma deliberately low for surfaces, higher
    // for anything meant to be looked at.
    function _tone(hue, sat, light) {
        return Qt.hsla(hue, Math.max(0, Math.min(1, sat)),
                       Math.max(0, Math.min(1, light)), 1)
    }

    // --------------------------------------------------------------- seeding
    // The most chromatic colour that is not nearly black or nearly white.
    // Extremes carry a hue but no usable one — a highlight's hue is noise.
    function seedOf(colors) {
        var best = null, bestScore = -1
        for (var i = 0; i < colors.length; i++) {
            var hsl = _hsl(colors[i])
            if (hsl.l < 0.12 || hsl.l > 0.9)
                continue
            // Prefer saturation, but do not chase a single neon pixel: a mid
            // lightness is worth something too.
            var score = hsl.s * (1 - Math.abs(hsl.l - 0.5))
            if (score > bestScore) { bestScore = score; best = hsl }
        }
        // Every candidate was black, white or grey: fall back to a neutral hue
        // rather than inventing one.
        return best ? best : { h: 0, s: 0, l: 0.5 }
    }

    // ---------------------------------------------------------------- build
    // `dark` decides the direction of the ramp. It is the USER's setting, not
    // the image's: a bright photo must not turn a dark desktop light.
    function build(colors, dark, name) {
        if (!colors || colors.length === 0)
            return null

        var seed = seedOf(colors)
        var h = seed.h
        // Surfaces keep a trace of the hue and almost none of the chroma.
        var sSurface = Math.min(seed.s, 0.18)
        var sMuted = Math.min(seed.s, 0.30)
        var sAccent = Math.max(seed.s, 0.45)

        var out = {}
        function put(key, c) { out[key] = _hex(c) }

        if (dark) {
            put("crust",    _tone(h, sSurface, 0.07))
            put("mantle",   _tone(h, sSurface, 0.10))
            put("base",     _tone(h, sSurface, 0.13))
            put("surface0", _tone(h, sSurface, 0.18))
            put("surface1", _tone(h, sSurface, 0.23))
            put("surface2", _tone(h, sSurface, 0.28))
            put("overlay0", _tone(h, sMuted,   0.36))
            put("overlay1", _tone(h, sMuted,   0.45))
            put("overlay2", _tone(h, sMuted,   0.55))
            put("subtext0", _tone(h, sMuted,   0.68))
            put("subtext1", _tone(h, sMuted,   0.78))
            put("text",     _tone(h, 0.10,     0.90))
        } else {
            put("crust",    _tone(h, sSurface, 0.96))
            put("mantle",   _tone(h, sSurface, 0.93))
            put("base",     _tone(h, sSurface, 0.90))
            put("surface0", _tone(h, sSurface, 0.85))
            put("surface1", _tone(h, sSurface, 0.79))
            put("surface2", _tone(h, sSurface, 0.72))
            put("overlay0", _tone(h, sMuted,   0.62))
            put("overlay1", _tone(h, sMuted,   0.52))
            put("overlay2", _tone(h, sMuted,   0.44))
            put("subtext0", _tone(h, sMuted,   0.34))
            put("subtext1", _tone(h, sMuted,   0.26))
            put("text",     _tone(h, 0.12,     0.15))
        }

        var accentL = dark ? 0.62 : 0.42
        put("blue",      _tone(h, sAccent, accentL))
        put("sapphire",  _tone(h, sAccent, accentL + (dark ? 0.06 : -0.06)))
        put("sky",       _tone((h + 0.04) % 1, sAccent, accentL + 0.04))
        put("teal",      _tone((h + 0.08) % 1, sAccent, accentL))
        put("lavender",  _tone((h + 0.94) % 1, sAccent, accentL + 0.06))
        put("mauve",     _tone((h + 0.88) % 1, sAccent, accentL))
        put("pink",      _tone((h + 0.92) % 1, sAccent, accentL + 0.08))
        put("flamingo",  _tone((h + 0.96) % 1, Math.min(sAccent, 0.5), accentL + 0.1))
        put("rosewater", _tone(h, Math.min(sAccent, 0.35), accentL + 0.18))

        // Meaning first, image second. Each anchor is pulled a sixth of the way
        // towards the seed hue — enough to belong, not enough to lie.
        function anchored(anchorHue, sat, light) {
            var target = _tone(anchorHue, sat, light)
            var tinted = _tone(anchorHue + (h - anchorHue) / 6, sat, light)
            return _mix(target, tinted, 1.0)
        }
        put("red",    anchored(0.00, 0.65, dark ? 0.62 : 0.45))
        put("maroon", anchored(0.02, 0.55, dark ? 0.58 : 0.42))
        put("peach",  anchored(0.07, 0.65, dark ? 0.65 : 0.48))
        put("yellow", anchored(0.13, 0.65, dark ? 0.70 : 0.45))
        put("green",  anchored(0.30, 0.50, dark ? 0.60 : 0.40))

        return {
            name: name,
            family: "Wallpaper",
            display_name: "Aus dem Hintergrundbild",
            dark: dark,
            // The accent the shell picks by default. `blue` is the seed itself
            // — the name is inherited from the palette schema, not a claim
            // about the colour.
            accents: ["blue", "mauve", "teal", "peach", "green"],
            colors: out
        }
    }
}
