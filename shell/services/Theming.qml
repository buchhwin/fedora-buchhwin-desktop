pragma Singleton

// The thing that makes "change the palette, everything follows" true.
//
// ⚠️ NOTHING DID THIS BEFORE, and the file that most needed it said otherwise:
// tools/render.qml's own header claims it runs "whenever the palette or a look
// setting changes (from the running shell)". Nothing in shell/ started it — no
// Process, no watcher, no Connections. Measured by grepping for every way a
// process can be launched.
//
// What that meant in use: pick a wallpaper, and the SHELL recolours instantly
// (QML bindings all the way down from Config to Theme), while GTK, Qt, kitty
// and niri sit on the old colours until somebody types `bhctl theme apply`.
// Half of the project's central promise, quietly untrue — and
// ui/notch/pages/WallpaperPage.qml even promised the other half in a comment.
//
// ⚠️ IT DOES NOT RENDER AT STARTUP. The files on disk were written the last
// time something changed; rewriting them on every login is a process spawn and
// a fistful of file writes to produce byte-identical output. So the first
// settled state is only RECORDED, and rendering happens on changes after that.
// "Nothing happens while nothing is happening" is the standard this project is
// held to.
import QtQuick
import Quickshell
import Quickshell.Io
import "../config"
import "../theme"

