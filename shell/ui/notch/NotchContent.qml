// What is inside the island: the clock when collapsed, a page when open.
//
// Collapsed content comes straight from the reference screenshot — the clock,
// one line, centred, and nothing else. It is not a widget strip.
import QtQuick
import Quickshell
import "../../theme"
import "../../config"
import "../common"
import "pages"

Item {
    id: root

    property string page: ""
    // With the bar on, the clock lives out on the strip and the island stays
    // empty. From the plan: "Bar aus: nur Notch — Uhr · Media · Status wandern
    // in die Notch." So it is one clock that moves, never two on one screen.
    property bool showClock: true

    readonly property bool expanded: page !== ""

    // The island asks the content how wide it wants to be, never the reverse.
    implicitWidth: expanded && loader.item
        ? Math.max(Config.notch.minExpandedWidth, loader.item.implicitWidth)
        : Config.notch.collapsedWidth

    // Collapsed: the clock — but only when the bar is not already showing one.
    BarText {
        anchors.centerIn: parent
        visible: !root.expanded && root.showClock
        opacity: root.expanded ? 0 : 1
        text: {
            function p(n) { return n < 10 ? "0" + n : "" + n }
            return p(clock.hours) + ":" + p(clock.minutes)
        }
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    Loader {
        id: loader
        anchors.centerIn: parent
        width: parent.width - Theme.space5 * 2
        active: root.expanded
        asynchronous: true
        sourceComponent: root.page === "volume" ? volumePage
                       : root.page === "media" ? mediaPage
                       : root.page === "notifications" ? notificationsPage
                       : null

        // The shape leads, the contents follow — that is what makes the change
        // read as one movement rather than two things happening at once.
        opacity: root.expanded ? 1 : 0
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }

    Component { id: volumePage; VolumePage {} }
    Component { id: mediaPage; MediaPage {} }
    Component { id: notificationsPage; NotificationsPage {} }
}
