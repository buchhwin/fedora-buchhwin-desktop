// Clicking beside the island closes it.
//
// niri has no focus-grab, so this cannot be had for free: it takes a real
// fullscreen surface that swallows the click.
//
// ⚠️ The opacity is 0.004 and that number is load-bearing. A surface that is
// FULLY transparent is treated as "not drawn" and is given an EMPTY input
// region — so it catches nothing and the island can never be dismissed. A
// hair above zero keeps it a real surface while remaining invisible.
//
// It exists only while the island is open, which is also why it cannot get in
// the way of anything else: there is nothing to get in the way of the rest of
// the time.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../ipc"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "buchhwin-catcher"
    // Below the island, above everything else: a click must reach this before
    // it reaches a window, but never before it reaches the island itself.
    //
    // ⚠️ THAT SENTENCE WAS A WISH, NOT A FACT, UNTIL THE PANEL MOVED UP. This
    // surface and the panel were both on `Top`, where stacking follows creation
    // order — and Shell.qml creates this one second, so it was in front of the
    // thing it is supposed to sit behind, and the panel could not be used at
    // all. The panel is on `Overlay` now; this one stays here, which is what
    // makes the comment true.
    WlrLayershell.layer: WlrLayer.Top

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"            // literal-ok: absence of colour, not a colour

    Rectangle {
        anchors.fill: parent
        color: Theme.scrim
        // Not zero — see above. Anything that reads this as "why not just 0"
        // will spend an afternoon on it.
        opacity: 0.004              // literal-ok: input-region threshold, not a style

        TapHandler { onTapped: Ipc.collapse() }
    }
}
