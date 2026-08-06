pragma Singleton

// The compositor, as the rest of the shell is allowed to see it.
//
// A thin layer on purpose. Everything above this file talks about workspaces
// and windows; only services/Niri.qml knows that they arrive as JSON lines
// from `niri msg -j event-stream`. That boundary is the whole point: swapping
// the compositor later is one file, not a search through the interface.
//
// The `available` flag is not decoration. On a machine where the stream never
// comes up, a surface must be able to say "no compositor" instead of drawing
// an empty strip that looks like a bug.

import QtQuick
import Quickshell
import "." as Services

Singleton {
    id: root

    readonly property bool available: Services.Niri.available

    readonly property var workspaces: Services.Niri.orderedWorkspaces
    readonly property var windows: Services.Niri.windows
    readonly property var focusedWindow: Services.Niri.focusedWindow
    readonly property var focusedWorkspace: Services.Niri.focusedWorkspace
    readonly property bool overviewOpen: Services.Niri.overviewOpen
    readonly property string keyboardLayout: Services.Niri.keyboardLayout

    // A reload that failed leaves the PREVIOUS config running, which from the
    // outside looks like "my change did nothing". Surfaced so a surface can
    // say which it was.
    readonly property bool configFailed: Services.Niri.configFailed

    // Whether the focused window fills the given screen. The screen comes from
    // the caller — a surface knows which output it is on, a service does not.
    function focusedIsFullscreen(screenW, screenH) {
        return Services.Niri.isFullscreen(Services.Niri.focusedWindow, screenW, screenH)
    }

    function focusWorkspace(idx) { Services.Niri.focusWorkspace(idx) }
    function focusWindow(id) { Services.Niri.focusWindow(id) }
    function toggleOverview() { Services.Niri.toggleOverview() }
    function moveWindowToWorkspace(windowId, wsIdx) {
        Services.Niri.moveWindowToWorkspace(windowId, wsIdx)
    }
}
