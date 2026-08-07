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
import "../common"
import "../notch"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Public interface: config.kdl attaches the blur, shadow and corner radius
    // rules to this namespace. Renaming it here without renaming it there
    // loses all three silently.
    WlrLayershell.namespace: "buchhwin-overlay"
    // ⚠️ `Overlay`, NOT `Top`, AND THAT IS THE WHOLE PANEL'S USABILITY. The
    // click-catcher — a fullscreen surface whose entire job is to swallow a
    // click and close the panel — was also on `Top`, and Shell.qml creates it
    // AFTER this one. wlr-layer-shell stacks within a layer by creation order,
    // so the catcher sat on top of the panel and ate every click meant for it —
    // "ich geh z. B. auf Medien oder auf Settings, schließt sich das Fenster und ich komme nicht in die Tab".  // english-ok: the report, quoted
    // Measured with `niri msg layers`: both namespaces in the Top layer, with
    // nothing deciding between them but the order they were made in.
    //
    // Raising the panel a layer is the fix rather than reordering the loaders,
    // because order is an accident and a layer is a promise. ShellSurface
    // already does exactly this when a window goes fullscreen.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: root.wantsKeys ? WlrKeyboardFocus.OnDemand
                                                : WlrKeyboardFocus.None

    // Pages that are typed into need the keyboard; the rest must not steal it,
    // or opening the volume readout would take focus away from your editor.
    readonly property bool wantsKeys:
        Ipc.page === "event" || Ipc.page === "wallpaper" || Ipc.page === "session"
        || Ipc.page === "theme"
        || Ipc.page === "calendar" || Ipc.page === "quick"
        || Ipc.page === "clipboard" || Ipc.page === "calculator"

    anchors { top: true }
    exclusionMode: ExclusionMode.Ignore
    color: "transparent"                    // literal-ok: absence of colour

    // ⚠️ AT THE TOP EDGE, WITH NO GAP — and this is a bug fix, not a style
    // choice. It used to sit below the notch with the island's own gap under
    // it, which left a band at the top of the screen that belonged to the
    // fullscreen ClickCatcher. Measured with a real pointer, one row at a time:
    // a click at y=41 closed the panel and a click at y=44 did not. The tab row
    // is at y=79. So aiming at a tab and landing a few pixels high shut the
    // window — which is exactly the "I click on Media or Settings and it
    // closes" that was reported, and it was nothing to do with the tabs.
    //
    // With the panel at the edge there is no dead band left to miss into, and
    // it also gives what the brief asks for: the surface grows out of the notch
    // rather than appearing under it. The notch is hidden while a page is open,
    // so nothing is covered that anybody is looking at.
    margins.top: 0

    implicitWidth: Math.max(1, card.implicitWidth)
    implicitHeight: Math.max(1, card.implicitHeight)

    mask: Region { item: card }

    Item {
        id: card
        anchors.centerIn: parent

        implicitWidth: content.implicitWidth
        implicitHeight: content.implicitHeight

        // The pane, drawn behind the page rather than as the page's own
        // background: a lit rim has to sit on top of the fill, and a Rectangle
        // can only have one flat border colour.
        GlassPane {
            anchors.fill: parent
            radius: Theme.radiusLg
            fill: Theme.panelBg
        }

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
