pragma Singleton

// What the island is showing, and the outside world's handle on it.
//
// One place, not one per screen: two monitors must not disagree about whether
// the notch is open, and a keybinding has no idea which screen you meant. The
// surfaces bind to this; nobody assigns to their own `page`.
//
// Keys live in the compositor (niri has no protocol for shell-owned shortcuts),
// so they reach us through `qs -c buchhwin ipc call notch show media`. That
// also means the shortcuts keep working when this shell is dead — they simply
// fail to reach anyone, instead of the compositor swallowing them.

import QtQuick
import Quickshell
import Quickshell.Io

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
    readonly property var autoClosing: ["volume", "brightness", "notifications"]

    function show(name) {
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
        function wallpaper(): void { root.toggle("wallpaper") }
        function event(): void { root.toggle("event") }
        function collapse(): void { root.collapse() }
        function state(): string { return root.page }
    }
}
