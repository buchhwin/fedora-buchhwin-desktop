pragma ComponentBehavior: Bound

// The month, as a page of the island.
//
// Pure arithmetic: no service, no network, nothing that can be unavailable. The
// clock it reads is the same SystemClock the collapsed island shows, so the two
// can never disagree about what day it is.
//
// Weather belongs on this page and is deliberately absent. It needs a location,
// and the place to type a location in is the settings window, which M8 builds.
// A weather line with nowhere to set the location would be a decoration that
// lies on someone else's machine.
import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../../theme"
import "../../common"

ColumnLayout {
    id: root
    spacing: Theme.space3
    implicitWidth: Theme.space6 * 18

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // The month on display. Kept as year+month rather than a Date so that
    // stepping over a year boundary is arithmetic instead of a special case.
    property int shownYear: clock.date.getFullYear()
    property int shownMonth: clock.date.getMonth()      // 0-11

    readonly property bool onToday: shownYear === clock.date.getFullYear()
                                    && shownMonth === clock.date.getMonth()

    readonly property var monthNames: [
        "Januar", "Februar", "März", "April", "Mai", "Juni",
        "Juli", "August", "September", "Oktober", "November", "Dezember"]

    // Monday first: this is a German desktop, and a calendar that starts on
    // Sunday is read wrong at a glance rather than read slowly.
    readonly property var dayNames: ["Mo", "Di", "Mi", "Do", "Fr", "Sa", "So"]

    function step(months) {
        var m = shownMonth + months
        shownYear += Math.floor(m / 12)
        shownMonth = ((m % 12) + 12) % 12
    }

    // Blank cells before the 1st. getDay() is 0=Sunday, so Monday-first needs
    // the shift — the classic off-by-one that puts every date on the wrong day.
    readonly property int leading: (new Date(shownYear, shownMonth, 1).getDay() + 6) % 7
    readonly property int daysInMonth: new Date(shownYear, shownMonth + 1, 0).getDate()

    Keys.onLeftPressed: root.step(-1)
    Keys.onRightPressed: root.step(1)
    Keys.onEscapePressed: root.step(0)      // consumed; the island handles closing

    // ------------------------------------------------------------ month head
    RowLayout {
        Layout.fillWidth: true
        spacing: Theme.space2

        Pill {
            interactive: true
            Icon { text: "chevron_left"; size: Theme.fontSizeLg }
            TapHandler { onTapped: root.step(-1) }
        }

        BarText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            font.weight: Theme.weightSemibold
            text: root.monthNames[root.shownMonth] + " " + root.shownYear
        }

        // Only offered when it would do something. A button that is already
        // where it takes you is noise.
        Pill {
            interactive: true
            visible: !root.onToday
            BarText { text: "heute"; font.pixelSize: Theme.fontSizeSm }
            TapHandler {
                onTapped: {
                    root.shownYear = clock.date.getFullYear()
                    root.shownMonth = clock.date.getMonth()
                }
            }
        }

        Pill {
            interactive: true
            Icon { text: "chevron_right"; size: Theme.fontSizeLg }
            TapHandler { onTapped: root.step(1) }
        }
    }

    // --------------------------------------------------------------- weekdays
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 0
        rowSpacing: Theme.space1

        Repeater {
            model: root.dayNames
            BarText {
                required property string modelData
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                text: modelData
            }
        }
    }

    // ------------------------------------------------------------------ grid
    GridLayout {
        Layout.fillWidth: true
        columns: 7
        columnSpacing: 0
        rowSpacing: Theme.space1

        Repeater {
            // Six rows always: a month that needs five must not make the island
            // change height as you page through it.
            model: 42

            Item {
                id: cellItem
                required property int index

                readonly property int day: index - root.leading + 1
                readonly property bool inMonth: day >= 1 && day <= root.daysInMonth
                readonly property bool isToday:
                    inMonth && root.onToday && day === clock.date.getDate()

                Layout.fillWidth: true
                implicitHeight: Theme.space5

                Rectangle {
                    anchors.centerIn: parent
                    width: Math.min(parent.width, Theme.space5)
                    height: width
                    radius: Theme.radiusPill
                    // Accent marks today and nothing else on this page.
                    color: cellItem.isToday ? Theme.accent : "transparent"  // literal-ok: absence of colour

                    BarText {
                        anchors.centerIn: parent
                        visible: cellItem.inMonth
                        text: cellItem.day
                        font.pixelSize: Theme.fontSizeSm
                        font.weight: cellItem.isToday ? Theme.weightSemibold : Theme.weightNormal
                        color: cellItem.isToday ? Theme.accentFg : Theme.fg
                    }
                }
            }
        }
    }
}
