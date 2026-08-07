pragma Singleton

// What the island is showing, and the outside world's handle on it.
//
// One place, not one per screen: two monitors must not disagree about whether
// the notch is open, and a keybinding has no idea which screen you meant. The
// surfaces bind to this; nobody assigns to their own `page`.
//
// Keys live in the compositor (niri has no protocol for shell-owned shortcuts),
// so they reach us through `qs -c buchhwin ipc call notch media`. That
// also means the shortcuts keep working when this shell is dead — they simply
// fail to reach anyone, instead of the compositor swallowing them.

import QtQuick
import Quickshell
import Quickshell.Io
import "../config"

Singleton {
    id: root

    // "" = collapsed. Any other value names the page.
    property string page: ""
    readonly property bool expanded: page !== ""

    // Pages that close themselves after a moment, because they report
    // something rather than offering something to do.
    //
    // Not called "transient": that is a reserved word in QML, and the error it
    // produces names this file but surfaces two levels up as the useless
    // "Type ShellSurface unavailable".
    readonly property var autoClosing: ["volume", "brightness", "mic", "notifications"]

    // The two that are readouts rather than places: they appear on their own
    // when something changes, and `surfaces.osd` is what stops them doing that.
    // The setting existed with nothing reading it, so switching it off changed
    // nothing at all — which is worse than not having it.
    readonly property var osdPages: ["volume", "brightness", "mic"]

    function show(name) {
        if (root.osdPages.indexOf(name) >= 0 && !Config.surfaces.osd)
            return          // the key still works; it just says nothing about it
        root.page = name
        if (root.autoClosing.indexOf(name) >= 0)
            idle.restart()
        else
            idle.stop()
    }

    function toggle(name) {
        if (root.page === name) root.collapse()
        else root.show(name)
    }

    function collapse() {
        idle.stop()
        root.page = ""
    }

    // ---------------------------------------------------- the quick panel's tab
    //
    // Which of the quick panel's four views is showing. It lives here rather
    // than in the page because things point at it from outside — the bar's
    // network, sound and gear pills all open the panel on the overview, where
    // the switches are — and the page itself is rebuilt every time the surface
    // opens, so a property of its own would forget which tab you were on
    // between openings.
    readonly property int quickOverview: 0
    readonly property int quickMedia: 1
    readonly property int quickNotifications: 2
    readonly property int quickTimer: 3
    // ⚠️ `quickSettings` IS GONE — the switches moved into the overview beside
    // the calendar on 06.08.2026, because the space there was empty and the
    // deep settings are going to M8 anyway. Five tabs became four.
    //
    // Named constants are what made that a small change: everything that used
    // to point at the settings tab now points at `quickOverview`, and the
    // compiler found every one of them. Numbers scattered through five files
    // would not have.
    property int quickTab: quickOverview

    // Open the panel on a named tab — or, if it is already open on that tab,
    // close it, so the gear behaves like every other toggle in the shell.
    function showQuick(tab) {
        if (root.page === "quick" && root.quickTab === tab) {
            root.collapse()
            return
        }
        root.quickTab = tab
        root.show("quick")
    }

    // ------------------------------------------------- the pointer on the notch
    //
    // ⚠️ `notchHover` IS GONE. It named the screen whose notch was under the
    // pointer, and it existed only so Shell.qml could create the pill beside it
    // on that screen. The notch now grows in place instead, so the state stayed
    // inside the one surface that owns it (ShellSurface's `mode`) and this key
    // had no reader left. A property nothing reads is the debt this project has
    // found five times.

    // ------------------------------------------------------------- launcher
    //
    // ⚠️ NOT A PAGE, AND THAT IS THE WHOLE POINT. Pages open AT the notch, so
    // the notch steps aside while one is up (see ui/surface/ShellSurface.qml's
    // `mode`). The launcher opens in the MIDDLE of the screen, and the brief is
    // explicit that a surface there leaves the notch alone. Making it a page
    // would hide the clock to show a program list on the other half of the
    // screen.
    //
    // It is also the one surface that can be open at the same time as a page,
    // which a single `page` string cannot express.
    property bool launcher: false

    function showLauncher() { root.launcher = true }
    function hideLauncher() { root.launcher = false }
    function toggleLauncher() { root.launcher = !root.launcher }

    Timer {
        id: idle
        interval: 1600
        onTriggered: root.collapse()
    }

    // ⚠️ One function per page, with NO arguments — deliberately.
    //
    // `qs ipc show` happily lists `show(page: string)`, but `qs ipc call notch
    // show media` answers "The following argument was not expected: media" in
    // quickshell 0.2.1, whichever order the options are given in. Parameterless
    // calls work. So the interface is shaped to what the tool can actually do
    // rather than to what its own listing suggests.
    //
    // ⚠️ AND THE ARGUMENT WAS ONLY HALF OF IT. Measured on 06.08.2026 against
    // the launcher, which had a parameterless `show()`: it printed the target's
    // function list and did nothing, while `toggle` and `hide` on the same
    // handler worked. So the NAME `show` is unusable on its own — it collides
    // with the `qs ipc show` subcommand. Nothing here is called `show` any
    // more, and tests/ipc-names.sh keeps it that way.
    //
    //     qs -c buchhwin ipc call notch media
    //     qs -c buchhwin ipc call notch collapse
    IpcHandler {
        target: "notch"

        function media(): void { root.toggle("media") }
        function volume(): void { root.toggle("volume") }
        function quick(): void { root.toggle("quick") }
        function notifications(): void { root.toggle("notifications") }
        // None of these three closes itself: they are places you look around
        // in or choose from, not reports that have finished being read.
        function calendar(): void { root.toggle("calendar") }
        function tray(): void { root.toggle("tray") }
        // The workspace map. Like the calendar and the tray it is a place
        // you look around in, so it does not close itself.
        function workspaces(): void { root.toggle("workspaces") }
        function wallpaper(): void { root.toggle("wallpaper") }
        function event(): void { root.toggle("event") }
        function brightness(): void { root.toggle("brightness") }
        // ⚠️ `show`, not `toggle`. It is fired by the mute key right after the
        // state changed, so pressing the key twice in a row must show the new
        // state twice — a toggle would close the readout on the second press,
        // exactly when there is something new to read.
        function mic(): void { root.show("mic") }
        function session(): void { root.toggle("session") }
        function clipboard(): void { root.toggle("clipboard") }
        function calculator(): void { root.toggle("calculator") }
        function timer(): void { root.toggle("timer") }
        // The quick panel, opened straight onto its settings view. This is what
        // the gear on the bar calls, and what the settings key is bound to —
        // the bar's gear used to have no handler at all and was, in the words of
        // the report, "stumm": it did nothing and did not say so either.
        function settings(): void { root.showQuick(root.quickSettings) }
        function collapse(): void { root.collapse() }
        function state(): string { return root.page }
    }

    // ⚠️ Lower case, no digits, in both the target and the verb. The smoke test
    // reads every keybinding with /ipc call ([a-z]+) ([a-z]+)/ and checks the
    // pair exists; a name like `barToggle` would not match the expression at
    // all, so the binding would go unchecked rather than fail.
    IpcHandler {
        target: "bar"

        // The bar is built and off by default — the notch is the surface. This
        // is how it gets tried out without editing shell.json, which was the
        // only way until now.
        function toggle(): void {
            Config.bar.enabled = !Config.bar.enabled
            Config.save()
        }
        function state(): string { return Config.bar.enabled ? "on" : "off" }
    }

    // Its own target rather than a verb on `notch`, because it is not one:
    // `qs -c buchhwin ipc call launcher toggle` says what it does, and the
    // notch's verb list stays a list of the notch's pages.
    IpcHandler {
        target: "launcher"

        function toggle(): void { root.toggleLauncher() }
        // ⚠️ `open`, NOT `show`. An IPC function called `show` cannot be called
        // from the command line at all: `qs ipc show` is quickshell's own
        // subcommand, so `qs -c buchhwin ipc call launcher show` prints the
        // target's function list and returns without doing anything. Measured —
        // `toggle` and `hide` both worked, `show` left the launcher `closed`
        // and printed the list. Nothing user-facing depended on it (the two key
        // bindings use `toggle`), which is exactly why it could sit there
        // broken: a function nobody can call is the same debt as a key nobody
        // reads. tests/ipc-names.sh keeps the name from coming back.
        function open(): void { root.showLauncher() }
        function hide(): void { root.hideLauncher() }
        function state(): string { return root.launcher ? "open" : "closed" }
    }
}
