// The notch itself: one window per screen, carrying the silhouette, the bar
// contents on it, and the island in it.
//
// Bar and island are ONE drawn shape — the plan says so directly, and building
// them as two windows failed exactly as it predicted: with the bar on, the
// island vanished behind it and the concave shoulder had nothing to blend into.
//
// What is NOT here any more are the pages. The island used to become each of
// them, which was right for the volume readout it was drawn from and wrong for
// everything after: a calendar is not a notch that got bigger. They live in
// surface/OverlaySurface.qml now, and this window has three states instead —
// full, hidden, strip. See `mode`.
//
// It reserves no space; a separate Strut does that, which is the whole reason
// the two are separate windows.

import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../services" as Services
import "../../ipc"
import "../bar"
import "../notch"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    property bool barEnabled: true
    property bool notchEnabled: true

    // Public interface: config.kdl attaches the blur rule to this namespace.
    // Renaming it here without renaming it there loses the blur silently.
    WlrLayershell.namespace: "buchhwin-notch"

    // ⚠️ A FULLSCREEN WINDOW IS DRAWN ABOVE THE `top` LAYER. Measured: with the
    // terminal fullscreen, the strip was simply not on screen — not mis-sized,
    // not transparent, gone. `top` is the right home the rest of the time
    // (below fullscreen content, above ordinary windows), so the surface moves
    // to `overlay` exactly while it is needed there and back afterwards.
    //
    // That is also why the strip is a hairline rather than the whole notch: it
    // is the one thing allowed to sit over a fullscreen video, so it has to
    // earn the space, and hovering is what asks for more.
    WlrLayershell.layer: root.fullscreenHere ? WlrLayer.Overlay : WlrLayer.Top

    // ⚠️ THE WINDOW IS EXACTLY AS BIG AS WHAT IS DRAWN IN IT. Nothing here is
    // cosmetic — niri's blur rule applies to the whole LAYER SURFACE, not to
    // the shape painted on it.
    //
    // This was full width and a constant `expandedHeight + flare` = 149 px, so
    // the top fifth of the screen was permanently blurred while the island
    // itself was 150×34, and every window's upper edge sat behind that band.
    // Reported as "the blur is a fifth of the screen but the notch is not" —
    // which is exactly what it was.
    //
    // It is also the cheapest thing in the shell to get right: blurring
    // 1280×149 instead of 174×48 is roughly twenty-five times the full-screen
    // GPU reads, every frame, on a laptop.
    //
    // With the bar on, full width is correct — the bar really does span the
    // screen. With it off, the surface is the island plus its shoulders.
    anchors { top: true; left: root.barEnabled; right: root.barEnabled }

    //
    // ⚠️ AND IT HAS NO INVISIBLE MARGIN. From niri's own layer-rule docs:
    // "niri has no way of knowing about invisible margins, and will draw the
    // shadow behind the entire surface." Blur is the same. The window used to
    // carry `flare` px of transparent border for the shoulders to curve into —
    // and that border came out as a blurred, colour-fringed halo around the
    // pill. Reported as "the colours bug out around it", and that was it.
    //
    // The shoulders now curve within the island's own width instead, so what
    // the surface covers and what it paints are the same rectangle.
    implicitWidth: root.barEnabled ? 0 : Math.max(1, root.islandW)

    // `islandH` is animated, so the window follows the shape down rather than
    // snapping to the collapsed size at the START of a close, which would cut
    // the closing animation off halfway.
    implicitHeight: Math.max(1, root.islandH)

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"            // literal-ok: absence of colour, not a colour

    // ⚠️ The mask is the INPUT region, and it must follow the drawn shape, not
    // the window. Masking the whole window turns the entire top strip of the
    // screen into a click trap even where nothing is painted.
    mask: Region {
        item: hitArea
    }

    // ---------------------------------------------------------------- state
    // Which page is open is held in one place, not per screen: two monitors
    // must not disagree, and a keybinding cannot say which screen it meant.
    // See ipc/Ipc.qml — that is what `qs ipc call notch …` drives. The pages
    // themselves are drawn by surface/OverlaySurface.qml.
    readonly property real barH: root.barEnabled ? Config.bar.height : 0

    // ------------------------------------------------------------------ mode
    // The notch does not become the pages any more; it gets out of their way.
    //
    //   full    the pill with the clock — the resting state
    //   hidden  something is open AT the notch, and that surface has the stage
    //   strip   a window is fullscreen: a discreet dark bar, nothing more
    //
    // Hovering the strip brings the full notch back, and leaving returns it —
    // so the clock is never more than a pointer away, even in fullscreen.
    //
    // ⚠️ Only surfaces that open AT the notch hide it. A launcher in the middle
    // of the screen leaves it alone; that is a property of the surface, not a
    // special case here.
    readonly property bool fullscreenHere:
        root.screen ? Services.Compositor.focusedIsFullscreen(root.screen.width,
                                                              root.screen.height)
                    : false

    readonly property string mode:
        !root.notchEnabled ? "full"
      : Ipc.expanded ? "hidden"
      : (root.fullscreenHere && !hover.hovered) ? "strip"
      : "full"

    // The strip is deliberately thin and deliberately still THERE: a fullscreen
    // window with a hairline above it reads as fullscreen, while nothing at all
    // reads as a screen with a missing edge.
    readonly property real stripHeight:
        Math.max(2, Math.round(Config.notch.collapsedHeight / 8))

    readonly property real targetIslandWidth:
        root.mode === "hidden" ? 0
      : root.mode === "strip" ? Config.notch.collapsedWidth * 0.55
      : Config.notch.collapsedWidth

    // The island has its OWN height. It used to read `bar.height`, so resizing a
    // bar that was switched off resized the notch — two things that look
    // unrelated moving together is the kind of surprise that costs an evening.
    // With the bar on, the island still cannot be shorter than the bar, or the
    // one shared silhouette would have a step in it.
    readonly property real targetIslandHeight:
        root.mode === "hidden" ? 0
      : root.mode === "strip" ? root.stripHeight
      : Math.max(Config.notch.collapsedHeight, root.barH)

    // One pair of animated numbers drives the shape, the hit area and the
    // contents, so they cannot disagree about how far open the island is.
    property real islandW: Config.notch.collapsedWidth
    property real islandH: Config.notch.collapsedHeight

    Binding on islandW { value: root.targetIslandWidth }
    Binding on islandH { value: root.targetIslandHeight }

    // Soft, and deliberately not springy: the brief rules out overshoot.
    Behavior on islandW {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
    }
    Behavior on islandH {
        enabled: Theme.animate
        NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
    }

    // Brings the full notch back while the pointer is on the strip. On the
    // window rather than on the island, so the thin strip is easy to find.
    HoverHandler { id: hover }

    Silhouette {
        anchors.fill: parent
        barHeight: root.barH
        islandWidth: root.islandW
        islandHeight: root.islandH
        // Passed whole; Silhouette clamps it against its own geometry, which is
        // the only place that knows how much room is left. Clamping twice, with
        // two different limits, is how the two ended up disagreeing before.
        // The shoulders curve INSIDE `islandWidth`, so they never need room
        // outside the surface — see the note on implicitWidth above.
        flare: root.notchEnabled ? Config.notch.flare : 0
        cornerRadius: Config.notch.cornerRadius
        // The reference calls for a near-black island that stands clearly
        // apart from what is behind it — panelBg sat so close to the desktop
        // backdrop that the shape was invisible on screen.
        fill: Theme.bgDeep
    }

    // The clickable region: the bar strip plus the island. Kept as plain items
    // so the mask follows the same geometry the shape does.
    Item {
        id: hitArea
        anchors.fill: parent

        Item {
            id: barStrip
            width: parent.width
            height: root.barH
            visible: root.barEnabled

            BarContent {
                anchors.fill: parent
                hostWindow: root
            }
        }

        Item {
            id: island
            x: (parent.width - root.islandW) / 2
            y: 0
            width: root.islandW
            height: root.islandH
            visible: root.notchEnabled
            clip: true

            // Clicking the island opens the quick panel — the one surface
            // that answers "what is going on" without making you choose a
            // question first. It used to open media, or volume when nothing
            // was playing, which meant the same click did different things
            // depending on whether Spotify happened to be running.
            TapHandler { onTapped: Ipc.toggle("quick") }

            // What the notch itself shows: the clock, and only the clock. The
            // pages moved to surface/OverlaySurface.qml — see the note there
            // for why the island stopped morphing into them.
            NotchContent {
                id: notch
                anchors.fill: parent
                // Nothing but the clock lives here now, so `page` stays empty.
                page: ""
                // The clock moves into the island exactly when the bar is not
                // there to hold it — and never while the notch is a strip,
                // where there is no room for it.
                showClock: !root.barEnabled && root.mode === "full"
                hostWindow: root
                opacity: root.mode === "full" ? 1 : 0
                Behavior on opacity {
                    enabled: Theme.animate
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
            }
        }
    }

    // ------------------------------------------------------------- triggers
    // A volume change opens the volume page; a notification opens that one.
    // Both then float under the notch, and the notch steps aside while they
    // are up — see `mode` above.
    //
    // ⚠️ A NOTIFICATION NO LONGER OPENS THE NOTCH. It used to: an arriving
    // message called Ipc.show("notifications"), which took over whatever the
    // notch was showing and then closed again after 1.6 s, so the message was
    // both an interruption and gone before it could be acted on. Toasts have
    // their own surface now (ui/notif/ToastSurface.qml), in the top-right,
    // where they leave the notch alone — which is also the stated rule: only
    // surfaces that open AT the notch displace it.
    //
    // The reference that STARTS the notification server moved with it, into
    // Shell.qml. It used to live here, which quietly meant there was no
    // notification daemon at all on a machine with the notch switched off.

    Connections {
        target: Services.Audio
        enabled: Services.Audio.available && root.notchEnabled
        function onVolumeChanged() { Ipc.show("volume") }
        function onMutedChanged() { Ipc.show("volume") }
    }
}
