// Where the sound goes, where it comes from, and a level for each programme.
//
// This is the part that makes pavucontrol unnecessary, which the plan names as
// a goal rather than a side effect. Three sections, and each is absent rather
// than empty when there is nothing in it: a heading over no rows is furniture.
//
// ⚠️ Nodes are only bound while this exists — Audio.watch(true/false). Without
// that the sliders would show whatever the values were when the nodes appeared.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../../services" as Services
import "../common"

ColumnLayout {
    id: root

    spacing: Theme.space2

    Component.onCompleted: Services.Audio.watch(true)
    Component.onDestruction: Services.Audio.watch(false)

    // ------------------------------------------------------------- outputs
    BarText {
        Layout.fillWidth: true
        visible: Services.Audio.outputs.length > 1
        text: "Output"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    Repeater {
        // One output is not a choice, and a list of one is a list that only
        // takes up room.
        model: Services.Audio.outputs.length > 1 ? Services.Audio.outputs : []

        Rectangle {
            id: outRow
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: outLine.implicitHeight + Theme.space2 * 2
            radius: Theme.radiusSm
            color: outRow.modelData.isDefault ? Theme.surfaceHigh
                 : outHover.hovered ? Theme.pillHover
                 : "transparent"                              // literal-ok: absence of colour

            HoverHandler { id: outHover }
            TapHandler { onTapped: Services.Audio.useOutput(outRow.modelData) }

            RowLayout {
                id: outLine
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space3

                Icon {
                    text: outRow.modelData.icon
                    size: Theme.fontSizeLg
                    color: outRow.modelData.isDefault ? Theme.accent : Theme.fg
                }

                BarText {
                    Layout.fillWidth: true
                    text: outRow.modelData.name
                    elide: Text.ElideRight
                }

                Icon {
                    visible: outRow.modelData.isDefault
                    text: "check"
                    size: Theme.fontSize
                    color: Theme.accent
                }
            }
        }
    }

    // ------------------------------------------------------------ programmes
    BarText {
        Layout.fillWidth: true
        visible: Services.Audio.streams.length > 0
        text: "Programs"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }

    Repeater {
        model: Services.Audio.streams

        RowLayout {
            id: streamRow
            required property var modelData
            Layout.fillWidth: true
            spacing: Theme.space3

            BarText {
                Layout.preferredWidth: Theme.space6 * 4
                text: streamRow.modelData.name
                elide: Text.ElideRight
                font.pixelSize: Theme.fontSizeSm
            }

            LevelRow {
                Layout.fillWidth: true
                icon: streamRow.modelData.muted ? "volume_off" : "graphic_eq"
                value: streamRow.modelData.volume
                live: !streamRow.modelData.muted
                onMoved: function (f) { Services.Audio.setNodeVolume(streamRow.modelData, f) }
                onNudged: function (d) {
                    Services.Audio.setNodeVolume(streamRow.modelData,
                        streamRow.modelData.volume + d / steps)
                }
            }
        }
    }

    BarText {
        Layout.fillWidth: true
        visible: Services.Audio.streams.length === 0
        text: "Nothing is playing"
        color: Theme.fgMuted
        font.pixelSize: Theme.fontSizeSm
    }
}
