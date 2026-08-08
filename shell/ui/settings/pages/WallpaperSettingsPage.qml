// Wallpaper — which picture, from where, and how it is fitted.
//
// ⚠️ `WallpaperSettingsPage`, not `WallpaperPage`: the notch already has a page
// by that name. Two QML types with one name in two folders resolve correctly
// and read as a mistake forever after — the same reason NotifyPage is not
// called NotificationsPage.
import QtQuick
import QtQuick.Layouts
import ".."
import "../../../config"
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

    SettingGroup {
        Layout.fillWidth: true
        title: "Slideshow"

        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.slideshow"
            label: "Change the picture by itself"
            hint: "Walks the folder above. With this off nothing runs — there is no timer at all."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.intervalMinutes"
            label: "Every"
            hint: "Minutes between pictures."
            kind: "slider"
            from: 1
            to: 240
            step: 1
            unit: " min"
            usable: Config.wallpaper.slideshow
        }
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.shuffle"
            label: "In a random order"
            hint: "Off walks the folder in name order. On never picks the picture already showing."
            usable: Config.wallpaper.slideshow
        }
        // ⚠️ THE SECOND SWITCH, AND IT IS THE POINT OF THE GROUP. With the
        // palette set to "wallpaper" every picture change recalculates all 26
        // colours and rewrites every foreign application's config — measured,
        // a forest picture gives base 27201b and a desert one 1b2027. A
        // slideshow every fifteen minutes would then repaint the whole desktop
        // every fifteen minutes. Changing the picture and changing the colours
        // are two different wishes.
        SettingRow {
            Layout.fillWidth: true
            key: "wallpaper.slideshowRecolour"
            label: "Take the colours along"
            hint: "Off keeps the scheme the desktop had when the slideshow started. Only matters while the palette is set to follow the wallpaper."
            usable: Config.wallpaper.slideshow
        }
    }
}
