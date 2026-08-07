// Notifications — arriving messages, how long they stay, and where they land.
//
// ⚠️ The file is `NotifyPage`, not `NotificationsPage`, because the island
// already has a page by that name. Two QML types with one name in two folders
// resolve correctly and read as a mistake for the rest of the project's life.
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
        title: "Arriving messages"

        SettingRow {
            Layout.fillWidth: true
            key: "surfaces.notifications"
            label: "Show messages when they arrive"
            hint: "Their own surface in the top-right corner, not a page of the island — a message that arrives has not been asked for, and taking over the island made every one interrupt whatever was there."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notifications.dnd"
            label: "Do not disturb"
            hint: "⚠️ It persists across logins on purpose. Everything still arrives and is still in the list on Mod+N; critical messages still come through, because that is what the urgency level is for."
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notifications.timeoutMs"
            label: "How long one stays"
            hint: "Senders may ask for their own; this is the answer when they do not. ⚠️ Critical messages never time out — a disk-full warning that vanishes while you are elsewhere is worse than none."
            kind: "slider"
            from: 1000; to: 20000; step: 500; unit: "ms"
            usable: Config.surfaces.notifications
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notifications.maxVisible"
            label: "How many at once"
            kind: "slider"
            from: 1; to: 8; step: 1
            usable: Config.surfaces.notifications
        }
        SettingRow {
            Layout.fillWidth: true
            key: "notifications.monitors"
            label: "Screens"
            hint: "⚠️ Empty means every screen — which on two monitors means the same message twice. That is the honest default, but worth naming one output once a second screen is in play."
            kind: "strings"
            placeholder: "Every screen"
            usable: Config.surfaces.notifications
        }
    }
}
