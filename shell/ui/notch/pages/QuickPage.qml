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

RowLayout {
    id: root
    spacing: Theme.space4

    // Which view is showing. The value lives in Ipc, not here: the gear on the
    // bar opens this panel already on the settings view, and this page is built
    // afresh every time the surface opens, so a property of its own would
    // forget the tab between openings.
    readonly property int tab: Ipc.quickTab

    // ⚠️ ONE WIDTH FOR ALL FOUR TABS, and it is a bug fix rather than tidiness.
    // Measured on the running VM: the panel was 669 px wide on Overview and
    // 619 px on Settings, so it changed size by 50 px every time you touched a
    // tab. Each view was simply asking for whatever its own contents wanted,
    // and the surface follows the content on both axes (see NotchContent).
    //
    // ⚠️ It went from 20 to 24 grid units when the switches moved in beside the
    // calendar. Measured, one step at a time: at 20 the tile read "Do not
    // dis…", at 22 "Do not distu…", at 24 the whole name fits. A switch whose
    // name is cut off is a switch you have to guess at.
    //
    // ⚠️ Widening the PANEL is the fix rather than the tile, because the tile
    // cannot ask for what it needs: its label is `Layout.fillWidth` with
    // `elide: Text.ElideRight` (ui/quick/Tile.qml), so it silently accepts
    // whatever it is given and cuts the text. Making it demand its natural
    // width instead would break the grid on a narrow screen, where eliding is
    // the correct behaviour.
    // ⚠️ It is deliberately MORE than `notch.minExpandedWidth` (619): that key
    // is a FLOOR from the reference screenshot, not a ceiling, and the quick
    // panel is the one page whose job is to gather things rather than show one.
    //
    // ⚠️ Declared through `Layout.preferredWidth` rather than by assigning
    // `implicitWidth`. A Layout computes its own implicit size and writes it,
    // so assigning it means whoever writes last wins — which is a size that
    // changes on rearrange.
    readonly property int contentWidth: Theme.space6 * 24

    // ------------------------------------------------------------------- rail
    // ⚠️ SYMBOLS DOWN THE LEFT, NOT PILLS ACROSS THE TOP — his choice. The
    // component is `common/IconRail.qml` rather than something built here,
    // because the settings window (M8) has the same strip and building it twice
    // is how the predecessor ended up with two sidebars that drifted apart.
    //
    // ⚠️ The glyphs were chosen by `tests/icons.sh`, not by taste: `grid_view`
    // and `space_dashboard` are both MISSING from "Material Icons Round", which
    // is how "Overview" ended up as `dashboard`.
    // ⚠️ SIX ENTRIES, AND TWO OF THEM ARE DOORS RATHER THAN TABS. His request
    // of 07.08.2026: a button for the theme menu and one for the wallpapers,
    // beside the four views. Both already exist as their own surfaces, on
    // Mod+Shift+A and Mod+Shift+W — rebuilding either as a fifth and sixth tab
    // would be a second theme grid to drift from the first, which is the
    // mistake this file's header spends a paragraph on.
    //
    // So an entry may carry a `page`, and the rail opens that instead of
    // switching tab. Two behaviours in one strip, told apart by the DATA rather
    // than by the index — an index test would need correcting every time the
    // order changed.
    readonly property var railEntries: [
        { icon: "dashboard",     tooltip: "Overview" },
        { icon: "music_note",    tooltip: "Media" },
        { icon: "notifications", tooltip: "Notifications" },
        { icon: "timer",         tooltip: "Timer" },
        { icon: "palette",       tooltip: "Theme",     page: "theme" },
        { icon: "wallpaper",     tooltip: "Wallpaper", page: "wallpaper" }
    ]

    IconRail {
        // ⚠️ `fillHeight` AND `centred`, not `AlignTop`. The rail used to sit at
        // the top of a panel as tall as a month grid, so three quarters of the
        // strip was empty. Spreading the symbols over that whole height was
        // tried first and he turned it down — they belong together as a group,
        // in the middle.
        Layout.fillHeight: true
        centred: true
        currentIndex: root.tab
        entries: root.railEntries

        onActivated: function (i) {
            var e = root.railEntries[i]
            if (e && e.page)
                Ipc.toggle(String(e.page))
            else
                Ipc.quickTab = i
        }
    }

    // Everything that is not the rail. It is its own column so the rail stays
    // the height of four symbols instead of stretching to the calendar.
    ColumnLayout {
        id: body
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: root.contentWidth
        spacing: Theme.space4

    // The way out of the panel entirely — the full settings window. On its own
    // row now that the tabs have left the top, right-aligned so it does not
    // read as a fifth entry.
    RowLayout {
        Layout.fillWidth: true
        Item { Layout.fillWidth: true }
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

        // ------------------------------------------- the switches and levels
        // ⚠️ THE SAME QuickSettings THE SETTINGS TAB USED TO BE, PUT HERE —
        // not a copy. Two sets of tiles would drift: one would learn about a
        // new switch and the other would not, and they would sit on one screen
        // disagreeing about whether the wifi is on.
        //
        // It brings its own volume and brightness rows, which is why the two
        // this column used to carry are gone rather than kept: the panel would
        // otherwise have shown each slider twice.
        //
        // His decision on 06.08.2026 — the space beside the calendar was empty,
        // and the deep settings are going to M8 anyway. Five tabs became four.
        QuickSettings {
            Layout.fillWidth: true
        }

        }
    }

    // The everyday switches stay here: the panel is what you reach for while
    // working, and the window is where you go to change how the desktop is
    // built. Two places on purpose, not a duplication.
    }   // body

    // ⚠️ THE PLACEHOLDER IS GONE, AND SO IS EVERYTHING THAT SERVED IT. This used
    // to set a `note` property to "The settings window is still to come", show
    // it in a small line under the panel, and clear it again after four seconds
    // on a Timer. With a window to open, none of those three has a writer any
    // more — and a property nothing writes, a line nothing fills and a timer
    // nothing starts are the same debt as a config key nothing reads, which
    // this project has now found six times. They went out with the placeholder.
    //
    // Opening the window also shuts the panel: leaving both up would put two
    // ways to change the same setting on screen at once.
    function openSettings() {
        Ipc.collapse()
        Ipc.showSettings()
    }
}
