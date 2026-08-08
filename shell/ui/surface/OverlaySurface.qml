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
    // ⚠️ THIS WHITELIST IS WHY ESC WORKED ON SOME PAGES AND NOT OTHERS, and it
    // was reported exactly that way: "bei manchen nur Esc, bei manchen nix".      // english-ok: quoted brief
    // A page that is not named here never receives keyboard focus, so its Esc
    // handler — if it even had one — could never fire. Nine of sixteen pages had
    // no handler and five of those could not have used one.
    //
    // The split is not "which page has a text field" but "did you OPEN this, or
    // did it appear at you". Volume, brightness and the microphone readout are
    // raised BY a key you just pressed and dismiss themselves; taking the
    // keyboard for them would pull focus out of the editor mid-sentence, which
    // is the fault the original comment is guarding against. Everything you open
    // on purpose can be closed with Esc.
    readonly property bool wantsKeys:
        Ipc.page === "event" || Ipc.page === "wallpaper" || Ipc.page === "session"
        || Ipc.page === "theme"
        || Ipc.page === "calendar" || Ipc.page === "quick"
        || Ipc.page === "clipboard" || Ipc.page === "calculator"
        || Ipc.page === "notifications" || Ipc.page === "timer"
        || Ipc.page === "tray" || Ipc.page === "workspaces"
        || Ipc.page === "media"

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

    // ⚠️⚠️ THE SIZE IS TAKEN ONCE THE LAYOUT HAS STOPPED MOVING, not on every
    // measurement — and this is the last visible step of the stutter.
    //
    // Bound straight to `card.implicitWidth` the window followed the layout
    // through BOTH of its passes. Measured with WAYLAND_DEBUG on one opening of
    // the quick panel:
    //
    //     set_size(150, 34)     the idle shape
    //     set_size(672, 306)    first pass
    //     set_size(712, 376)    second pass — exactly pagePadding * 2 wider
    //
    // The 40 px is the circle NotchContent's loader documents: a page is
    // measured inside a width that came from the page's own measurement, so the
    // two only agree after a second pass. That second `set_size` lands WHILE the
    // scale-and-fade is running, so the card visibly grows a second time in the
    // middle of its own animation. Not a stutter in the numbers — a re-target.
    //
    // `Qt.callLater` collapses repeated calls in the same turn of the event
    // loop into one, so both passes are absorbed and the window is told the
    // final size once. It does NOT fix the circle — that needs pages with a
    // natural width, which is a change to every page — it stops the circle from
    // reaching the compositor.
    //
    // ⚠️ NOT a Timer with a duration. Guessing a number that is "long enough for
    // the layout" is the flake that comes back on a slower machine; callLater is
    // ordering, and ordering is what the fault is made of.
    property real settledW: 1
    property real settledH: 1
    function settleSize() {
        root.settledW = Math.max(1, card.implicitWidth)
        root.settledH = Math.max(1, card.implicitHeight)
    }

    Connections {
        target: card
        function onImplicitWidthChanged() { Qt.callLater(root.settleSize) }
        function onImplicitHeightChanged() { Qt.callLater(root.settleSize) }
    }

    implicitWidth: root.settledW
    implicitHeight: root.settledH

    mask: Region { item: card }

    // ⚠️ ESC LIVES HERE, ONCE, rather than in every page. Seven of sixteen pages
    // carried their own handler and nine did not, so closing a surface depended
    // on which surface it was — and every new page would have had to remember.
    // The host knows how to close itself; a page does not need to.
    //
    // Pages keep their own handlers where Esc means something ELSE first (the
    // calculator clears, the calendar returns to today). Those consume it and
    // this never sees it, which is the correct precedence: the innermost thing
    // that has an answer wins.
    Item {
        id: card
        anchors.centerIn: parent

        focus: true
        Keys.onEscapePressed: Ipc.collapse()

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
        // ⚠️⚠️ THE SIZE IS SET, NOT ANIMATED, AND THAT IS THE WHOLE REASON THIS
        // SURFACE FEELS DIFFERENT NOW. There used to be a `Behavior` on
        // `implicitWidth` and one on `implicitHeight` here — and this window's
        // own `implicitWidth`/`implicitHeight` are bound to them, so every frame
        // of every open re-sized a Wayland layer surface.
        //
        // That is protocol, not drawing: `set_size` plus an `ack_configure`
        // round trip with niri, a buffer of a new size (the swapchain discarded
        // every frame), a fresh blur and corner-radius calculation for the new
        // geometry, and a new input region. Measured on the VM at 60 Hz, ONE
        // opening of the quick panel: 11 × `set_size`, 9 × `ack_configure`.
        // One per frame. At 144 Hz, about 21.
        //
        // ⚠️ AND UNLIKE THE NOTCH THIS SURFACE CANNOT SIMPLY BE OVERSIZED. The
        // notch has blur and shadow switched off (`surface("buchhwin-notch",
        // notchRadius, false, false)`) so spare room costs nothing there; this
        // one is translucent and blurred, and niri applies both to the WHOLE
        // surface, so a surface bigger than what it draws comes out as the
        // blurred, colour-fringed halo described at the top of this file.
        //
        // So the size lands on the target immediately — ONE re-size per page
        // instead of one per frame — and the motion is carried by `scale` and
        // `opacity` above, which are GPU transforms the compositor never hears
        // about. The card growing from 0.92 while fading in is what "grows out
        // of the notch" actually looks like; the surface underneath it was never
        // the part anybody could see.

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
