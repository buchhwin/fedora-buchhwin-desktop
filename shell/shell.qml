// The one entry point.
//
//   qs -c buchhwin                          the desktop
//   BUCHHWIN_TOOL=dump-tokens qs -p shell   a headless tool
//
// There is deliberately no second entry point for tools. Quickshell makes the
// folder of the file it is given the config root, so a tool started by its own
// path would put theme/ and config/ "outside the config folder" and the
// singletons would never register — the tool would then quietly compute
// different values than the shell it is supposed to describe.
//
// One root means the renderer, the token dump and the running desktop all walk
// the same import graph. That is not tidiness, it is the reason a palette
// switch can be trusted to produce the same colours everywhere.

import QtQuick
import Quickshell

ShellRoot {
    id: root

    readonly property string tool: Quickshell.env("BUCHHWIN_TOOL") || ""

    LazyLoader {
        active: root.tool !== ""
        source: root.tool !== "" ? "tools/" + root.tool + ".qml" : ""
    }

    LazyLoader {
        active: root.tool === ""
        source: "ui/Shell.qml"
    }
}
