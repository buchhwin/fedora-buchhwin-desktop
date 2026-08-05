pragma ComponentBehavior: Bound

// The quick panel: the one surface that answers "what is going on".
//
// It is what clicking the notch opens, and it is deliberately the only page
// that gathers things rather than showing one: the month, the weather, the
// handful of sliders worth reaching for, and the way into the settings. Every
// other page is a single answer to a single question.
//
// Two columns, because the island is wide and short. The calendar is the tall
// thing, so it takes the left side and sets the height; everything else stacks
// beside it.
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

RowLayout {
    id: root
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
            text: "Keine Regler auf diesem Gerät"
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
        }

        // ------------------------------------------------------------- footer
        RowLayout {
            Layout.fillWidth: true
            spacing: Theme.space2

            BarText {
                Layout.fillWidth: true
                text: root.note
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                elide: Text.ElideRight
            }

            Pill {
                interactive: true
                Icon { text: "settings"; size: Theme.fontSizeLg }
                TapHandler { onTapped: root.openSettings() }
            }
        }
    }

    // The gear will open the settings window. It does not exist yet (M8), and
    // a button that opens nothing is worse than one that says so.
    property string note: ""
    function openSettings() {
        root.note = "Einstellungen kommen in M8 — bis dahin shell.json"
        forget.restart()
    }
    Timer { id: forget; interval: 4000; onTriggered: root.note = "" }
}
