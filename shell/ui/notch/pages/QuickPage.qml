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

    // ⚠️ ONE WIDTH FOR ALL FIVE TABS, and it is a bug fix rather than tidiness.
    // Measured on the running VM: the panel was 669 px wide on Overview and
    // 619 px on Settings, so it changed size by 50 px every time you touched a
    // tab. Each view was simply asking for whatever its own contents wanted,
    // and the surface follows the content on both axes (see NotchContent).
    //
    // The number is the widest view — the month grid beside the weather column
    // needs about 621 px — rounded up onto the 32 px grid with a little air.
    // ⚠️ It is deliberately MORE than `notch.minExpandedWidth` (619): that key
    // is a FLOOR from the reference screenshot, not a ceiling, and the quick
    // panel is the one page whose job is to gather things rather than show one.
    //
    // ⚠️ Declared through `Layout.preferredWidth` rather than by assigning
    // `implicitWidth`. A Layout computes its own implicit size and writes it,
    // so assigning it means whoever writes last wins — which is a size that
    // changes on rearrange.
    readonly property int contentWidth: Theme.space6 * 20

    // ------------------------------------------------------------------- tabs
    RowLayout {
        Layout.fillWidth: true
        // The row is on every tab, so pinning the width here pins it for all of
        // them. Everything else may be narrower; nothing may be wider, and
        // tests/quick-panel.sh measures that rather than trusting it.
        Layout.preferredWidth: root.contentWidth
        spacing: Theme.space2

        Repeater {
            model: ["Overview", "Media", "Notifications", "Timer", "Settings"]

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
    //
    // ⚠️ AND EVERY ONE OF THEM NEEDS `visible: active`. This is "der abstand im  english-ok: the report, quoted
    // quicksettings menu passt immer noch nicht", and it is not a padding       english-ok: the report, quoted
    // problem at all. A Loader with `active: false` is 0 px tall — but it is
    // still VISIBLE, and QtQuick.Layouts gives every visible item its row
    // spacing whether or not it has any height. Three loaders sit between the
    // tab row and the content, so on Settings two of them were contributing
    // `space4` each for nothing.
    //
    // Measured on the VM before the fix, column x=700 through the Overview pill
    // and the Wi-Fi tile: pill bottom y=49, tile top y=98 — a 48 px gap where
    // `space4` is 16. Exactly three spacings where there should be one.
    Loader {
        Layout.fillWidth: true
        active: root.tab === Ipc.quickNotifications
        visible: active
        asynchronous: true
        sourceComponent: notificationsTab
    }

    // The same TimerPage that Mod+Shift+T opens, not a second one. A countdown
    // shown in two places that disagree about how long is left is worse than a
    // countdown in one place — the same reason the calendar and the media
    // transport are reused rather than rebuilt.
    Loader {
        Layout.fillWidth: true
        active: root.tab === Ipc.quickTimer
        visible: active
        asynchronous: true
        // ⚠️ `timerTab`, not `TimerPage {}`. This one was left behind when the
        // other two were fixed, in the same file, four lines above the comment
        // that explains why it is wrong — a recipe is what a Loader wants, and
        // an instance is built once and kept forever.
        sourceComponent: timerTab
    }

    Loader {
        Layout.fillWidth: true
        active: root.tab === Ipc.quickSettings
        visible: active
        asynchronous: true
        sourceComponent: settingsTab
    }

    // ⚠️ COMPONENTS, NOT INSTANCES — the same trap NotchContent.qml already
    // names, and it was walked into here anyway. `sourceComponent: QuickSettings
    // {}` writes an OBJECT into a property that wants a recipe: the object is
    // built at once and stays built, so the settings view and the notification
    // list existed the whole time the panel was open on some other tab. That is
    // the opposite of what the Loader is for — "a closed list does not exist" —
    // and it is the likeliest reason the panel sometimes came up far too tall,
    // reported as "sometimes the gap gets too big, down to the bottom of the
    // screen, but only sometimes".
    Component { id: notificationsTab; NotificationsPage {} }
    Component { id: timerTab; TimerPage {} }
    Component { id: settingsTab; QuickSettings {} }

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
