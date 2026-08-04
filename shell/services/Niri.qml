pragma Singleton

// The niri backend. The ONLY file in the shell that knows which compositor is
// running — everything else talks to Compositor.qml.
//
// State comes from `niri msg -j event-stream`: one JSON object per line, keyed
// by event name, pushed as things happen. No polling, and no second source of
// truth — the first event of each kind carries the full list, so there is
// never a moment where we have half the picture.
//
// ⚠️ The `-j` is not optional. Without it `niri msg event-stream` prints Rust's
// Debug formatting — `Workspace { id: 4, idx: 4, name: None, … }` — which looks
// close enough to JSON to write a parser against and is not.

import QtQuick
import Quickshell
import Quickshell.Io

Singleton {
    id: root

    // Every service carries this. On a machine where the stream never comes up
    // — no niri, or the socket is not reachable — the UI must be able to say
    // so rather than draw an empty bar that looks like a bug.
    readonly property bool available: _connected

    property var workspaces: []
    property var windows: []
    property int focusedWindowId: -1
    property int focusedWorkspaceId: -1
    property bool overviewOpen: false
    property string keyboardLayout: ""
    // niri reports whether the config it just loaded parsed. Worth surfacing:
    // a failed reload leaves the OLD config running, which otherwise looks
    // like "my change did nothing".
    property bool configFailed: false

    property bool _connected: false

    readonly property var focusedWindow: {
        for (var i = 0; i < windows.length; i++)
            if (windows[i].id === focusedWindowId)
                return windows[i]
        return null
    }

    readonly property var focusedWorkspace: {
        for (var i = 0; i < workspaces.length; i++)
            if (workspaces[i].id === focusedWorkspaceId)
                return workspaces[i]
        return null
    }

    // Workspaces in the order niri lays them out, not the order it reports
    // them — the event arrives unsorted and a bar that reshuffles its buttons
    // on every event is unusable.
    readonly property var orderedWorkspaces: {
        var list = []
        for (var i = 0; i < workspaces.length; i++)
            list.push(workspaces[i])
        list.sort(function (a, b) { return a.idx - b.idx })
        return list
    }

    function dispatch(args) {
        if (!args || !args.length)
            return
        action.command = ["niri", "msg", "action"].concat(args)
        action.running = true
    }

    function focusWorkspace(idx) { dispatch(["focus-workspace", String(idx)]) }
    function focusWindow(id) { dispatch(["focus-window", "--id", String(id)]) }
    function toggleOverview() { dispatch(["toggle-overview"]) }

    // One-shot actions. A second dispatch while the first is still running
    // would drop it, so each gets its own short-lived process.
    Process { id: action }

    Process {
        id: events
        command: ["niri", "msg", "-j", "event-stream"]
        running: true

        stdout: SplitParser {
            splitMarker: "\n"
            onRead: function (line) { root._handle(line) }
        }

        // niri restarting, or a config reload that replaces the socket, ends
        // the stream. Coming back is normal operation, not an error worth
        // shouting about — but never coming back must not look like "quiet".
        onExited: function () {
            root._connected = false
            retry.start()
        }
    }

    Timer {
        id: retry
        interval: 1000
        repeat: false
        onTriggered: events.running = true
    }

    function _handle(line) {
        if (!line || !line.length)
            return
        var e
        try {
            e = JSON.parse(line)
        } catch (err) {
            // A malformed line is not worth tearing the stream down for, but
            // it is worth not pretending we understood it.
            return
        }
        root._connected = true

        if (e.WorkspacesChanged !== undefined) {
            root.workspaces = e.WorkspacesChanged.workspaces || []
            for (var i = 0; i < root.workspaces.length; i++)
                if (root.workspaces[i].is_focused)
                    root.focusedWorkspaceId = root.workspaces[i].id
            return
        }
        if (e.WindowsChanged !== undefined) {
            root.windows = e.WindowsChanged.windows || []
            for (var j = 0; j < root.windows.length; j++)
                if (root.windows[j].is_focused)
                    root.focusedWindowId = root.windows[j].id
            return
        }
        if (e.WorkspaceActivated !== undefined) {
            var id = e.WorkspaceActivated.id
            var focused = e.WorkspaceActivated.focused
            var ws = root.workspaces.slice()
            for (var k = 0; k < ws.length; k++) {
                // niri sends one activation; every other workspace on the same
                // output stops being active. Applying only the positive half
                // leaves two workspaces highlighted at once.
                if (ws[k].id === id) {
                    ws[k].is_active = true
                    if (focused) ws[k].is_focused = true
                } else if (ws[k].output === root._outputOf(id)) {
                    ws[k].is_active = false
                    if (focused) ws[k].is_focused = false
                }
            }
            root.workspaces = ws
            if (focused) root.focusedWorkspaceId = id
            return
        }
        if (e.WindowOpenedOrChanged !== undefined) {
            var w = e.WindowOpenedOrChanged.window
            if (!w) return
            var list = root.windows.slice()
            var found = false
            for (var m = 0; m < list.length; m++)
                if (list[m].id === w.id) { list[m] = w; found = true; break }
            if (!found) list.push(w)
            root.windows = list
            if (w.is_focused) root.focusedWindowId = w.id
            return
        }
        if (e.WindowClosed !== undefined) {
            var closed = e.WindowClosed.id
            var rest = []
            for (var n = 0; n < root.windows.length; n++)
                if (root.windows[n].id !== closed) rest.push(root.windows[n])
            root.windows = rest
            if (root.focusedWindowId === closed) root.focusedWindowId = -1
            return
        }
        if (e.WindowFocusChanged !== undefined) {
            root.focusedWindowId = e.WindowFocusChanged.id === null
                ? -1 : e.WindowFocusChanged.id
            return
        }
        if (e.OverviewOpenedOrClosed !== undefined) {
            root.overviewOpen = e.OverviewOpenedOrClosed.is_open === true
            return
        }
        if (e.KeyboardLayoutsChanged !== undefined) {
            var kl = e.KeyboardLayoutsChanged.keyboard_layouts
            if (kl && kl.names && kl.names.length)
                root.keyboardLayout = kl.names[kl.current_idx || 0]
            return
        }
        if (e.KeyboardLayoutSwitched !== undefined) {
            // Only the index arrives here; the names came earlier.
            return
        }
        if (e.ConfigLoaded !== undefined) {
            root.configFailed = e.ConfigLoaded.failed === true
            return
        }
        // WindowUrgencyChanged, CastsChanged, WindowLayoutsChanged and
        // whatever a later niri adds: ignored on purpose. An unknown event is
        // not an error, and crashing the bar over one would be.
    }

    function _outputOf(wsId) {
        for (var i = 0; i < root.workspaces.length; i++)
            if (root.workspaces[i].id === wsId)
                return root.workspaces[i].output
        return ""
    }
}
