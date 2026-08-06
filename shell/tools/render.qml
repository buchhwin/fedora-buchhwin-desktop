// The renderer: writes every foreign application's colours, fonts and radii
// from the same tokens the shell draws itself with.
//
//   BUCHHWIN_TOOL=render QT_QPA_PLATFORM=offscreen qs -p shell
//
// This is what makes "change the palette, everything follows" true rather than
// aspirational. It runs in three situations and is the SAME code every time:
//
//   * during installation, before any session exists (headless)
//   * whenever the palette or a look setting changes (from the running shell)
//   * from `bhctl theme`, as a repair
//
// There is deliberately no template engine and no second renderer in bash.
// One writer, one set of tokens, no drift.
//
// EACH PROGRAM IS THEMED ON ITS OWN, in one of three states (config/Config.qml):
//
//   colour    the system's colours, whatever theme.palette says
//   neutral   a grey scheme — themed, but colourless. The semantic colours
//             stay anchored, so an error still reads as an error.
//   off       we write a stub that overrides nothing, and say so in it
//
// The two colour sets come from the SAME generator: theme/FromImage.qml builds
// every palette from (hue, saturation, dark), so "neutral" is that function
// with saturation zero. Not a second palette format and not a second look —
// one generator, one consumer, a different seed.
//
// Note the GTK caveat, which is written into the generated files too: setting
// gtk-decoration-layout to ":" removes the three window buttons, but a
// libadwaita headerbar is application CONTENT and stays. We remove the
// buttons, not the bar, and we say so instead of pretending.

import QtQuick
import Quickshell
import Quickshell.Io
import "../theme"
import "../config"
import "../common"

