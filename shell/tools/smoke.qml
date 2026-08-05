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

            root.ok("theme tokens exist",
                    Theme.panelBg !== undefined && Theme.radiusLg > 0
                    && Theme.space4 > 0 && Theme.fontSize > 0)
            root.ok("glass tokens exist",
                    Theme.glassRimTop !== undefined
                    && Theme.glassSheen !== undefined
                    && Theme.hairline > 0)

            // ------------------------------------------------------ ipc
            // Every verb the generated keybindings call has to exist, or a key
            // answers with an error nobody sees. Checked against the config
            // rather than a list typed here, so a new binding cannot be added
            // without its verb.
            var verbs = ["media", "volume", "quick", "notifications", "calendar",
                         "tray", "wallpaper", "event", "brightness", "session",
                         "clipboard", "collapse", "state"]
            var binds = Config.keys.binds
            var orphans = []
            for (var b = 0; b < binds.length; b++) {
                var arg = String(binds[b].arg || "")
                var m = arg.match(/ipc call notch ([a-z]+)/)
                if (m && verbs.indexOf(m[1]) < 0)
                    orphans.push(binds[b].key + " → " + m[1])
            }
            root.ok("no keybinding calls an ipc verb that does not exist" +
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

            // Ical is a parser rather than a device, so it has no `available`;
            // it still has to build, and it is the one piece with real logic.
            root.ok("services/Ical builds", Services.Ical !== null)

            note(root.failures === 0
                 ? "smoke: all good"
                 : "ABORT: " + root.failures + " check(s) failed")
            Qt.callLater(Qt.quit)
        }
    }
}
