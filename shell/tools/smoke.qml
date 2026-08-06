// The smoke test: start everything the desktop is made of, headless, and say
// so if any of it failed to come into existence.
//
//   BUCHHWIN_TOOL=smoke QT_QPA_PLATFORM=offscreen qs -p shell
//
// ⚠️ THIS IS THE CHECK A LINTER CANNOT DO. qmllint reads files; it does not
// build the object graph. It cannot see a missing qmldir entry, a singleton
// shadowed by a Qt type, or a `Connections { target: <singleton> }` that
// crashes on a singleton still being constructed — and every one of those has
// turned this desktop black at some point during development. The plan called
// for this from M1 and it was never written, so the CI has been linting and
// calling it proof.
//
// ⚠️ IT DOES NOT START THE SURFACES. A PanelWindow needs a Wayland compositor
// with wlr-layer-shell, which a CI container does not have. What it does start
// is everything BELOW the surfaces — config, migrations, theme, every service —
// which is where the singleton faults live. The surfaces themselves are checked
// on the VM, by looking at them.
//
// The plan names this file shell/tests/headless.qml. It is here instead because
// quickshell treats the folder of the file it is given as the config root: a
// second root would give the tools a different import graph from the shell, and
// then the thing being tested is not the thing that runs. Same reason there is
// only one entry point — see shell.qml.
import QtQuick
import Quickshell
import Quickshell.Io
import "../services" as Services
import "../config"
import "../theme"
import "../ipc"
import "../common"
import "../ui/common" as Ui

