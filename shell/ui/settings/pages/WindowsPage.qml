// Windows — how focus follows the pointer, and which windows float.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Focus"

        SettingRow {
            Layout.fillWidth: true
            key: "input.focusFollowsMouse"
            label: "Focus follows the pointer"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "input.warpMouseToFocus"
            label: "Pointer jumps to the focused window"
        }
    }

    SettingGroup {
        Layout.fillWidth: true
        title: "Windows"

        SettingRow {
            Layout.fillWidth: true
            key: "windows.noCsd"
            label: "No title bars"
            hint: "Asks every program to let the compositor draw the frame — and niri draws none. ⚠️ libadwaita header bars stay: they are program content, not decoration."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.blurred"
            label: "Blur behind"
            hint: "App ids, separated by commas. Only worth it for windows transparent enough to show it."
            kind: "strings"
            placeholder: "kitty, org.gnome.Nautilus"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.floating"
            label: "Open floating"
            kind: "strings"
            placeholder: "None"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "windows.blockFromScreencast"
            label: "Hide from screen sharing"
            kind: "strings"
            placeholder: "None"
        }
    }
}
