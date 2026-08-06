// A few pixels in a corner of the screen that open something when you rest in
// them.
//
// His idea: top-right for the notifications, top-left for the workspace map.
//
// ⚠️ NIRI ALREADY OWNS THE TOP-LEFT CORNER, and it is on by default. From its
// own docs, Configuration: Gestures.md: "Put your mouse at the very top-left
// corner of a monitor to toggle the overview", with `off` to disable. So a
// corner configured here has to be one niri is not using, or niri's has to be
// switched off — one gesture may not mean two things, and this project has
// already paid for that lesson once with the fullscreen strip.
//
// ⚠️ AND IT WAITS. A corner that fires the moment the pointer brushes it is a
// trap rather than a shortcut: you reach for a window's close button, you cross
// the corner, and a panel appears over what you were aiming at. `dwellMs` is the
// whole difference between the two, and it is a setting rather than a constant
// because how long feels right is not something anyone can decide for somebody
// else.
//
// ⚠️ THE SURFACE IS TINY AND HAS NO INPUT REGION BEYOND ITSELF. It sits on the
// `top` layer, which is above ordinary windows — so anything bigger than a few
// pixels would be stealing clicks from whatever is underneath it.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // "left" or "right". Only the top edge for now: the bottom corners are
    // where windows put their resize grips.
    required property string corner
    // What to do when the pointer has stayed long enough.
    signal triggered()

    WlrLayershell.namespace: "buchhwin-hotcorner"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    anchors {
        top: true
        left: root.corner === "left"
        right: root.corner === "right"
    }

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"          // literal-ok: absence of colour

    // Big enough to hit without looking, small enough to be out of the way.
    // The pointer is a single pixel; this is the target around it.
    implicitWidth: Theme.space2 * 2
    implicitHeight: Theme.space2 * 2

    HoverHandler { id: hover }

    // ⚠️ The timer is what makes this usable rather than hostile. It restarts on
    // entry and stops on exit, so crossing the corner does nothing at all and
    // resting in it does the thing.
    Timer {
        id: dwell
        interval: Config.surfaces.hotCornerDwellMs
        onTriggered: root.triggered()
    }

    Connections {
        target: hover
        function onHoveredChanged() {
            if (hover.hovered)
                dwell.restart()
            else
                dwell.stop()
        }
    }
}
