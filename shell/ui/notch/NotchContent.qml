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

    // The island's own window, handed down so a tray menu has somewhere to
    // open. Without it a right-click in the tray page does nothing and says
    // nothing — see pages/TrayPage.qml.
    property var hostWindow: null

    // With the bar on, the clock lives out on the strip and the island stays
    // empty. From the plan: "Bar aus: nur Notch — Uhr · Media · Status wandern
    // in die Notch." So it is one clock that moves, never two on one screen.
    property bool showClock: true

    readonly property bool expanded: page !== ""

    // The island asks the content how big it wants to be, never the reverse —
    // on BOTH axes. The page must never read the island's current size back, or
    // the two would chase each other; pages that need a reference size use the
    // configured number instead (see pages/WallpaperPage.qml).
    implicitWidth: expanded && loader.item
        ? Math.max(Config.notch.minExpandedWidth, loader.item.implicitWidth)
        : Config.notch.collapsedWidth

    implicitHeight: expanded && loader.item
        ? loader.item.implicitHeight + Theme.space5 * 2
        : Config.bar.height

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
                       : root.page === "quick" ? quickPage
                       : root.page === "calendar" ? calendarPage
                       : root.page === "tray" ? trayPage
                       : root.page === "wallpaper" ? wallpaperPage
                       : root.page === "event" ? eventPage
                       : null

        // The shape leads, the contents follow — that is what makes the change
        // read as one movement rather than two things happening at once.
        opacity: root.expanded ? 1 : 0
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }

    // ⚠️ `sourceComponent` needs a Component, never an instance. QML accepts an
    // instance without a word of complaint and then never builds the thing.
    Component { id: volumePage; VolumePage {} }
    Component { id: mediaPage; MediaPage {} }
    Component { id: notificationsPage; NotificationsPage {} }
    Component { id: quickPage; QuickPage {} }
    Component { id: calendarPage; CalendarPage {} }
    Component { id: trayPage; TrayPage { hostWindow: root.hostWindow } }
    Component { id: wallpaperPage; WallpaperPage {} }
    Component { id: eventPage; EventPage {} }
}
