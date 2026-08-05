// What the island used to become: a surface of its own, floating under the notch.
//
// The island morphing into every page was the original design, and it was right
// for the volume readout it was drawn from. It stopped being right once the
// pages grew: a calendar is not a notch that got bigger, and asking one shape to
// be both meant the notch could never simply be a notch.
//
// So the pages live here now, and the notch gets out of the way while one is
// open (see ShellSurface's `mode`). Three things fall out of that, all of them
// improvements rather than compromises:
//
//   * The notch is only ever notch-sized, so its blur and shadow are too.
//   * This surface is only ever page-sized, for the same reason.
//   * Neither has to animate into a shape the other needs.
//
// ⚠️ THE SURFACE IS EXACTLY AS BIG AS WHAT IT DRAWS. From niri's own docs on
// layer rules: "niri has no way of knowing about invisible margins, and will
// draw the shadow behind the entire surface." Blur behaves the same way. A
// surface with a transparent border therefore gets a blurred, colour-fringed
// halo — which is precisely the "the colours bug out around it" that was
// reported for the notch.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../ipc"
import "../notch"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Public interface: config.kdl attaches the blur, shadow and corner radius
    // rules to this namespace. Renaming it here without renaming it there
    // loses all three silently.
    WlrLayershell.namespace: "buchhwin-overlay"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: root.wantsKeys ? WlrKeyboardFocus.OnDemand
                                                : WlrKeyboardFocus.None

    // Pages that are typed into need the keyboard; the rest must not steal it,
    // or opening the volume readout would take focus away from your editor.
    readonly property bool wantsKeys:
        Ipc.page === "event" || Ipc.page === "wallpaper" || Ipc.page === "session"
        || Ipc.page === "calendar" || Ipc.page === "quick"

    anchors { top: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"                    // literal-ok: absence of colour

    // Sits below the notch, with the island's own gap under it.
    margins.top: Config.bar.height + Theme.space2

    implicitWidth: Math.max(1, card.implicitWidth)
    implicitHeight: Math.max(1, card.implicitHeight)

    mask: Region { item: card }

    Rectangle {
        id: card
        anchors.centerIn: parent

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        radius: Theme.radiusLg
        color: Theme.panelBg

        // Grows out of nothing rather than appearing: slightly small and
        // slightly high, so it reads as coming from the notch above it. No
        // overshoot — the brief rules out anything springy.
        scale: Ipc.expanded ? 1 : 0.92
        opacity: Ipc.expanded ? 1 : 0
        transformOrigin: Item.Top

        Behavior on scale {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        Behavior on implicitWidth {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        Behavior on implicitHeight {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }

        NotchContent {
            id: content
            anchors.centerIn: parent
            page: Ipc.page
            // The clock belongs to the notch, never to a page.
            showClock: false
            hostWindow: root
        }
    }
}
