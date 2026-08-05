// One window per screen: the silhouette, the bar contents on it, the island in it.
//
// This replaces the two windows M3 started with. They could not work: with the
// bar on, the island was simply hidden behind it, and the concave shoulder had
// nothing to blend into. The plan says so directly — bar-on and bar-off are the
// same drawn silhouette with barH = 34 or barH = 0.
//
// The window is as tall as the island can ever get. It reserves nothing; a
// separate Strut reserves the COLLAPSED height, which is the whole reason the
// two are separate windows rather than one.

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
    WlrLayershell.layer: WlrLayer.Top

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

    implicitWidth: root.barEnabled ? 0
                 : Math.min(root.screen ? root.screen.width : root.islandW,
                            root.islandW + Config.notch.flare * 2)

    // `islandH` is animated, so the window follows the shape down rather than
    // snapping to the collapsed size at the START of a close, which would cut
    // the closing animation off halfway.
    implicitHeight: Math.max(root.islandH, root.targetIslandHeight) + Config.notch.flare

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"            // literal-ok: absence of colour, not a colour

    // ⚠️ The mask is the INPUT region, and it must follow the drawn shape, not
    // the window. Masking the whole window turns the entire top strip of the
    // screen into a click trap even where nothing is painted.
    mask: Region {
        item: hitArea
    }

    // ---------------------------------------------------------------- state
    // Held in one place, not per screen: two monitors must not disagree about
    // whether the island is open, and a keybinding cannot say which screen it
    // meant. See ipc/Ipc.qml — that is also what `qs ipc call notch …` drives.
    readonly property string page: root.notchEnabled ? Ipc.page : ""
    readonly property bool expanded: page !== ""

    readonly property real barH: root.barEnabled ? Config.bar.height : 0

    // The content decides both sizes, including which floor applies — a volume
    // readout and a calendar want very different minimums, and hard-coding the
    // calendar's here is what made the volume slider enormous.
    readonly property real targetIslandWidth:
        root.expanded ? notch.implicitWidth : Config.notch.collapsedWidth
    readonly property real targetIslandHeight:
        root.expanded ? notch.implicitHeight
                      : Math.max(Config.bar.height, root.barH)

    // One pair of animated numbers drives the shape, the hit area and the
    // contents, so they cannot disagree about how far open the island is.
    property real islandW: Config.notch.collapsedWidth
    property real islandH: Config.bar.height

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

    Silhouette {
        anchors.fill: parent
        barHeight: root.barH
        islandWidth: root.islandW
        islandHeight: root.islandH
        flare: root.notchEnabled ? Config.notch.flare : 0
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

            // Clicking the island opens it, and clicking it again closes it.
            // Media when something is playing, otherwise the volume page —
            // "show me what is going on" without having to choose first.
            TapHandler {
                onTapped: Ipc.toggle(Services.Media.available ? "media" : "volume")
            }

            NotchContent {
                id: notch
                anchors.fill: parent
                page: root.page
                // The clock moves into the island exactly when the bar is not
                // there to hold it.
                showClock: !root.barEnabled
                // For tray menus, which need a real window to open against.
                // The bar passes the same thing; with the bar off this is the
                // only one there is.
                hostWindow: root
            }
        }
    }

    // ------------------------------------------------------------- triggers
    // Volume changes turn the island INTO the slider. Not an OSD next to it —
    // the same shape, a different size and a different page.
    // A new notification turns the island into the notification page.
    //
    // ⚠️ This Connections object is also what CREATES the notification service.
    // QML builds a singleton on first access, so a service nobody references
    // never starts — and the notification daemon that never registers answers
    // notify-send with "The name is not activatable", which reads like a D-Bus
    // fault rather than "nothing asked for it". Same lesson as the palette
    // layer in M2, one floor down.
    Connections {
        target: Services.Notifications
        enabled: root.notchEnabled
        function onArrived(n) { Ipc.show("notifications") }
    }

    Connections {
        target: Services.Audio
        enabled: Services.Audio.available && root.notchEnabled
        function onVolumeChanged() { Ipc.show("volume") }
        function onMutedChanged() { Ipc.show("volume") }
    }
}
