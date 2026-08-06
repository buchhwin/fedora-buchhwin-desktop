// The bluetooth devices: connected, paired, and whatever else is answering.
//
// Discovery, like the wifi scan, lives exactly as long as this component does.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services" as Services
import "../common"

ColumnLayout {
    id: root

    spacing: Theme.space1

    Component.onCompleted: Services.Bt.watch(true)
    Component.onDestruction: Services.Bt.watch(false)

    BarText {
        Layout.fillWidth: true
        visible: !Services.Bt.enabled
        text: "Bluetooth is off"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Bt.enabled && Services.Bt.devices.length === 0
        text: Services.Bt.discovering ? "Looking for devices …" : "Nothing found yet"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }

    Repeater {
        model: Services.Bt.enabled ? Services.Bt.devices : []

        Rectangle {
            id: row
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: line.implicitHeight + Theme.space2 * 2
            radius: Theme.radiusSm
            color: rowHover.hovered ? Theme.pillHover : "transparent"  // literal-ok: absence of colour

            HoverHandler { id: rowHover }
            TapHandler {
                onTapped: {
                    if (row.modelData.connected) Services.Bt.disconnect(row.modelData)
                    else Services.Bt.connect(row.modelData)
                }
            }

            RowLayout {
                id: line
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space3

                Icon {
                    text: row.modelData.icon
                    size: Theme.fontSizeLg
                    color: row.modelData.connected ? Theme.accent : Theme.fg
                }

                BarText {
                    Layout.fillWidth: true
                    text: row.modelData.name
                    elide: Text.ElideRight
                    font.weight: row.modelData.connected ? Theme.weightMedium
                                                         : Theme.weightNormal
                }

                // The number that actually matters on a laptop: how much is
                // left in the headphones. Shown only where the device reports
                // it, rather than as a dash for everything that does not.
                BarText {
                    visible: row.modelData.battery >= 0
                    text: Math.round(row.modelData.battery * 100) + "%"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                }

                BarText {
                    visible: row.modelData.pairing
                    text: "pairing …"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.accent
                }

                BarText {
                    visible: !row.modelData.paired && !row.modelData.pairing
                    text: "new"
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgDim
                }

                Pill {
                    visible: row.modelData.paired
                    interactive: true
                    Icon { text: "link_off"; size: Theme.fontSize; color: Theme.fgDim }
                    onClicked: Services.Bt.forget(row.modelData)
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Bt.status.length > 0
        text: Services.Bt.status
        color: Theme.error
        font.pixelSize: Theme.fontSizeSm
        wrapMode: Text.WordWrap
    }
}