Scope {
    id: root

    property string report: ""
    property int failures: 0

    FileView { id: out; path: "/tmp/buchhwin-smoke.txt" }
    function note(s) { report += s + "\n"; out.setText(report) }

    function ok(what, cond) {
        if (cond) note("  ok    " + what)
        else { failures++; note("  FAIL  " + what) }
    }

    // A singleton that failed to build is `null` here rather than throwing, and
    // QML says so only in a warning on stderr that nothing reads. Hence a test.
    function service(name, obj) {
        if (obj === null || obj === undefined) {
            failures++
            note("  FAIL  services/" + name + " did not build")
            return
        }
        // Every service carries `available`; the rule is in the plan and the
        // point of it is that the ui can ask rather than assume. A service
        // without one will be used as though it were always there.
        if (obj.available === undefined) {
            failures++
            note("  FAIL  services/" + name + " has no `available` flag")
            return
        }
        note("  ok    services/" + name + " (available: " + obj.available + ")")
    }

    // A pill with something in it, built off screen purely so the check below
    // can ask whether it carries a tap handler of its own. Nothing draws it.
    Ui.Pill {
        id: probe
        interactive: true
        Ui.BarText { text: "Media" }
    }

    // Is there a TapHandler on the pill itself? `data` holds an Item's children
    // and its handlers together; a TapHandler is the one with a gesture policy,
    // which the HoverHandler beside it does not have.
    function pillHasOwnTap() {
        var d = probe.data
        for (var i = 0; i < d.length; i++)
            if (d[i] && d[i].gesturePolicy !== undefined)
                return true
        return false
    }

    // ⚠️ WaitFor, not a Timer, and the difference is documented in Config.qml:
    // `loaded` turns true one event-loop step BEFORE the JsonAdapter pushes the
    // parsed values into its properties. A timer that happens to fire in that
    // gap reads defaults and reports them as the truth. The first version of
    // this file used a 300 ms Timer and failed its own "config settled" check —
    // which is the test working, on itself.
    WaitFor {
        condition: Config.settled

        onTimedOut: {
            note("buchhwin smoke — ABORT: the configuration never settled")
            Qt.callLater(Qt.quit)
        }

        onReady: {
            note("buchhwin smoke — building every singleton headless")

            // ------------------------------------------------------ config
            root.ok("config settled", Config.settled)
            root.ok("no migration error: " + Config.migrationError,
                    Config.migrationError.length === 0)
            root.ok("config version matches the migration chain",
                    Config.version === Migrations.current)

            // ------------------------------------------------------ theme
            // All 26 palette names resolve. `hex()` answers Scheme.unknown for
            // a name it does not know — magenta, impossible to miss in a
            // screenshot, and equally impossible to notice in CI unless
            // something looks. Asked by name rather than by colour, so the
            // tripwire against literals stays satisfied and there is still only
            // one place that decides what "unknown" looks like.
            var names = ["rosewater", "flamingo", "pink", "mauve", "red",
                         "maroon", "peach", "yellow", "green", "teal", "sky",
                         "sapphire", "blue", "lavender", "text", "subtext1",
                         "subtext0", "overlay2", "overlay1", "overlay0",
                         "surface2", "surface1", "surface0", "base", "mantle",
                         "crust"]
            var missing = []
            for (var i = 0; i < names.length; i++)
                if (Scheme.hex(names[i]) === Scheme.unknown)
                    missing.push(names[i])
            root.ok("all 26 palette names resolve" +
                    (missing.length ? " (missing: " + missing.join(", ") + ")" : ""),
                    missing.length === 0)

            // The neutral set, asked the same question. tools/render.qml builds
            // it with FromImage.neutral() to theme a single program grey while
            // the rest stay coloured; a name missing from it would come out as
            // one black surface in one program — the kind of gap that is only
            // ever found by looking.
            var neutral = FromImage.neutral(true, 0)
            var greyMissing = []
            for (var g = 0; g < names.length; g++)
                if (!neutral || !neutral.colors || !neutral.colors[names[g]])
                    greyMissing.push(names[g])
            root.ok("the neutral set has all 26 names" +
                    (greyMissing.length ? " (missing: " + greyMissing.join(", ") + ")" : ""),
                    greyMissing.length === 0)

            // ⚠️ TWO VOCABULARIES FOR ONE COLOUR, checked rather than trusted.
            //
            // The shell draws with ROLES (Theme.bg), the renderer writes with
            // PALETTE KEYS (Scheme.hex("base")) — it has to, because it must be
            // able to read the same role out of a second, grey colour set that
            // Theme knows nothing about. Theme.qml says the two are the same
            // thing; here they are compared, so that renaming a role or
            // repointing it cannot silently give foreign applications different
            // colours from our own surfaces.
            var roles = [[Theme.bg, "base"], [Theme.bgDim, "mantle"],
                         [Theme.bgDeep, "crust"], [Theme.surface, "surface0"],
                         [Theme.surfaceHigh, "surface1"],
                         [Theme.surfaceHigher, "surface2"],
                         [Theme.overlay, "overlay0"], [Theme.outline, "overlay1"],
                         [Theme.fgDisabled, "overlay2"], [Theme.fg, "text"],
                         [Theme.fgMuted, "subtext1"], [Theme.fgDim, "subtext0"],
                         [Theme.ok, "green"], [Theme.warn, "yellow"],
                         [Theme.error, "red"], [Theme.info, "sapphire"],
                         [Theme.accentAlt, "teal"]]
            var drifted = []
            for (var r = 0; r < roles.length; r++)
                if (Theme.hex(roles[r][0]) !== Scheme.hex(roles[r][1]))
                    drifted.push(roles[r][1])
            root.ok("every Theme role is the palette key the renderer writes" +
                    (drifted.length ? " (drifted: " + drifted.join(", ") + ")" : ""),
                    drifted.length === 0)

            root.ok("theme tokens exist",
                    Theme.panelBg !== undefined && Theme.radiusLg > 0
                    && Theme.space4 > 0 && Theme.fontSize > 0)
            root.ok("glass tokens exist",
                    Theme.glassRimBottom !== undefined
                    && Theme.glassSheen !== undefined
                    && Theme.hairline > 0)

            // ⚠️ THE TAP TARGET, because this one shipped. A TapHandler written
            // inside a Pill lands in the Pill's inner Item, which is sized to
            // its contents — so half the pill highlighted on hover and did
            // nothing on click. Measured on the quick panel's "Media" tab: pill
            // 68 x 29, target 44 x 21, 1050 px² lit and dead.
            //
            // The call sites are guarded statically by tests/tap-targets.sh.
            // This is the other half: that Pill still has a handler of its own
            // for them to rely on.
            root.ok("a Pill carries its own tap handler",
                    probe.width > 0 && probe.height > 0 && root.pillHasOwnTap())

            // ------------------------------------------------------ ipc
            // Every verb the generated keybindings call has to exist, or a key
            // answers with an error nobody sees. Checked against the config
            // rather than a list typed here, so a new binding cannot be added
            // without its verb.
            // ⚠️ BOTH TARGETS. The launcher is not a notch page — it has its
            // own ipc target — and a check that only knew about `notch` would
            // have let a typo in the launcher's key through silently, which is
            // the one thing this check exists to prevent.
            var verbs = ({
                "notch": ["media", "volume", "quick", "notifications", "calendar",
                          "tray", "wallpaper", "event", "brightness", "session",
                          "clipboard", "settings", "collapse", "state"],
                "launcher": ["toggle", "show", "hide", "state"],
                "bar": ["toggle", "state"]
            })
            var binds = Config.keys.binds
            var orphans = []
            for (var b = 0; b < binds.length; b++) {
                var arg = String(binds[b].arg || "")
                var m = arg.match(/ipc call ([a-z]+) ([a-z]+)/)
                if (!m)
                    continue
                if (!verbs[m[1]] || verbs[m[1]].indexOf(m[2]) < 0)
                    orphans.push(binds[b].key + " → " + m[1] + " " + m[2])
            }
            root.ok("no keybinding calls an ipc target or verb that does not exist" +
                    (orphans.length ? " (" + orphans.join(", ") + ")" : ""),
                    orphans.length === 0)

            // ------------------------------------------------------ services
            root.service("Compositor", Services.Compositor)
            root.service("Niri", Services.Niri)
            root.service("Power", Services.Power)
            root.service("Audio", Services.Audio)
            root.service("Media", Services.Media)
            root.service("Notifications", Services.Notifications)
            root.service("Brightness", Services.Brightness)
            root.service("Wallpaper", Services.Wallpaper)
            root.service("Calendar", Services.Calendar)
            root.service("Weather", Services.Weather)
            root.service("Location", Services.Location)
            root.service("Tray", Services.Tray)
            root.service("Clipboard", Services.Clipboard)
            root.service("Theming", Services.Theming)

            // ⚠️ NO EXCEPTION ANY MORE. Ical used to be waved through here as
            // "a parser rather than a device", while services/qmldir said every
            // service carries `available` "without exception". One of the two
            // was wrong, and it was cheaper to give the parser an honest flag
            // than to keep a rule with a hole in it.
            root.service("Ical", Services.Ical)

            note(root.failures === 0
                 ? "smoke: all good"
                 : "ABORT: " + root.failures + " check(s) failed")
            Qt.callLater(Qt.quit)
        }
    }
}
