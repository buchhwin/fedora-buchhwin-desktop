// Quick settings: the handful of things worth reaching without a window.
//
// Rows appear only where the hardware does. On a machine with no backlight the
// brightness row is absent rather than dead — a slider that moves nothing is
// worse than no slider.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services" as Services
import "../../common"

ColumnLayout {
    id: root
    spacing: Theme.space3
    implicitWidth: Theme.space6 * 16

    component Row: RowLayout {
        property alias icon: sym.text
        property real value: 0
        property bool live: true
        signal moved(real f)

        spacing: Theme.space3
        Layout.fillWidth: true

        Icon {
            id: sym
            size: Theme.fontSizeXl
            color: parent.live ? Theme.fg : Theme.fgDisabled
        }

        Rectangle {
            id: track
            Layout.fillWidth: true
            implicitHeight: Theme.space2
            radius: Theme.radiusPill
            color: Theme.surfaceHigh

            Rectangle {
                width: track.width * Math.max(0, Math.min(1, parent.parent.value))
                height: parent.height
                radius: parent.radius
                color: Theme.accent
                Behavior on width {
                    enabled: Theme.animate
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
            }

            // Dragging anywhere on the track sets the value — no thumb to hit.
            TapHandler { onTapped: function (p) { parent.parent.moved(p.position.x / track.width) } }
            DragHandler {
                target: null
                onCentroidChanged: if (active)
                    parent.parent.moved(centroid.position.x / track.width)
            }
        }

        BarText {
            text: Math.round(parent.value * 100) + "%"
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeSm
        }
    }

    Row {
        visible: Services.Audio.available
        icon: Services.Audio.muted ? "volume_off" : "volume_up"
        value: Services.Audio.volume
        live: !Services.Audio.muted
        onMoved: function (f) { Services.Audio.setVolume(f) }
    }

    Row {
        visible: Services.Brightness.available
        icon: "brightness_6"
        value: Services.Brightness.fraction
        onMoved: function (f) { Services.Brightness.set(f) }
    }

    BarText {
        Layout.fillWidth: true
        visible: !Services.Audio.available && !Services.Brightness.available
        text: "Keine Regler auf diesem Gerät"
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
    }
}
