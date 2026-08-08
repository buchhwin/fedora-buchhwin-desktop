// Control Center — the things the quick panel reaches for while you work:
// brightness, night light, the work timer, the on-screen readouts, and the
// clipboard.
//
// The panel itself keeps the switches you press every day. This page is where
// the numbers behind them live — how warm the night light goes, how many
// clipboard entries are listed, whether an external monitor is followed live.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
import "../../../services" as Services
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "On-screen readouts"

        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.osd"
            label: "Show volume and brightness"
            hint: "The pill that appears under the island when a hardware key is pressed. ⚠️ It hides the island while it is up and gives it back afterwards — that is the macOS behaviour asked for, not a bug."
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Brightness"

        SettingRow {
            Layout.fillWidth: true
            key: "brightness.external"
            label: "External monitors over DDC/CI"
            hint: "Talks to the monitor over the graphics cable. ⚠️ The package brings its own udev rule with TAG+=uaccess, so this needs no group and no permission change."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "brightness.externalLive"
            label: "Follow the slider live"
            hint: "Off sends one value when you let go. DDC/CI is slow, and a value per frame queues up behind itself — this has never been measured on a real monitor, so off is the honest default."
            usable: Config.brightness.external
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Night light"

        SettingRow {
            Layout.fillWidth: true
            key: "nightlight.on"
            label: "Night light"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "nightlight.temperature"
            label: "Colour temperature"
            hint: "Lower is warmer. 6500 K is daylight; below about 3000 K everything goes orange."
            kind: "slider"
            from: 1000; to: 6500; step: 100; unit: "K"
            usable: Config.nightlight.on
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Work timer"

        SettingRow {
            Layout.fillWidth: true
            key: "timer.presets"
            label: "Preset lengths"
            hint: "Minutes, separated by commas. ⚠️ They are stored as text on purpose — JsonAdapter does not deserialise a list of numbers at all, and does it silently."
            kind: "picks"
            options: Services.Suggest.durations
            placeholder: "5, 15, 25, 60"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "timer.sound"
            label: "Sound when it ends"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "timer.soundFile"
            label: "Sound file"
            kind: "pick"
            options: Services.Suggest.sounds
            placeholder: "/usr/share/sounds/…"
            usable: Config.timer.sound
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Clipboard"

        SettingRow {
            Layout.fillWidth: true
            key: "clipboard.visibleRows"
            label: "Entries shown"
            hint: "How many rows the clipboard history opens at. Everything is kept either way."
            kind: "slider"
            from: 3; to: 20; step: 1
        }
    }
}
