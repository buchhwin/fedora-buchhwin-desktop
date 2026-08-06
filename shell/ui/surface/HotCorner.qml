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
// WHAT HAS BEEN RULED OUT, each with one variable changed at a time:
//
//   * `implicitWidth`/`implicitHeight` vs explicit `width`/`height`
//                                       — explicit 40 DREW, implicit did not
//   * literal `width: 24`               — drew NOTHING
//   * literal `width: 40`               — DREW, at x 1880..1918
//   * `exclusiveZone: -1` vs `ExclusionMode.Ignore`  — no difference
//   * `mask: Region { item: … }` present vs absent   — no difference
//   * HoverHandler on a bare PanelWindow vs on an Item — no difference
//   * `anchors { top: true; right: true }` is NOT the problem: ToastWindow uses
//     exactly the same two adjacent edges and works
//
// ⚠️ AND THE ONE RESULT THAT MAKES NO SENSE YET, which is where the next
// attempt should start: when it DID draw at 40, only about SIX of the forty
// rows appeared, at y 34..38 — and 34 is exactly the notch strut's height. So
// either something clips it to a few rows, or that magenta was not this surface
// at all and the real one has never been visible. Find out which before
// changing anything else.
//
// Do NOT go back to the input region or the handler. Two rounds went there on
// the assumption that the window existed and was merely deaf; the probe
// rectangle took thirty seconds and showed the window was not being drawn at
// all. Colour it in FIRST.

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

    // ⚠️ `exclusiveZone: -1`, NOT just `ExclusionMode.Ignore`, and the
    // difference is the whole feature. This project's own Strut.qml says it:
    // "-1 does not mean 'reserve nothing' — it additionally means DO NOT MOVE
    // ME". Without it the compositor honours the notch's strut and places this
    // 34 px down the screen — measured with a probe rectangle, which came out
    // at y=34 instead of y=0. A hot corner that is not in the corner is not a
    // hot corner.
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"          // literal-ok: absence of colour

    // ⚠️ `width`/`height`, NOT `implicitWidth`/`implicitHeight`. With the
    // implicit pair the surface was created — niri listed it — and drew NOTHING,
    // anywhere on a 1920×976 screen. A probe rectangle in a screaming colour
    // found zero pixels. With explicit sizes it appears immediately. Two rounds
    // went into the input region and the handler before the probe moved the
    // search here.
    width: Theme.space2 * 3
    height: Theme.space2 * 3

    Item {
        id: hitArea
        anchors.fill: parent
        HoverHandler {
            id: hover
            onHoveredChanged: hovered ? dwell.restart() : dwell.stop()
        }
    }

    // ⚠️ The timer is what makes this usable rather than hostile. It restarts on
    // entry and stops on exit, so crossing the corner does nothing at all and
    // resting in it does the thing.
    Timer {
        id: dwell
        interval: Config.surfaces.hotCornerDwellMs
        onTriggered: root.triggered()
    }

}
