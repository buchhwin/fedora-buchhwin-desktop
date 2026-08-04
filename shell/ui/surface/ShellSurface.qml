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

    anchors { top: true; left: true; right: true }
    implicitHeight: Config.notch.expandedHeight + Config.notch.flare

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"            // literal-ok: absence of colour, not a colour

    // ⚠️ The mask is the INPUT region, and it must follow the drawn shape, not
    // the window. Masking the whole window turns the entire top strip of the
    // screen into a click trap even where nothing is painted.
    mask: Region {
        item: hitArea
    }

    // ---------------------------------------------------------------- state
    property string page: ""
    readonly property bool expanded: page !== "" && root.notchEnabled

    function show(name) { if (root.notchEnabled) root.page = name }
    function collapse() { root.page = "" }

    readonly property real barH: root.barEnabled ? Config.bar.height : 0

    readonly property real targetIslandWidth:
        root.expanded ? Math.max(Config.notch.minExpandedWidth, notch.implicitWidth)
                      : Config.notch.collapsedWidth
    readonly property real targetIslandHeight:
        root.expanded ? Config.notch.expandedHeight
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

            NotchContent {
                id: notch
                anchors.fill: parent
                page: root.page
                // The clock moves into the island exactly when the bar is not
                // there to hold it.
                showClock: !root.barEnabled
            }
        }
    }

    // ------------------------------------------------------------- triggers
    // Volume changes turn the island INTO the slider. Not an OSD next to it —
    // the same shape, a different size and a different page.
    Connections {
        target: Services.Audio
        enabled: Services.Audio.available
        function onVolumeChanged() { root.show("volume"); idle.restart() }
        function onMutedChanged() { root.show("volume"); idle.restart() }
    }

    Timer {
        id: idle
        interval: 1600
        onTriggered: root.collapse()
    }
}