Scope {
    id: root

    readonly property string home: Quickshell.env("HOME")
    readonly property string cfg: Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")

    property string report: ""
    property int written: 0
    property int unchanged: 0

    function note(s) { report += s + "\n"; log.setText(report) }

    // ⚠️ SAY THAT WE STARTED, BEFORE ANYTHING CAN GO WRONG.
    //
    // note() overwrites the log rather than appending, so the file describes
    // one run — but only from the FIRST note(), and until now that was inside
    // WaitFor's onReady. A process that died before ever getting there (a QML
    // load error, a segfault) left the PREVIOUS run's text lying there, and
    // every reader treats that file as this run's result: bin/bhctl greps it
    // for ABORT, lib/common.sh reports from it, tests/reachable.sh is a wrapper
    // around both. That is not theory — it cost a whole attempt at the
    // per-target states, where "the renderer aborted" was read off a stale log
    // and the real failure was never seen.
    //
    // With this line a log that ends at "start" is a crash, a log that ends at
    // "ABORT" is a refusal, and a log that ends at "done" is a run. Three
    // distinguishable outcomes, one file write on tmpfs.
    Component.onCompleted: note("buchhwin render — start")

    // Every file goes through here so that "what did the renderer touch" is a
    // single list, and so a failure is reported rather than swallowed.
    //
    // ⚠️ IT COMPARES FIRST. This used to write every file on every run, and the
    // plan is explicit that "a second installation run changes no file" — which
    // was simply not true. It matters beyond tidiness: a program watching its
    // own config reloads on every write, so an unchanged rewrite is a reload
    // for nothing, and `bhctl theme apply` on an unchanged palette touched
    // seven files' mtimes. tools/niri.qml has done it this way from the start,
    // because niri live-reloads and the cost was immediately visible there.
    //
    // `blockLoading` on the views is what makes reading and writing possible in
    // the same statement.
    function write(view, path, text, label) {
        view.path = path
        if (view.text() === text) {
            unchanged++
            note("  same   " + label)
            return
        }
        view.setText(text)
        written++
        note("  wrote  " + label + "  ->  " + path)
    }

    // ------------------------------------------------------------ the states
    //
    // ⚠️ AN EXPLICIT SWITCH, not Config.theming[target]. Dynamic field access
    // on a JsonObject returns undefined — measured — and an undefined that
    // falls through an else would switch off programs nobody switched off.
    //
    // ⚠️ `enabled === false`, not `!enabled`. If the key ever came back
    // undefined, `!undefined` would turn everything off AND clean up after
    // itself. The direction a doubtful case falls in is not symmetric here.
    //
    // ⚠️ An unrecognised value becomes "colour", NEVER "off", for the same
    // reason: a typo in shell.json must not remove configuration.
    //
    // Only called from onReady. Nothing here may run during construction —
    // see the note there.
    function stateOf(target) {
        var g = Config.theming
        if (g.enabled === false)
            return "off"

        var v
        switch (target) {
        case "gtk":       v = g.gtk;       break
        case "qt":        v = g.qt;        break
        case "kitty":     v = g.kitty;     break
        case "niri":      v = g.niri;      break
        case "alacritty": v = g.alacritty; break
        case "btop":      v = g.btop;      break
        case "bat":       v = g.bat;       break
        case "fastfetch": v = g.fastfetch; break
        case "delta":     v = g.delta;     break
        case "tmux":      v = g.tmux;      break
        case "starship":  v = g.starship;  break
        case "lazygit":   v = g.lazygit;   break
        case "vscode":    v = g.vscode;    break
        default:          v = "inherit"
        }

        var s = String(v === undefined || v === null ? "" : v)
        if (s === "" || s === "inherit")
            s = String(g.mode || "colour")
        if (s !== "neutral" && s !== "off") {
            if (s !== "colour")
                note("  WARN   unknown state '" + s + "' for " + target + " — using colour")
            s = "colour"
        }
        return s
    }

    // The grey colour set. Built ONCE, as the first thing onReady does.
    //
    // ⚠️ NOT A BINDING, and the crash is only the third reason.
    //  1. FromImage.neutral() needs `dark`, and Theme.dark reads `true` until
    //     the palette has loaded (Scheme.qml). A property evaluated at
    //     creation would bake a DARK grey set onto latte and everforest-light.
    //  2. Holding one object guarantees all seven files come out of the same
    //     calculation even if the palette reloads mid-run.
    //  3. Reading JsonAdapter properties while the adapter is still
    //     deserialising is the shape that segfaults quickshell — ui/Shell.qml
    //     and services/Theming.qml both document it.
    // FromImage.neutral() is pure and does no I/O, so building it costs
    // nothing worth saving.
    property var neutralPal: null

    // A colour in the chosen state, as "#rrggbb".
    //
    // `key` is a PALETTE key, not a role name: theme/Theme.qml maps every role
    // straight onto one, so there is nothing to invent here — and a second
    // vocabulary for the same colour is the drift this project exists to
    // avoid. tools/smoke.qml checks the two agree.
    //
    // ⚠️ THE PALETTE STORES HEX WITHOUT THE HASH ("base": "212121"), and
    // Scheme.hex() is what puts it back. Reading colors[key] straight out of a
    // palette object and handing it to Qt.color() yields an invalid colour,
    // and the TypeError lands in whichever builder touches it first.
    function col(mode, key) {
        if (mode === "neutral") {
            var h = root.neutralPal ? root.neutralPal.colors[key] : ""
            if (h)
                return Theme.hex(Qt.color("#" + h))
            note("  WARN   the neutral set has no '" + key + "' — using the system colour")
        }
        return Theme.hex(Scheme.color(key))
    }

    // The same rule as Theme.on(), applied to the chosen colour set. Theme.on()
    // always answers out of the ACTIVE palette, which is the wrong answer for a
    // program being themed grey while the system is in colour.
    function onColour(mode, c) {
        return Theme.luminance(c) > Theme.onThreshold ? col(mode, "crust") : col(mode, "text")
    }

    // The accent — the one colour whose KEY comes from the settings.
    //
    // ⚠️ In the neutral set the configured accent is NOT usable. Five of the
    // accent names — red, maroon, peach, yellow, green — are ANCHORED in
    // FromImage and stay coloured at saturation zero, on purpose, so that an
    // error still reads as an error. Measured in the generated neutral.json:
    // green is #99cc66, while blue, mauve, teal and sapphire all come out
    // grey. So "neutral" with accent "green" — which is this project's own
    // default — would have produced a green desktop called neutral.
    // The neutral accent is the seed itself, `blue`.
    function accentOf(mode) { return col(mode, mode === "neutral" ? "blue" : Config.theme.accent) }
    function accentFgOf(mode) { return onColour(mode, Qt.color(accentOf(mode))) }

    // ⚠️ The state belongs IN the generated file, and not only for the reader:
    // it guarantees that switching colour ↔ neutral always produces a
    // difference write() can see, even for a palette whose colours happen to
    // be grey already.
    function head(hash, mode) {
        var c = hash ? "#" : " *"
        return (hash ? "" : "/*\n") +
            c + " Generated by buchhwin from palette '" + Scheme.name + "'" +
            (mode === "neutral" ? ", neutral (themed, but colourless)" : "") + ".\n" +
            c + " Do not edit — regenerated on every palette or look change.\n" +
            (hash ? "" : " */\n")
    }

    // "off" means CLEAN UP, not skip (see config/Config.qml). Cleaning up here
    // means a stub that overrides nothing — not a deletion.
    //
    // ⚠️ FileView has no delete, and that is not an obstacle but the better
    // answer: kitty.conf `include`s theme.conf and niri's config.kdl includes
    // colors.kdl. A deleted file is a pointer into nothing; a file of nothing
    // but comments is exactly as ineffective for both readers — and says why.
    // Measured for the one case where "ineffective" was not obvious: qt6ct
    // falls back to the style's palette for a colour file with no
    // active_colors, byte-identical to having no qt6ct at all.
    //
    // It goes through the same write(), so "a second run changes no file"
    // still holds and there is still one list of what the renderer touched.
    function offText(c, target) {
        return c + " Generated by buchhwin: theming is OFF for '" + target + "'.\n" +
               c + " Nothing in this file overrides anything.\n" +
               c + " It is left in place rather than deleted, so the include\n" +
               c + " that reads it does not point at nothing.\n" +
               c + " Set theming." + target + " to \"inherit\", \"colour\" or\n" +
               c + " \"neutral\" in shell.json to fill it again.\n"
    }
    function offCss(target) { return "/*\n" + offText(" *", target) + " */\n" }

    // One file, one state. The try/catch does not swallow anything — it
    // TRANSLATES.
    //
    // ⚠️ An exception inside a signal handler abandons the handler: the
    // remaining files are never written, Qt.quit() never runs, the process
    // hangs until `timeout 60` collects it — and because run_tool only greps
    // for ABORT, the installation says nothing at all. That is exactly how the
    // first attempt at these states failed: three GTK files written, kitty and
    // qt6ct not, and no word about it anywhere. Now it is an ABORT line with a
    // name and a reason, and the other targets are still written.
    property int threw: 0
    property var thrown: []
    function emitFile(mode, view, path, build, offBody, label, target) {
        try {
            if (mode === "off") {
                write(view, path, offBody, label + " (off)")
                return
            }
            write(view, path, build(mode), label + " (" + mode + ")")
        } catch (e) {
            root.threw++
            root.thrown.push(label)
            note("  ERROR  " + label + ": " + e)
        }
    }

    // ------------------------------------------------------------------ GTK 3
    function gtk3Css(m) {
        return head(false, m) +
            "@define-color theme_bg_color " + col(m, "base") + ";\n" +
            "@define-color theme_fg_color " + col(m, "text") + ";\n" +
            "@define-color theme_base_color " + col(m, "surface0") + ";\n" +
            "@define-color theme_text_color " + col(m, "text") + ";\n" +
            "@define-color theme_selected_bg_color " + accentOf(m) + ";\n" +
            "@define-color theme_selected_fg_color " + accentFgOf(m) + ";\n" +
            "@define-color insensitive_bg_color " + col(m, "mantle") + ";\n" +
            "@define-color insensitive_fg_color " + col(m, "overlay2") + ";\n" +
            "@define-color borders " + col(m, "overlay1") + ";\n" +
            "@define-color warning_color " + col(m, "yellow") + ";\n" +
            "@define-color error_color " + col(m, "red") + ";\n" +
            "@define-color success_color " + col(m, "green") + ";\n" +
            "@define-color accent_color " + accentOf(m) + ";\n" +
            "@define-color accent_fg_color " + accentFgOf(m) + ";\n" +
            // Shape does not follow the state: "neutral" means colourless, not
            // unstyled. Corners follow look.rounding, like every other surface.
            "\n/* Corners follow look.rounding, like every other surface. */\n" +
            "menu, .menu, popover, .popup, tooltip { border-radius: " + Theme.radiusMd + "px; }\n" +
            "button { border-radius: " + Theme.radiusSm + "px; }\n"
    }

    // ------------------------------------------------------------------ GTK 4
    // The same colour, opened up. `look.opacityApp` is what makes a GTK window
    // read as the one on the reference screenshot — near-black with the
    // wallpaper coming through, and the text still sharp.
    //
    // ⚠️ `rgba()` WITH A DECIMAL ALPHA, not an eight-digit hex. GTK's CSS parser
    // takes `rgba(r,g,b,a)` and does NOT take `#rrggbbaa`; the wrong one is not
    // an error, it is a colour that silently stays opaque.
    //
    // ⚠️ And it is written per COLOUR, not as one blanket rule on `window`.
    // libadwaita paints several surfaces — the window, the view, the sidebar —
    // and a single translucent rule underneath opaque ones changes nothing.
    function alphaOf(hex, a) {
        var c = Qt.color(hex)
        return "rgba(" + Math.round(c.r * 255) + ", " + Math.round(c.g * 255)
             + ", " + Math.round(c.b * 255) + ", " + a.toFixed(2) + ")"
    }

    function gtk4Css(m) {
        var a = Config.look.opacityApp
        return head(false, m) +
            "@define-color window_bg_color " + alphaOf(col(m, "base"), a) + ";\n" +
            "@define-color window_fg_color " + col(m, "text") + ";\n" +
            "@define-color view_bg_color " + alphaOf(col(m, "mantle"), a) + ";\n" +
            "@define-color view_fg_color " + col(m, "text") + ";\n" +
            "@define-color headerbar_bg_color " + alphaOf(col(m, "surface0"), a) + ";\n" +
            "@define-color headerbar_fg_color " + col(m, "text") + ";\n" +
            "@define-color popover_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color popover_fg_color " + col(m, "text") + ";\n" +
            "@define-color card_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color card_fg_color " + col(m, "text") + ";\n" +
            "@define-color sidebar_bg_color " + alphaOf(col(m, "mantle"), a) + ";\n" +
            "@define-color sidebar_fg_color " + col(m, "text") + ";\n" +
            "@define-color dialog_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color dialog_fg_color " + col(m, "text") + ";\n" +
            "@define-color accent_bg_color " + accentOf(m) + ";\n" +
            "@define-color accent_fg_color " + accentFgOf(m) + ";\n" +
            "@define-color accent_color " + accentOf(m) + ";\n" +
            "@define-color destructive_bg_color " + col(m, "red") + ";\n" +
            "@define-color destructive_fg_color " + onColour(m, Qt.color(col(m, "red"))) + ";\n" +
            "@define-color success_color " + col(m, "green") + ";\n" +
            "@define-color warning_color " + col(m, "yellow") + ";\n" +
            "@define-color error_color " + col(m, "red") + ";\n" +
            "@define-color borders " + col(m, "overlay1") + ";\n" +
            "\nwindow, popover > contents, .card { border-radius: " + Theme.radiusMd + "px; }\n" +
            "button { border-radius: " + Theme.radiusSm + "px; }\n"
    }

    // ⚠️ NOT A SINGLE COLOUR IN HERE, so it does not take the state — only the
    // header does, and only so the file names the palette it came from. Dark
    // or light is the user's decision (see Scheme.qml), and the neutral set
    // inherits it, so "neutral" keeps the dark GTK theme and the dark icons.
    function gtkSettings(m) {
        // ":" means: no window buttons on either side.
        // Honest note, repeated in the file itself: this removes the three
        // buttons. A libadwaita headerbar is content, not decoration, and stays.
        return head(true, m) +
            "# gtk-decoration-layout=\":\" removes the minimise/maximise/close\n" +
            "# buttons. It does NOT remove a libadwaita headerbar — that is part\n" +
            "# of the application's own layout and no setting can take it away.\n" +
            "[Settings]\n" +
            "gtk-application-prefer-dark-theme=" + (Theme.dark ? 1 : 0) + "\n" +
            "gtk-theme-name=" + (Theme.dark ? "adw-gtk3-dark" : "adw-gtk3") + "\n" +
            "gtk-icon-theme-name=" + (Theme.dark ? "Papirus-Dark" : "Papirus-Light") + "\n" +
            "gtk-font-name=" + Theme.fontUi + " " + Theme.fontSizePt + "\n" +
            "gtk-decoration-layout=:\n" +
            "gtk-xft-antialias=1\n" +
            "gtk-xft-hinting=1\n" +
            "gtk-xft-hintstyle=hintslight\n" +
            "gtk-xft-rgba=rgb\n"
    }

    // ------------------------------------------------------------------ kitty
    function kittyTheme(m) {
        return head(true, m) +
            "foreground " + col(m, "text") + "\n" +
            "background " + col(m, "base") + "\n" +
            // ⚠️ The terminal's own transparency, not the compositor's.
            //
            // It looked "nicely transparent" only while UNFOCUSED and went
            // solid black the moment it was selected — because the only
            // translucency it had was niri's `opacity 0.96` on inactive
            // windows. That is the wrong tool twice over: it fades the TEXT
            // along with the background, and it inverts the meaning, making
            // the window you are not using the readable one.
            //
            // background_opacity affects the background alone, so the type
            // stays crisp, and it does not care whether the window has focus.
            //
            // ⚠️ Transparency is not colour: a neutral terminal is still made
            // of glass. This stays outside the state on purpose.
            "background_opacity " + Theme.terminalOpacity + "\n" +
            "selection_foreground " + accentFgOf(m) + "\n" +
            "selection_background " + accentOf(m) + "\n" +
            "cursor " + accentOf(m) + "\n" +
            "cursor_text_color " + accentFgOf(m) + "\n" +
            "url_color " + col(m, "sapphire") + "\n" +
            "active_border_color " + accentOf(m) + "\n" +
            "inactive_border_color " + col(m, "overlay1") + "\n" +
            "active_tab_foreground " + accentFgOf(m) + "\n" +
            "active_tab_background " + accentOf(m) + "\n" +
            "inactive_tab_foreground " + col(m, "subtext0") + "\n" +
            "inactive_tab_background " + col(m, "surface0") + "\n" +
            "font_family " + Theme.fontMono + "\n" +
            "font_size " + Theme.fontSizePt + "\n" +
            "color0 " + col(m, "crust") + "\n" +
            "color8 " + col(m, "overlay0") + "\n" +
            "color1 " + col(m, "red") + "\n" +
            "color9 " + col(m, "red") + "\n" +
            "color2 " + col(m, "green") + "\n" +
            "color10 " + col(m, "green") + "\n" +
            "color3 " + col(m, "yellow") + "\n" +
            "color11 " + col(m, "yellow") + "\n" +
            "color4 " + col(m, "sapphire") + "\n" +
            "color12 " + col(m, "sapphire") + "\n" +
            "color5 " + col(m, "mauve") + "\n" +
            "color13 " + col(m, "mauve") + "\n" +
            "color6 " + col(m, "teal") + "\n" +
            "color14 " + col(m, "teal") + "\n" +
            "color7 " + col(m, "subtext1") + "\n" +
            "color15 " + col(m, "text") + "\n"
    }

    // ------------------------------------------------------------------- niri
    // COLOURS ONLY. This file is `include`d by the generated config.kdl, and
    // the split is what lets a palette change leave the keybindings alone.
    //
    // ⚠️ Two rules, both from niri's own documentation and both easy to break:
    //
    //  * No `on`, no `off`, no `width`, no `gaps` here. Whether a border exists
    //    is a look setting and belongs to tools/niri.qml. Worse, the meaning
    //    differs by file: "writing layout { border {} } in an included config
    //    does nothing… the same in the main config will ENABLE the border".
    //    Deciding visibility from here would mean deciding it differently
    //    depending on which file happened to be read.
    //
    //  * An include overrides what came before it, so config.kdl places this
    //    include after its own layout block. Sections merge property by
    //    property, so setting only colours leaves gaps and width untouched.
    // ⚠️ A SHADOW IS SHADE, NOT A COLOUR — and writing it as one was a real
    // fault, not a nicety. It used to be `crust` at a fixed alpha, `crust`
    // being the palette's darkest tone. On the two LIGHT palettes that tone is
    // nearly white (latte `#dce0e8`, everforest-light `#e6e2cc`), so every
    // window would have been given a bright HALO instead of a shadow, and
    // nothing in the shell would have said so.
    //
    // The tint therefore survives only while it is genuinely dark; otherwise
    // the shadow is black, which is what a shadow is. Light palettes also get
    // a gentler one — on a pale desktop a shadow at full strength reads as
    // dirt rather than as depth.
    function shadowColour(m, factor) {
        var c = col(m, "crust")
        var dark = Theme.luminance(c) < 0.25
        var a = Config.look.shadowOpacity * (dark ? 1.0 : 0.45) * factor
        var h = Math.round(Math.max(0, Math.min(1, a)) * 255).toString(16)
        // There is no token for the absence of light, and taking one from the
        // palette is exactly the fault described above.
        var black = "#000000"   // literal-ok: a shadow is shade, not a colour
        return (dark ? c : black) + (h.length < 2 ? "0" + h : h)
    }

    function niriColours(m) {
        return head(true, m).replace(/^#/gm, "//") +
            "// Colours only — see tools/render.qml. Structure lives in config.kdl.\n" +
            "layout {\n" +
            // Not bgDeep: that is the island's colour, and a backdrop in the
            // same shade makes the notch disappear on a machine with no
            // wallpaper. This is what shows THROUGH, so it stays a step lighter.
            "    background-color \"" + col(m, "base") + "\"\n" +
            "    border {\n" +
            "        active-color \"" + accentOf(m) + "\"\n" +
            "        inactive-color \"" + col(m, "overlay1") + "\"\n" +
            "        urgent-color \"" + col(m, "red") + "\"\n" +
            "    }\n" +
            "    focus-ring {\n" +
            "        active-color \"" + accentOf(m) + "\"\n" +
            "        inactive-color \"" + col(m, "overlay1") + "\"\n" +
            "        urgent-color \"" + col(m, "red") + "\"\n" +
            "    }\n" +
            // ⚠️ `inactive-color` IS WRITTEN, and it is not a nicety. niri's own
            // default for it is "a more transparent color", and how much more is
            // its business rather than ours. Measured on the running machine at
            // the same window edge, as the darkening of the wallpaper beside it:
            //
            //   no shadow            0
            //   unfocused, default   145      <- niri's guess, ~60 % of ours
            //   focused              240
            //
            // Most windows on a screen are unfocused, so that guess is what the
            // desktop actually looks like. Written down at 0.75 it stays a step
            // below the focused window — with no border and no focus ring, the
            // shadow is the only thing that says which window is live — while
            // still being a shadow rather than a hint.
            "    shadow {\n" +
            "        color \"" + shadowColour(m, 1.0) + "\"\n" +
            "        inactive-color \"" + shadowColour(m, 0.75) + "\"\n" +
            "    }\n" +
            "    insert-hint {\n" +
            "        color \"" + accentOf(m) + "80\"\n" +
            "    }\n" +
            "    tab-indicator {\n" +
            "        active-color \"" + accentOf(m) + "\"\n" +
            "        inactive-color \"" + col(m, "overlay1") + "\"\n" +
            "        urgent-color \"" + col(m, "red") + "\"\n" +
            "    }\n" +
            "}\n" +
            "\noverview {\n" +
            "    backdrop-color \"" + col(m, "mantle") + "\"\n" +
            "}\n"
    }

    // ------------------------------------------------------------------- Qt
    //
    // ⚠️ ALL THREE GROUPS, and this file was written for months with only one.
    //
    // qt6ct takes the colour scheme ONLY if active, inactive AND disabled each
    // carry a full set of roles; otherwise it silently keeps the fallback,
    // which is Qt's own default palette:
    //
    //     if(activeColors.count() >= QPalette::NColorRoles &&
    //        inactiveColors.count() >= QPalette::NColorRoles &&
    //        disabledColors.count() >= QPalette::NColorRoles) { … }
    //     else { customPalette = fallback; }
    //         — qt6ct-0.11, src/qt6ct-common/qt6ct.cpp
    //
    // We wrote active_colors and nothing else, so every Qt application has
    // been running on plain Fusion grey while the file, the pointer in
    // qt6ct.conf and the test all said the colours were there. Measured with a
    // QApplication under QT_QPA_PLATFORMTHEME=qt6ct: with one list the palette
    // came back #efefef/#000000, byte-identical to having no qt6ct at all;
    // with three it came back the palette's own #27231b/#e8e6e3.
    //
    // Exactly the same shape as the kitty theme that was written into a void
    // for a milestone — hence the test extension that reads the file back.
    //
    // 21 entries, in QPalette::ColorRole order up to PlaceholderText. qt6ct
    // appends Accent itself by copying Highlight when the list stops one short
    // of NColorRoles, so 21 is the intended length rather than an oversight.
    function qtColors(m) {
        var fg = col(m, "text"), bg = col(m, "base"), surface = col(m, "surface0")
        var dim = col(m, "mantle"), disabled = col(m, "overlay2")
        var active = [fg, surface, col(m, "surface1"), surface, dim, bg,
                      fg, fg, fg, bg, bg, col(m, "crust"), accentOf(m), accentFgOf(m),
                      col(m, "sapphire"), col(m, "teal"), surface, fg, dim, fg,
                      disabled]
        // Inactive is the same set on purpose: Qt uses it for windows that do
        // not have focus, and a desktop where the unfocused window changes
        // colour is the very effect kitty's background_opacity note argues
        // against. niri already dims unfocused windows if look.opacityInactive
        // says so — one mechanism, not two.
        var inactive = active.slice()
        // Disabled differs in exactly one thing: text stops being readable as
        // text. Everything structural stays, or a greyed-out dialog turns into
        // a different dialog.
        var dis = active.slice()
        dis[0] = disabled     // WindowText
        dis[6] = disabled     // Text
        dis[7] = disabled     // BrightText
        dis[8] = disabled     // ButtonText
        dis[13] = disabled    // HighlightedText
        dis[17] = disabled    // NoRole
        dis[19] = disabled    // ToolTipText
        return head(true, m) +
            "[ColorScheme]\n" +
            "active_colors=" + active.join(", ") + "\n" +
            "inactive_colors=" + inactive.join(", ") + "\n" +
            "disabled_colors=" + dis.join(", ") + "\n"
    }

    // ------------------------------------------------------------------ btop
    //
    // 37 keys, counted in a shipped theme rather than remembered
    // (/usr/share/btop/themes/*.theme). The format is theme[key]="#rrggbb", and
    // btop finds a user theme in ~/.config/btop/themes — both stated by btop's
    // own default config, which also names the pointer: color_theme.
    //
    // ⚠️ main_bg IS DELIBERATELY EMPTY. btop's own comment: "empty for terminal
    // default, need to be empty if you want transparent background". Writing
    // our base colour here would paint an opaque rectangle over a terminal we
    // went to some trouble to make translucent.
    function btopTheme(m) {
        function k(key, colour) { return "theme[" + key + "]=\"" + colour + "\"\n" }
        // Three-stop gradients. Meaning first: rising load goes green → yellow
        // → red, and that direction survives the neutral state because those
        // three are anchored.
        function ramp(prefix, a, b, c) {
            return k(prefix + "_start", col(m, a)) +
                   k(prefix + "_mid", col(m, b)) +
                   k(prefix + "_end", col(m, c))
        }
        return head(true, m) +
            "theme[main_bg]=\"\"\n" +
            k("main_fg", col(m, "text")) +
            k("title", col(m, "text")) +
            k("hi_fg", accentOf(m)) +
            k("selected_bg", col(m, "surface1")) +
            k("selected_fg", col(m, "text")) +
            k("inactive_fg", col(m, "overlay1")) +
            k("proc_misc", col(m, "teal")) +
            k("cpu_box", col(m, "overlay0")) +
            k("mem_box", col(m, "overlay0")) +
            k("net_box", col(m, "overlay0")) +
            k("proc_box", col(m, "overlay0")) +
            k("div_line", col(m, "overlay0")) +
            ramp("temp", "green", "yellow", "red") +
            ramp("cpu", "green", "yellow", "red") +
            ramp("free", "green", "teal", "sapphire") +
            ramp("cached", "sapphire", "blue", "mauve") +
            ramp("available", "teal", "sapphire", "blue") +
            ramp("used", "yellow", "peach", "red") +
            ramp("download", "green", "teal", "sapphire") +
            ramp("upload", "yellow", "peach", "red")
    }

    // ------------------------------------------------------------- alacritty
    //
    // The alternative terminal, themed from the same tokens as kitty so the two
    // are not two looks. ⚠️ `import` lives under [general] as of 0.14 — read in
    // alacritty(5), where it sits in the GENERAL section — and the importing
    // file is loaded LAST, so our values are the ones a user can override.
    function alacrittyToml(m) {
        function q(s) { return "\"" + s + "\"" }
        return head(true, m) +
            "[window]\n" +
            // The same argument as kitty's background_opacity: the terminal's
            // own transparency, not the compositor's, so the type stays crisp.
            "opacity = " + Theme.terminalOpacity + "\n\n" +
            "[font]\nnormal = { family = " + q(Theme.fontMono) + " }\n" +
            "size = " + Theme.fontSizePt + "\n\n" +
            "[colors.primary]\n" +
            "background = " + q(col(m, "base")) + "\n" +
            "foreground = " + q(col(m, "text")) + "\n\n" +
            "[colors.cursor]\n" +
            "text = " + q(accentFgOf(m)) + "\n" +
            "cursor = " + q(accentOf(m)) + "\n\n" +
            "[colors.selection]\n" +
            "text = " + q(accentFgOf(m)) + "\n" +
            "background = " + q(accentOf(m)) + "\n\n" +
            "[colors.normal]\n" +
            "black = " + q(col(m, "crust")) + "\n" +
            "red = " + q(col(m, "red")) + "\n" +
            "green = " + q(col(m, "green")) + "\n" +
            "yellow = " + q(col(m, "yellow")) + "\n" +
            "blue = " + q(col(m, "sapphire")) + "\n" +
            "magenta = " + q(col(m, "mauve")) + "\n" +
            "cyan = " + q(col(m, "teal")) + "\n" +
            "white = " + q(col(m, "subtext1")) + "\n\n" +
            "[colors.bright]\n" +
            "black = " + q(col(m, "overlay0")) + "\n" +
            "red = " + q(col(m, "red")) + "\n" +
            "green = " + q(col(m, "green")) + "\n" +
            "yellow = " + q(col(m, "yellow")) + "\n" +
            "blue = " + q(col(m, "sapphire")) + "\n" +
            "magenta = " + q(col(m, "mauve")) + "\n" +
            "cyan = " + q(col(m, "teal")) + "\n" +
            "white = " + q(col(m, "text")) + "\n"
    }

    // ------------------------------------------------------------------ tmux
    //
    // Sourced from tmux.conf. tmux reads ~/.tmux.conf or
    // $XDG_CONFIG_HOME/tmux/tmux.conf (tmux(1)), and `source-file` is the
    // pointer.
    function tmuxConf(m) {
        return head(true, m) +
            "set -g status-style \"bg=" + col(m, "mantle") + ",fg=" + col(m, "text") + "\"\n" +
            "set -g status-left-style \"bg=" + accentOf(m) + ",fg=" + accentFgOf(m) + ",bold\"\n" +
            "set -g status-right-style \"bg=" + col(m, "surface0") + ",fg=" + col(m, "subtext1") + "\"\n" +
            "setw -g window-status-current-style \"bg=" + accentOf(m) +
            ",fg=" + accentFgOf(m) + ",bold\"\n" +
            "setw -g window-status-style \"bg=" + col(m, "mantle") + ",fg=" + col(m, "subtext0") + "\"\n" +
            "setw -g window-status-activity-style \"fg=" + col(m, "yellow") + "\"\n" +
            "set -g pane-border-style \"fg=" + col(m, "overlay1") + "\"\n" +
            "set -g pane-active-border-style \"fg=" + accentOf(m) + "\"\n" +
            "set -g message-style \"bg=" + col(m, "surface0") + ",fg=" + col(m, "text") + "\"\n" +
            "set -g mode-style \"bg=" + accentOf(m) + ",fg=" + accentFgOf(m) + "\"\n" +
            "set -g display-panes-active-colour \"" + accentOf(m) + "\"\n" +
            "set -g display-panes-colour \"" + col(m, "overlay1") + "\"\n" +
            "set -g clock-mode-colour \"" + accentOf(m) + "\"\n"
    }

    // -------------------------------------------------------------- git-delta
    //
    // ⚠️ INCLUDED FROM ~/.config/git/config, NEVER WRITTEN INTO ~/.gitconfig.
    // Proven rather than hoped: git reads BOTH global files, so an [include] in
    // the XDG one takes effect while a hand-written ~/.gitconfig is left
    // completely alone — measured with two HOMEs and `git config --get`.
    //
    // `syntax-theme` is bat's theme registry, not delta's own: delta renders
    // through bat. It is only named here when bat is themed as well, because
    // pointing at a theme that was never built is the same mistake as writing
    // a file nobody reads.
    function deltaGitconfig(m, batThemed) {
        return head(true, m) +
            "[delta]\n" +
            (batThemed ? "\tsyntax-theme = buchhwin\n" : "") +
            "\tminus-style = normal \"" + col(m, "mantle") + "\"\n" +
            "\tminus-emph-style = normal \"" + col(m, "red") + "\"\n" +
            "\tplus-style = normal \"" + col(m, "surface0") + "\"\n" +
            "\tplus-emph-style = normal \"" + col(m, "green") + "\"\n" +
            "\tline-numbers-minus-style = \"" + col(m, "red") + "\"\n" +
            "\tline-numbers-plus-style = \"" + col(m, "green") + "\"\n" +
            "\tline-numbers-zero-style = \"" + col(m, "overlay1") + "\"\n" +
            "\tline-numbers-left-style = \"" + col(m, "overlay0") + "\"\n" +
            "\tline-numbers-right-style = \"" + col(m, "overlay0") + "\"\n" +
            "\tfile-style = bold \"" + accentOf(m) + "\"\n" +
            "\tfile-decoration-style = \"" + col(m, "overlay0") + "\" ul\n" +
            "\thunk-header-style = \"" + col(m, "subtext0") + "\"\n" +
            "\thunk-header-decoration-style = \"" + col(m, "overlay0") + "\" box\n" +
            "\tblame-palette = \"" + col(m, "base") + "\" \"" + col(m, "mantle") +
            "\" \"" + col(m, "surface0") + "\" \"" + col(m, "surface1") + "\"\n"
    }

    // ------------------------------------------------------------------- bat
    //
    // A .tmTheme — the Sublime format bat's syntax highlighter reads — and the
    // one target with a second step: bat only sees a theme after
    // `bat cache --build`, so the file alone is exactly the kitty mistake with
    // a different name. The renderer runs it, and waits for it.
    function batTheme(m) {
        function scope(name, colour, style) {
            return "\t\t<dict>\n\t\t\t<key>scope</key><string>" + name + "</string>\n" +
                   "\t\t\t<key>settings</key><dict>\n" +
                   "\t\t\t\t<key>foreground</key><string>" + colour + "</string>\n" +
                   (style ? "\t\t\t\t<key>fontStyle</key><string>" + style + "</string>\n" : "") +
                   "\t\t\t</dict>\n\t\t</dict>\n"
        }
        return "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" +
            "<!-- Generated by buchhwin from palette '" + Scheme.name + "'" +
            (m === "neutral" ? ", neutral" : "") + ". Do not edit. -->\n" +
            "<plist version=\"1.0\">\n<dict>\n" +
            "\t<key>name</key><string>buchhwin</string>\n" +
            "\t<key>settings</key>\n\t<array>\n" +
            "\t\t<dict>\n\t\t\t<key>settings</key><dict>\n" +
            "\t\t\t\t<key>background</key><string>" + col(m, "base") + "</string>\n" +
            "\t\t\t\t<key>foreground</key><string>" + col(m, "text") + "</string>\n" +
            "\t\t\t\t<key>caret</key><string>" + accentOf(m) + "</string>\n" +
            "\t\t\t\t<key>lineHighlight</key><string>" + col(m, "surface0") + "</string>\n" +
            "\t\t\t\t<key>selection</key><string>" + col(m, "surface1") + "</string>\n" +
            "\t\t\t</dict>\n\t\t</dict>\n" +
            scope("comment", col(m, "overlay1"), "italic") +
            scope("string", col(m, "green"), "") +
            scope("constant.numeric", col(m, "peach"), "") +
            scope("constant.language", col(m, "peach"), "") +
            scope("constant.character, constant.other", col(m, "peach"), "") +
            scope("keyword, storage.type, storage.modifier", col(m, "red"), "") +
            scope("entity.name.function, support.function", accentOf(m), "") +
            scope("entity.name.type, entity.name.class, support.type, support.class",
                  col(m, "yellow"), "") +
            scope("variable, variable.parameter", col(m, "text"), "") +
            scope("entity.name.tag", col(m, "mauve"), "") +
            scope("entity.other.attribute-name", col(m, "teal"), "") +
            scope("punctuation, meta.brace", col(m, "subtext0"), "") +
            scope("invalid", col(m, "red"), "") +
            "\t</array>\n</dict>\n</plist>\n"
    }

    // --------------------------------------------------------------- lazygit
    //
    // ⚠️ THE ONLY TARGET WHOSE POINTER IS AN ENVIRONMENT VARIABLE.
    // lazygit reads one config file, and the only way to add a second is
    // LG_CONFIG_FILE with a comma-separated list — stated by lazygit's own
    // --help ("Comma separated list to custom config file(s)"). We already own
    // environment.d, so that is a pointer we can set without editing anything
    // of the user's. Ours is listed LAST so their own config still wins.
    function lazygitYml(m) {
        function style(key, colour, extra) {
            return "    " + key + ":\n      - \"" + colour + "\"\n" +
                   (extra ? "      - " + extra + "\n" : "")
        }
        return head(true, m) +
            "gui:\n  theme:\n" +
            style("activeBorderColor", accentOf(m), "bold") +
            style("inactiveBorderColor", col(m, "overlay1"), "") +
            style("searchingActiveBorderColor", col(m, "yellow"), "bold") +
            style("optionsTextColor", col(m, "subtext0"), "") +
            style("selectedLineBgColor", col(m, "surface1"), "") +
            style("inactiveViewSelectedLineBgColor", col(m, "surface0"), "") +
            style("cherryPickedCommitFgColor", col(m, "base"), "") +
            style("cherryPickedCommitBgColor", col(m, "teal"), "") +
            style("markedBaseCommitFgColor", col(m, "base"), "") +
            style("markedBaseCommitBgColor", col(m, "yellow"), "") +
            style("unstagedChangesColor", col(m, "red"), "") +
            style("defaultFgColor", col(m, "text"), "")
    }

    // blockLoading so write() can compare against what is already on disk in
    // the same statement; printErrors off because "not there yet" is the normal
    // case on a first run and not a fault worth shouting about. Same shape as
    // tools/niri.qml:520-521.
    FileView { id: f1; blockLoading: true; printErrors: false }
    FileView { id: f2; blockLoading: true; printErrors: false }
    FileView { id: f3; blockLoading: true; printErrors: false }
    FileView { id: f4; blockLoading: true; printErrors: false }
    FileView { id: f5; blockLoading: true; printErrors: false }
    FileView { id: f6; blockLoading: true; printErrors: false }
    FileView { id: f7; blockLoading: true; printErrors: false }
    FileView { id: f8; blockLoading: true; printErrors: false }
    FileView { id: f9; blockLoading: true; printErrors: false }
    FileView { id: f10; blockLoading: true; printErrors: false }
    FileView { id: f11; blockLoading: true; printErrors: false }
    FileView { id: f12; blockLoading: true; printErrors: false }
    FileView { id: f13; blockLoading: true; printErrors: false }
    FileView { id: f14; blockLoading: true; printErrors: false }
    FileView { id: f15; blockLoading: true; printErrors: false }
    FileView { id: f16; blockLoading: true; printErrors: false }

    // ------------------------------------------------------------- VS Code
    //
    // ⚠️ AN EXTENSION, NOT A PILE OF colorCustomizations. VS Code has no
    // include mechanism, so the only two ways in are its settings file — which
    // belongs to the user and would then hold two hundred generated lines — or
    // a colour theme of our own, which is a directory we own entirely with a
    // ONE LINE pointer in the user's file. That is the same shape as kitty's
    // include and btop's `color_theme`, and it is the shape this project uses
    // everywhere for a reason: `off` has something to take back out.
    function vscodePackage() {
        return JSON.stringify({
            name: "buchhwin-theme",
            displayName: "Buchhwin",
            description: "Generated from the buchhwin palette. Do not edit.",
            version: "1.0.0",
            publisher: "buchhwin",
            engines: { vscode: "^1.70.0" },
            categories: ["Themes"],
            contributes: {
                themes: [{
                    label: "Buchhwin",
                    uiTheme: Theme.dark ? "vs-dark" : "vs",
                    path: "./themes/buchhwin-color-theme.json"
                }]
            }
        }, null, 2) + "\n"
    }

    function vscodeTheme(m) {
        var c = ({
            "editor.background": col(m, "base"),
            "editor.foreground": col(m, "text"),
            "editorLineNumber.foreground": col(m, "overlay0"),
            "editorLineNumber.activeForeground": accentOf(m),
            "editorCursor.foreground": accentOf(m),
            "editor.selectionBackground": col(m, "surface1"),
            "editor.lineHighlightBackground": col(m, "mantle"),
            "sideBar.background": col(m, "mantle"),
            "sideBar.foreground": col(m, "subtext1"),
            "sideBarSectionHeader.background": col(m, "surface0"),
            "activityBar.background": col(m, "crust"),
            "activityBar.foreground": col(m, "text"),
            "activityBarBadge.background": accentOf(m),
            "activityBarBadge.foreground": accentFgOf(m),
            "statusBar.background": col(m, "crust"),
            "statusBar.foreground": col(m, "subtext0"),
            "titleBar.activeBackground": col(m, "crust"),
            "titleBar.activeForeground": col(m, "text"),
            "tab.activeBackground": col(m, "base"),
            "tab.inactiveBackground": col(m, "mantle"),
            "tab.activeBorderTop": accentOf(m),
            "panel.background": col(m, "mantle"),
            "terminal.background": col(m, "base"),
            "terminal.foreground": col(m, "text"),
            "focusBorder": accentOf(m),
            "list.activeSelectionBackground": col(m, "surface1"),
            "list.hoverBackground": col(m, "surface0"),
            "errorForeground": col(m, "red"),
            "editorError.foreground": col(m, "red"),
            "editorWarning.foreground": col(m, "yellow"),
            "editorInfo.foreground": col(m, "blue")
        })
        return JSON.stringify({
            name: "Buchhwin",
            type: Theme.dark ? "dark" : "light",
            colors: c,
            tokenColors: [
                { scope: ["comment"], settings: { foreground: col(m, "overlay1"),
                                                  fontStyle: "italic" } },
                { scope: ["string"], settings: { foreground: col(m, "green") } },
                { scope: ["constant.numeric"], settings: { foreground: col(m, "peach") } },
                { scope: ["keyword", "storage.type"], settings: { foreground: col(m, "mauve") } },
                { scope: ["entity.name.function"], settings: { foreground: col(m, "blue") } },
                { scope: ["variable"], settings: { foreground: col(m, "text") } },
                { scope: ["entity.name.type"], settings: { foreground: col(m, "yellow") } }
            ]
        }, null, 2) + "\n"
    }

    // ⚠️ THE USER'S OWN FILE, TOUCHED WITH TWO KEYS AND A BACKUP.
    //
    // settings.json is JSONC — VS Code allows comments in it — and JSON.parse
    // does not. Whole-line comments are stripped, which cannot corrupt a `//`
    // inside a string on a value line, and that is the only stripping done. If
    // what is left still does not parse, NOTHING is written and the line to add
    // by hand is printed instead. Destroying somebody's editor settings to set
    // a colour scheme would be a poor trade.
    function vscodeSettings(mode) {
        var raw = f16.text()
        var obj = ({})
        if (raw && raw.trim().length) {
            var stripped = raw.split("\n").filter(function (l) {
                return l.replace(/^\s+/, "").indexOf("//") !== 0
            }).join("\n")
            try {
                obj = JSON.parse(stripped)
            } catch (e) {
                return null
            }
            if (typeof obj !== "object" || obj === null)
                return null
        }
        if (mode === "off") {
            delete obj["workbench.colorTheme"]
        } else {
            obj["workbench.colorTheme"] = "Buchhwin"
        }
        // Not part of the colour scheme, and set in both states on purpose:
        // "native" means the compositor draws the frame, and niri's
        // prefer-no-csd then draws none at all — no title bar, no buttons.
        obj["window.titleBarStyle"] = "native"
        return JSON.stringify(obj, null, 4) + "\n"
    }
    FileView { id: log; path: "/tmp/buchhwin-render.log" }

    // ⚠️ bat NEEDS A SECOND STEP, and without it this whole target is the kitty
    // mistake again: the .tmTheme sits in the right folder and bat has never
    // heard of it until `bat cache --build` compiles it into its own cache.
    //
    // Only run when the theme actually changed — it takes about a second and
    // rebuilding an unchanged cache on every look tweak is exactly the kind of
    // idle work this project measures itself against. And the process is waited
    // for rather than fired off: the renderer quits in the next event loop
    // step, which would kill it.
    // ------------------------------------------------- the settings GTK 4 reads
    //
    // ⚠️ settings.ini IS NOT WHERE GTK 4 LOOKS FOR THESE. Measured on the
    // machine: with `gtk-icon-theme-name=Papirus-Dark` written into both
    // gtk-3.0/settings.ini and gtk-4.0/settings.ini, `gsettings get
    // org.gnome.desktop.interface icon-theme` still answered 'Adwaita' — and
    // Nautilus duly drew Adwaita's blue folders on a warm dark palette. Same
    // for `color-scheme`, which answered 'default'.
    //
    // libadwaita and GTK 4 take these from the settings portal, which reads
    // dconf. So they are written there as well as into the files: the files
    // still matter for GTK 3 and for anything that reads them directly, and
    // this is what the toolkit the file manager is built on actually consults.
    //
    // ⚠️ `reset`, not "write the old value back", when theming is off. We never
    // knew what was there before — reset returns the key to the system default,
    // which is the honest meaning of "we are not touching this any more".
    //
    // ⚠️ Through `sh` for the same reason as bat below: a Process whose binary
    // is missing never reports back, and a machine without gsettings would hang
    // the renderer on its guard timer.
    function gsettingsScript(mode) {
        var iface = "org.gnome.desktop.interface"
        if (mode === "off")
            return "command -v gsettings >/dev/null || exit 0; "
                 + "for k in icon-theme gtk-theme color-scheme font-name; do "
                 + "gsettings reset " + iface + " $k; done"
        var icons = Theme.dark ? "Papirus-Dark" : "Papirus-Light"
        var gtk = Theme.dark ? "adw-gtk3-dark" : "adw-gtk3"
        var scheme = Theme.dark ? "prefer-dark" : "prefer-light"
        var font = Theme.fontUi + " " + Theme.fontSizePt
        return "command -v gsettings >/dev/null || exit 0; "
             + "gsettings set " + iface + " icon-theme '" + icons + "'; "
             + "gsettings set " + iface + " gtk-theme '" + gtk + "'; "
             + "gsettings set " + iface + " color-scheme '" + scheme + "'; "
             + "gsettings set " + iface + " font-name '" + font + "'"
    }

    Process { id: gsettingsApply }

    property bool batPending: false
    Process {
        id: batCache
        // ⚠️ THROUGH `sh`, AND THAT IS NOT A STYLE CHOICE.
        //
        // A Process whose binary does not exist never emits onExited, so the
        // renderer sat on the guard timer for the full ten seconds on every
        // single run on a machine without bat — measured at 11 s, and the CI
        // container has no bat, which would have been six of those inside one
        // suite. `sh` always exists, so the signal always comes: immediately
        // when bat is absent, after the real build when it is there.
        command: ["sh", "-c", "command -v bat >/dev/null || exit 3; exec bat cache --build"]
        onExited: function (code) {
            // 3 is our own signal for "bat is not installed", which is not a
            // fault: the theme file is written and will be compiled the day it
            // is. Anything else is bat itself failing, and that is worth a line.
            root.note(code === 0 ? "  built  bat cache"
                    : code === 3 ? "  skip   bat is not installed; the theme is written anyway"
                                 : "  ERROR  bat cache --build exited " + code)
            root.finish()
        }
    }
    Timer {
        id: batGuard
        interval: 10000
        onTriggered: {
            root.note("  ERROR  bat cache --build did not finish in 10 s")
            root.finish()
        }
    }
    function finish() {
        batGuard.stop()
        note("done: " + written + " written, " + unchanged + " unchanged")
        if (root.threw) {
            note("buchhwin render — ABORT")
            note("  " + root.threw + " target(s) threw: " + root.thrown.join(", "))
        }
        Qt.callLater(Qt.quit)
    }

    // Wait for the palette to actually be there. The previous fixed 700 ms
    // timer looked like it was doing this and was not: it touched Scheme for
    // the first time inside itself, so the palette had not begun loading when
    // `ready` was tested. See WaitFor.qml.
    WaitFor {
        condition: Config.settled && Scheme.ready

        // The derived palette may have to read the wallpaper first, which is
        // a deliberate ~1.8 s wait (the quantiser lies on its first signal —
        // see Scheme.qml). Five seconds is right for reading a file and wrong
        // for reading an image, and this runs on the installer's critical path.
        timeoutMs: Scheme.derived ? 12000 : 5000

        onTimedOut: {
            note("buchhwin render — ABORT")
            note("  the palette did not load; refusing to write fallback colours")
            note("  " + (Scheme.failure.length ? Scheme.failure : "no reason reported"))
            Qt.callLater(Qt.quit)
        }

        onReady: {
            // ⚠️ NOTHING ABOVE THIS LINE READS Config OR Scheme. This is the
            // first moment the config has settled AND the deferral in
            // WaitFor.qml has passed, which is the difference between the
            // real values and the adapter's defaults.
            root.neutralPal = FromImage.neutral(Theme.dark, 0)

            var mGtk = stateOf("gtk"), mQt = stateOf("qt")
            var mKitty = stateOf("kitty"), mNiri = stateOf("niri")
            var mBtop = stateOf("btop"), mAla = stateOf("alacritty")
            var mTmux = stateOf("tmux"), mBat = stateOf("bat")
            var mDelta = stateOf("delta"), mLazy = stateOf("lazygit")

            note("buchhwin render — palette " + Scheme.name +
                 " (" + Scheme.displayName + "), accent " + Config.theme.accent)
            note("  states: gtk=" + mGtk + " qt=" + mQt + " kitty=" + mKitty +
                 " niri=" + mNiri + " btop=" + mBtop + " alacritty=" + mAla +
                 " tmux=" + mTmux + " bat=" + mBat + " delta=" + mDelta +
                 " lazygit=" + mLazy + "   (theming.enabled " + Config.theming.enabled +
                 ", theming.mode " + Config.theming.mode + ")")

            emitFile(mGtk, f1, root.cfg + "/gtk-3.0/gtk.css",
                     gtk3Css, offCss("gtk"), "gtk3 colours", "gtk")
            emitFile(mGtk, f2, root.cfg + "/gtk-3.0/settings.ini",
                     gtkSettings, offText("#", "gtk"), "gtk3 settings", "gtk")
            emitFile(mGtk, f3, root.cfg + "/gtk-4.0/gtk.css",
                     gtk4Css, offCss("gtk"), "gtk4 colours", "gtk")
            gsettingsApply.command = ["sh", "-c", root.gsettingsScript(mGtk)]
            gsettingsApply.running = true
            note("  set    gtk desktop settings via gsettings (" + mGtk + ")")

            emitFile(mGtk, f4, root.cfg + "/gtk-4.0/settings.ini",
                     gtkSettings, offText("#", "gtk"), "gtk4 settings", "gtk")
            emitFile(mKitty, f5, root.cfg + "/kitty/theme.conf",
                     kittyTheme, offText("#", "kitty"), "kitty", "kitty")
            emitFile(mNiri, f6, root.cfg + "/niri/colors.kdl",
                     niriColours, offText("//", "niri"), "niri colours", "niri")
            emitFile(mQt, f7, root.cfg + "/qt6ct/colors/buchhwin.conf",
                     qtColors, offText("#", "qt"), "qt6ct", "qt")
            emitFile(mBtop, f8, root.cfg + "/btop/themes/buchhwin.theme",
                     btopTheme, offText("#", "btop"), "btop", "btop")
            emitFile(mAla, f9, root.cfg + "/alacritty/buchhwin.toml",
                     alacrittyToml, offText("#", "alacritty"), "alacritty", "alacritty")
            emitFile(mTmux, f10, root.cfg + "/tmux/buchhwin.conf",
                     tmuxConf, offText("#", "tmux"), "tmux", "tmux")
            emitFile(mDelta, f11, root.cfg + "/git/buchhwin-delta.gitconfig",
                     function (mm) { return deltaGitconfig(mm, mBat !== "off") },
                     offText("#", "delta"), "git-delta", "delta")
            emitFile(mLazy, f12, root.cfg + "/lazygit/buchhwin.yml",
                     lazygitYml, offText("#", "lazygit"), "lazygit", "lazygit")

            // bat last, because it is the one that has to be compiled after it
            // is written.
            var batBefore = written
            var home = Quickshell.env("HOME") || "~"
            var ext = home + "/.vscode/extensions/buchhwin-theme"
            var mCode = stateOf("vscode")
            emitFile(mCode, f14, ext + "/package.json",
                     function () { return root.vscodePackage() },
                     root.vscodePackage(), "vscode manifest", "vscode")
            emitFile(mCode, f15, ext + "/themes/buchhwin-color-theme.json",
                     root.vscodeTheme,
                     // ⚠️ `off` writes an EMPTY theme rather than deleting it.
                     // The pointer in settings.json is taken out at the same
                     // time, but a stale pointer at a deleted theme makes VS
                     // Code fall back with a warning on every start.
                     JSON.stringify({ name: "Buchhwin", colors: {}, tokenColors: [] },
                                    null, 2) + "\n",
                     "vscode theme", "vscode")
            f16.path = root.cfg + "/Code/User/settings.json"
            var codeSettings = root.vscodeSettings(mCode)
            if (codeSettings === null)
                note("  skip   vscode settings.json does not parse — "
                     + "add \"workbench.colorTheme\": \"Buchhwin\" by hand")
            else
                write(f16, root.cfg + "/Code/User/settings.json", codeSettings,
                      "vscode settings (" + mCode + ")")

            emitFile(mBat, f13, root.cfg + "/bat/themes/buchhwin.tmTheme",
                     batTheme, "<!-- buchhwin: theming is OFF for bat. -->\n",
                     "bat", "bat")
            root.batPending = written !== batBefore

            // ⚠️ Two keys still have no writer, and it is not an oversight:
            // neither fastfetch nor starship has any include mechanism — read
            // in their own binaries and --help output, both name a single
            // config file that belongs to the user. Their colours come from the
            // terminal's sixteen ANSI colours, which the kitty and alacritty
            // themes above already set, so they follow the palette without a
            // file of their own. Said out loud rather than silently skipped.
            note("  no file of their own: fastfetch, starship — they follow the " +
                 "terminal's ANSI colours (no include mechanism exists)")

            if (root.batPending) {
                note("  running bat cache --build (a theme file alone is invisible to bat)")
                batGuard.start()
                batCache.running = true
                return
            }
            root.finish()
        }
    }
}
