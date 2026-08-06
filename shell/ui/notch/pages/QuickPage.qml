pragma ComponentBehavior: Bound

// The quick panel: the one surface that answers "what is going on".
//
// It is what clicking the notch opens, and it is deliberately the only page
// that gathers things rather than showing one: the month, the weather, the
// handful of sliders worth reaching for, and the way into the settings. Every
// other page is a single answer to a single question.
//
// FOUR TABS. It started with two, on the argument that a third column would
// stop the panel being a glance — and that argument was about COLUMNS, which is
// still right and is why none of this sits side by side. As tabs they cost
// nothing: only one is built at a time, and each stays as sparse as it was.
//
// Overview and Media were already here. Notifications is the same page Mod+N
// opens, and Settings is the switches — network, bluetooth, night light, do not
// disturb, microphone, the bar — with sound and brightness under them.
//
// ⚠️ NOT ONE COPY MORE. The month, the media transport and the notification
// list are the SAME components the standalone pages use, never a second one
// built to fit here. Two month grids would drift — different weekday order,
// different today marker — and disagree on one screen.
//
// Two columns inside the overview, because the island is wide and short. The
// calendar is the tall thing, so it takes the left side and sets the height;
// everything else stacks beside it.
//
// ⚠️ The calendar here is the SAME CalendarPage, not a copy of it. A second
// month grid would drift from the first — different weekday order, different
// today marker — and the two would sit on the same screen disagreeing.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../config"
import "../../../ipc"
import "../../../services" as Services
import "../../common"
import "../../quick"

ColumnLayout {
    id: root
    spacing: Theme.space4

    // Which view is showing. The value lives in Ipc, not here: the gear on the
    // bar opens this panel already on the settings view, and this page is built
    // afresh every time the surface opens, so a property of its own would
    // forget the tab between openings.
    readonly property int tab: Ipc.quickTab

    // ------------------------------------------------------------------- tabs
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        Repeater {
            model: ["Overview", "Media", "Notifications", "Settings"]

            Pill {
                id: tabPill
                required property int index
                required property string modelData
                interactive: true
                // Accent marks the tab you are on, and nothing else on this row.
                active: root.tab === tabPill.index
                BarText {
                    text: tabPill.modelData
                    font.pixelSize: Theme.fontSizeSm
                    color: tabPill.active ? Theme.accentFg : Theme.fgMuted
                }
                onClicked: Ipc.quickTab = tabPill.index
            }
        }

        Item { Layout.fillWidth: true }

        // Still on the tab row rather than inside a tab, because it leaves the
        // panel entirely — it is the way to the full settings WINDOW, which is
        // M8 and does not exist yet. The everyday switches are the fourth tab
        // beside it now, so this is no longer the only thing it could have been.
        Pill {
            interactive: true
            Icon { text: "open_in_new"; size: Theme.fontSizeLg }
            onClicked: root.openSettings()
        }
    }

    // ---------------------------------------------------------------- media
    // The same MediaPage the island uses on its own — artwork, title, transport.
    // A second one would drift, exactly as a second calendar would.
    MediaPage {
        Layout.fillWidth: true
        visible: root.tab === Ipc.quickMedia
    }

    // ⚠️ `Loader`, not `visible: false`, for these two. The month and the media
    // transport are cheap and already built; a notification list and a settings
    // view that starts wifi scans are not, and building them to leave them
    // hidden is exactly the idle work this desktop is not allowed to do. Each
    // exists only while its tab is the one showing.
    Loader {
        Layout.fillWidth: true
        active: root.tab === Ipc.quickNotifications
        asynchronous: true
        sourceComponent: NotificationsPage {}
    }

    Loader {
        Layout.fillWidth: true
        active: root.tab === Ipc.quickSettings
        asynchronous: true
        sourceComponent: QuickSettings {}
    }

    // --------------------------------------------------------------- overview
    RowLayout {
        visible: root.tab === Ipc.quickOverview
        spacing: Theme.space5

        CalendarPage {
        Layout.alignment: Qt.AlignTop
    }

    ColumnLayout {
        Layout.alignment: Qt.AlignTop
        Layout.minimumWidth: Theme.space6 * 9
        spacing: Theme.space4

        // ------------------------------------------------------------ weather
        ColumnLayout {
            Layout.fillWidth: true
            spacing: Theme.space1

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space3
                visible: Services.Weather.available

                Icon {
                    text: Services.Weather.iconName
                    size: Theme.fontSizeXl
                    color: Theme.fg
                }

                ColumnLayout {
                    spacing: 0   // literal-ok: absence of a gap — the temperature and its
                                 // description are one label on two lines, not two things
                    BarText {
                        text: Math.round(Services.Weather.temperature) + "°"
                        font.pixelSize: Theme.fontSizeLg
                        font.weight: Theme.weightSemibold
                    }
                    BarText {
                        text: Services.Weather.description
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                    }
                }

                Item { Layout.fillWidth: true }

                BarText {
                    text: Services.Location.name
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                    elide: Text.ElideRight
                    Layout.maximumWidth: Theme.space6 * 4
                }
            }

            // The place is set through the shared picker, so the settings
            // window (M8) will use the same component rather than a second one
            // — and choosing "Passau" anywhere shows up here in the same
            // instant, because both read one binding.
            LocationPicker {
                Layout.fillWidth: true
                compact: true
                visible: !Services.Weather.available || Services.Location.guessed
            }
        }

        // ------------------------------------------------------------ sliders
        // Rows appear only where the hardware does. On a machine with no
        // backlight the brightness row is absent rather than dead — a slider
        // that moves nothing is worse than no slider.
        LevelRow {
            Layout.fillWidth: true
            visible: Services.Audio.available
            icon: Services.Audio.muted ? "volume_off"
                : Services.Audio.volume > 0.5 ? "volume_up" : "volume_down"
            value: Services.Audio.volume
            live: !Services.Audio.muted
            onMoved: function (f) { Services.Audio.setVolume(f) }
            onNudged: function (d) {
                Services.Audio.setVolume(Math.max(0, Math.min(1,
                    Services.Audio.volume + d / steps)))
            }
        }

        LevelRow {
            Layout.fillWidth: true
            visible: Services.Brightness.available
            icon: "brightness_6"
            value: Services.Brightness.fraction
            onMoved: function (f) { Services.Brightness.set(f) }
            onNudged: function (d) {
                Services.Brightness.set(Math.max(0.01, Math.min(1,
                    Services.Brightness.fraction + d / steps)))
            }
        }

        BarText {
            Layout.fillWidth: true
            visible: !Services.Audio.available && !Services.Brightness.available
            text: "No controls on this machine"
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
        }

        }
    }

    // Why the gear does not open anything yet. One line, and it clears itself.
    BarText {
        Layout.fillWidth: true
        visible: root.note.length > 0
        text: root.note
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        wrapMode: Text.WordWrap
    }

    // The full settings window is still M8. The difference now is that the
    // everyday switches are one tab away rather than nowhere, so this says what
    // is missing instead of standing in for it.
    property string note: ""
    function openSettings() {
        root.note = "The settings window is still to come — the switches are under Settings"
        forget.restart()
    }
    Timer { id: forget; interval: 4000; onTriggered: root.note = "" }
}
