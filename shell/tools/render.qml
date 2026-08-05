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
    function gtk4Css(m) {
        return head(false, m) +
            "@define-color window_bg_color " + col(m, "base") + ";\n" +
            "@define-color window_fg_color " + col(m, "text") + ";\n" +
            "@define-color view_bg_color " + col(m, "mantle") + ";\n" +
            "@define-color view_fg_color " + col(m, "text") + ";\n" +
            "@define-color headerbar_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color headerbar_fg_color " + col(m, "text") + ";\n" +
            "@define-color popover_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color popover_fg_color " + col(m, "text") + ";\n" +
            "@define-color card_bg_color " + col(m, "surface0") + ";\n" +
            "@define-color card_fg_color " + col(m, "text") + ";\n" +
            "@define-color sidebar_bg_color " + col(m, "mantle") + ";\n" +
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
            "    shadow {\n" +
            "        color \"" + col(m, "crust") + "b0\"\n" +
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
    FileView { id: log; path: "/tmp/buchhwin-render.log" }

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

            note("buchhwin render — palette " + Scheme.name +
                 " (" + Scheme.displayName + "), accent " + Config.theme.accent)
            note("  states: gtk=" + mGtk + " qt=" + mQt + " kitty=" + mKitty +
                 " niri=" + mNiri + "   (theming.enabled " + Config.theming.enabled +
                 ", theming.mode " + Config.theming.mode + ")")

            emitFile(mGtk, f1, root.cfg + "/gtk-3.0/gtk.css",
                     gtk3Css, offCss("gtk"), "gtk3 colours", "gtk")
            emitFile(mGtk, f2, root.cfg + "/gtk-3.0/settings.ini",
                     gtkSettings, offText("#", "gtk"), "gtk3 settings", "gtk")
            emitFile(mGtk, f3, root.cfg + "/gtk-4.0/gtk.css",
                     gtk4Css, offCss("gtk"), "gtk4 colours", "gtk")
            emitFile(mGtk, f4, root.cfg + "/gtk-4.0/settings.ini",
                     gtkSettings, offText("#", "gtk"), "gtk4 settings", "gtk")
            emitFile(mKitty, f5, root.cfg + "/kitty/theme.conf",
                     kittyTheme, offText("#", "kitty"), "kitty", "kitty")
            emitFile(mNiri, f6, root.cfg + "/niri/colors.kdl",
                     niriColours, offText("//", "niri"), "niri colours", "niri")
            emitFile(mQt, f7, root.cfg + "/qt6ct/colors/buchhwin.conf",
                     qtColors, offText("#", "qt"), "qt6ct", "qt")

            // ⚠️ The eight remaining keys in Config.theming have no builder
            // yet — btop, bat, fastfetch, git-delta, tmux, alacritty, starship
            // and lazygit are the next milestone. They are named here rather
            // than passed over in silence: a setting that does nothing is a
            // promise, and the only way to find out it was empty must not be
            // to try it.
            note("  no writer yet: alacritty, btop, bat, fastfetch, delta, " +
                 "tmux, starship, lazygit")

            note("done: " + written + " written, " + unchanged + " unchanged")
            if (root.threw) {
                note("buchhwin render — ABORT")
                note("  " + root.threw + " target(s) threw: " + root.thrown.join(", "))
            }
            Qt.callLater(Qt.quit)
        }
    }
}
