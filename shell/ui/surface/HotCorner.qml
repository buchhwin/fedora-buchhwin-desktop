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
//
// ⚠️⚠️ THIS DOES NOT WORK YET, AND `surfaces.hotCorners` DEFAULTS TO "off"
// BECAUSE OF IT. What is measured, so the next attempt does not start over:
//
//   * The surface EXISTS. `niri msg layers` lists `buchhwin-hotcorner` on the
//     Top layer, alongside notch, strut and wallpaper.
//   * It DRAWS NOTHING. A probe rectangle in a screaming colour filling the
//     whole item produced ZERO pixels anywhere on screen — checked in both top
//     corners. So this is not "the hover is not firing", it is "the window has
//     no size or is not mapped", and chasing the handler was the wrong end.
//   * No QML warning of any kind in the shell's log.
//   * `Theme.space2` is 16, so `implicitWidth`/`implicitHeight` are not zero
//     from the token side.
//   * Hover was tried at (1912,8), (1915,4), (1919,0) and (1904,0) — all
//     silent, which is consistent with an unmapped window.
//
// WHAT TO TRY NEXT, in order:
//   1. `anchors { top: true; right: true }` — two ADJACENT edges. Every other
//      surface in this shell anchors to one edge or to three. It is the one
//      thing here that has no precedent in the project, and a PanelWindow that
//      does not know how wide it should be is a plausible zero.
//      Test it by giving the window explicit `width`/`height` instead.
//   2. `mask: Region { item: hitArea }` evaluated before `hitArea` has a size.
//      Try without the mask at all.
//   3. Only then look at the handler.

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

    // ⚠️ AN ITEM, AND AN EXPLICIT INPUT REGION. A HoverHandler written straight
    // into the PanelWindow of a surface that draws NOTHING never fired —
    // measured at four positions inside the corner, all silent. ShellSurface
    // gets away with the bare handler because it paints a silhouette and sets
    // `mask: Region { item: … }`; an empty, fully transparent window has
    // nothing for the compositor to hand a pointer to.
    //
    // So there is a real (if invisible) Item here, the mask names it, and the
    // handler lives on it.
    Item {
        id: hitArea
        anchors.fill: parent
        HoverHandler {
            id: hover
            onHoveredChanged: hovered ? dwell.restart() : dwell.stop()
        }
    }

    mask: Region { item: hitArea }

    // ⚠️ The timer is what makes this usable rather than hostile. It restarts on
    // entry and stops on exit, so crossing the corner does nothing at all and
    // resting in it does the thing.
    Timer {
        id: dwell
        interval: Config.surfaces.hotCornerDwellMs
        onTriggered: root.triggered()
    }

}
