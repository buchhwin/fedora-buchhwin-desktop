// Notifications, as a page of the island rather than a stack of popups.
//
// The design brief's rule for nothing-to-show is one sentence of text, so an
// empty list says so instead of presenting an empty frame.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root
    spacing: Theme.space2
    implicitWidth: Theme.space6 * 16

    BarText {
        Layout.fillWidth: true
        visible: Services.Notifications.count === 0
        text: "No notifications"
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
    }

    Repeater {
        model: Services.Notifications.list.slice(0, 3)

        RowLayout {
            id: row
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.space3

            Rectangle {
                implicitWidth: Theme.space5
                implicitHeight: Theme.space5
                radius: Theme.radiusSm
                // Urgency is information, so it gets colour; everything else
                // lives on surface and spacing.
                color: row.modelData.urgency === NotificationUrgency.Critical
                       ? Theme.error
                       : row.modelData.urgency === NotificationUrgency.Low
                         ? Theme.surfaceHigh : Theme.accent
            }

            ColumnLayout {
                Layout.fillWidth: true
                spacing: 0            // literal-ok: no gap at all — summary and body are one block

                BarText {
                    Layout.fillWidth: true
                    text: row.modelData.summary
                    font.weight: Theme.weightSemibold
                }

                BarText {
                    Layout.fillWidth: true
                    visible: row.modelData.body.length > 0
                    text: row.modelData.body
                    color: Theme.fgMuted
                    font.pixelSize: Theme.fontSizeSm
                }
            }

            Pill {
                interactive: true
                Icon { text: "close"; size: Theme.fontSize; color: Theme.fgDim }
                TapHandler { onTapped: Services.Notifications.dismiss(row.modelData) }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Notifications.count > 3
        text: "+ " + (Services.Notifications.count - 3) + " weitere"
        color: Theme.fgDim
        font.pixelSize: Theme.fontSizeSm
        horizontalAlignment: Text.AlignHCenter
    }
}
