// Wallpaper — which picture, from where, and how it is fitted.
//
// ⚠️ `WallpaperSettingsPage`, not `WallpaperPage`: the notch already has a page
// by that name. Two QML types with one name in two folders resolve correctly
// and read as a mistake forever after — the same reason NotifyPage is not
// called NotificationsPage.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../theme"

ColumnLayout {
    id: root

    spacing: Theme.space5

    SettingGroup {
        Layout.fillWidth: true
        title: "Wallpaper"

        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.wallpaper"
            label: "Draw the wallpaper"
            hint: "The shell draws it rather than a second daemon. Off leaves whatever the compositor puts there."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.folder"
            label: "Folder"
            hint: "Where Mod+Shift+W looks for pictures."
            kind: "field"
            placeholder: "~/Pictures/Wallpapers"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.current"
            label: "Current picture"
            hint: "A file:// address. Easier to choose with Mod+Shift+W."
            kind: "field"
            placeholder: "file:///…"
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.monitors"
            label: "Screens"
            kind: "strings"
            placeholder: "Every screen"
        }
    }
}
