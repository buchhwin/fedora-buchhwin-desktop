// The volume page: what the notch becomes while you are changing the volume.
//
// Laid out from the screenshot the user supplied: speaker on the left, a track
// that fills, the percentage on the right. It is a PAGE, not a window — the
// notch grows to this size and this appears inside it.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../services" as Services
import "../../common"

RowLayout {
    id: root
    spacing: Theme.space3
    implicitWidth: Theme.space6 * 12

    Icon {
        text: Services.Audio.muted ? "volume_off"
            : Services.Audio.volume > 0.5 ? "volume_up" : "volume_down"
        size: Theme.fontSizeXl
        color: Services.Audio.muted ? Theme.fgDim : Theme.fg
    }

    Rectangle {
        Layout.fillWidth: true
        implicitHeight: Theme.space2
        radius: Theme.radiusPill
        color: Theme.surfaceHigh

        Rectangle {
            width: parent.width * (Services.Audio.muted ? 0 : Services.Audio.volume)
            height: parent.height
            radius: parent.radius
            color: Theme.accent

            // The fill follows the value rather than jumping to it, which is
            // what makes a volume key feel continuous instead of stepped.
            Behavior on width {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }
        }
    }

    BarText {
        text: Math.round(Services.Audio.volume * 100) + "%"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
    }
}