Singleton {
    id: root

    // There is no hardware behind this one; it is available as soon as there is
    // a palette to render. Every service carries the flag — see services/qmldir.
    readonly property bool available: Scheme.ready

    property bool busy: false
    property string lastError: ""

    // ⚠️ A LOG, because this service does its work in another process and would
    // otherwise fail in complete silence — which is exactly how the thing it
    // replaces went unnoticed for a milestone. `bhctl doctor` can read it, and
    // so can anyone wondering why a palette did not arrive.
    //
    // It only ever holds the last few lines: an append-forever file on a
    // desktop that runs for weeks is a slow leak, not a diagnostic.
    property var _lines: []
    FileView { id: logFile; path: "/tmp/buchhwin-theming.log" }
    function log(s) {
        var l = root._lines.slice()
        l.push(s)
        while (l.length > 20) l.shift()
        root._lines = l
        logFile.setText(l.join("\n") + "\n")
    }

    // Everything the renderer actually reads, as one string. A change to any of
    // it means the generated files would come out different; a change to
    // anything else must NOT spawn a process.
    //
    // ⚠️ Built from the same values render.qml consumes, deliberately by hand
    // rather than by walking the config: a `JSON.stringify(Config)` would also
    // catch the notch geometry and the key bindings, and every keystroke in the
    // settings window would then rewrite twelve foreign config files.
    //
    // ⚠️ THE `settled` GUARD IS NOT AN OPTIMISATION, IT IS THE CRASH GUARD.
    // Touching two dozen JsonAdapter properties while the adapter is still
    // deserialising is exactly the shape that segfaults quickshell — the
    // backtrace sits in `JsonAdapter::deserializeRec`, and ui/Shell.qml
    // documents the Weather service being kept out of construction for that
    // reason. Before the config has settled this reads ONE property and
    // returns; afterwards the adapter is done and the rest is safe.
    readonly property string fingerprint: {
        if (!Config.settled)
            return ""
        var t = Config.theme, l = Config.look, g = Config.theming
        return [t.palette, t.accent, t.customColor,
                l.rounding, l.borderWidth, l.opacityPanel, l.opacityTerminal,
                l.fontUi, l.fontMono, l.fontSize, l.profile,
                g.enabled, g.mode,
                g.gtk, g.qt, g.kitty, g.alacritty, g.niri, g.btop, g.bat,
                g.fastfetch, g.delta, g.tmux, g.starship, g.lazygit,
                // ⚠️ THE COLOURS THEMSELVES, not the palette's NAME. The first
                // version watched `Scheme.name` and `theme.palette`, and the
                // acceptance test failed on the very case this service exists
                // for: choosing a different wallpaper leaves the name at
                // "wallpaper" and changes only the colours, so the fingerprint
                // never moved and nothing was re-rendered. Measured — kitty's
                // theme.conf came back byte-identical after a wallpaper change.
                //
                // Twenty-six short strings, compared once per change. It is
                // also the honest question: "did the colours change", not "did
                // the setting that usually changes them change".
                // The palette as it was WRITTEN, not as a property reports it.
                // See the FileView below for why that distinction had to be
                // made the hard way.
                paletteFile.text()].join("")
    }

    property string _seen: ""

    onFingerprintChanged: root._consider()

    // ⚠️ THE PALETTE IS WATCHED AS A FILE, NOT AS A SIGNAL — and that is the
    // fourth attempt, after three that did not work and were each measured:
    //
    //   1. reading Scheme.colors inside the fingerprint's JS block. Never fired
    //      again after the first evaluation; a binding whose first run takes an
    //      early `return` does not reliably carry the dependencies of the
    //      branch it skipped.
    //   2. `Connections { target: Scheme; onColorsChanged }`. Never fired —
    //      and this project already had that written down as a trap for
    //      singletons that are still coming into existence.
    //   3. the prescribed replacement, a bound property plus on…Changed. Also
    //      never fired, while the palette demonstrably re-derived: the cache
    //      file on disk changed its `source` and its `base` inside the test
    //      window, every time.
    //
    // What IS certain: the service is bound to the live Scheme, not a second
    // instance — when it arms it reports the same `base` that is on disk.
    //
    // So this stops asking the singleton and asks the file, which is the one
    // mechanism this project has never had trouble with: Config watches
    // shell.json exactly this way and has been reliable since M1. It also makes
    // the fingerprint honest — it now contains the palette AS WRITTEN rather
    // than a property's opinion of it.
    FileView {
        id: paletteFile
        path: Scheme.palettePath
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: root._consider()
    }

    function _consider() {
        // Both guards matter. Before the config settles the fingerprint is
        // built from adapter defaults, and rendering those would write the
        // wrong colours into every foreign config with no error anywhere —
        // exactly the failure Config.qml documents for one-shot reads.
        if (!Config.settled || !Scheme.ready || !root.fingerprint.length)
            return

        if (root._seen === "") {
            // First settled state: record it, render nothing. See the note above.
            root._seen = root.fingerprint
            root.log("armed on palette " + Scheme.name)
            return
        }
        if (root._seen === root.fingerprint)
            return

        root._seen = root.fingerprint
        root.log("something changed — rendering in " + debounce.interval + " ms")
        debounce.restart()
    }

    // A palette change is one event, but it arrives as several property
    // changes — palette, then the derived colours, then `ready`. Rendering on
    // each would spawn three processes to produce one result.
    Timer {
        id: debounce
        // ⚠️ 800 ms, not 300. Measured: a wallpaper change produced TWO renders
        // in a row — the palette file is written, then read back, and each is a
        // change the fingerprint sees. Two processes for one result. The window
        // has to be wider than that write-then-reload round trip, and 800 ms is
        // still nothing to a human who has just clicked a picture.
        interval: 800
        onTriggered: root.render()
    }

    // Runs the same tool the installer and `bhctl` run. One renderer, three
    // callers — a second copy of this logic is how the predecessor ended up
    // with two sets of colours that disagreed.
    function render() {
        if (root.busy) {
            // Something changed while we were writing. Go round once more when
            // this one finishes rather than running two at a time.
            debounce.restart()
            return
        }
        root.busy = true
        root.log("running: " + proc.command.join(" "))
        proc.running = true
    }

    Process {
        id: proc
        // `env` as the binary rather than an environment property: it is the
        // one form that is certain to exist, and the tool needs both variables.
        //
        // `-p <root>` rather than `-c buchhwin`: the running shell already holds
        // that config name, and a second instance under the same name is a
        // question this does not need to ask.
        command: ["env", "BUCHHWIN_TOOL=render", "QT_QPA_PLATFORM=offscreen",
                  "qs", "-p", Quickshell.shellPath("")]

        onExited: function (code) {
            root.busy = false
            // ⚠️ The tool exits 0 even when it refuses to write — it says so in
            // its log instead. Silence here would mean a palette that never
            // reached anything, reported as success.
            root.lastError = code === 0 ? "" : "render exited " + code
            root.log(code === 0 ? "render finished" : "RENDER FAILED, exit " + code)
        }
    }
}
