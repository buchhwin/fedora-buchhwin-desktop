// The volume page: what the notch becomes while you are changing the volume.
//
// Laid out from the reference screenshot: speaker on the left, a track that
// fills, the percentage on the right — a small dark pill, and nothing more.
//
// ⚠️ It declares itself COMPACT, and that is the whole point of the flag. The
// island's reference geometry (619 × 135, from the settings screenshot) belongs
// to pages you READ. Forced onto a volume readout it produced a slab covering a
// sixth of the screen for three pieces of information. A page you GLANCE at is
// as small as its contents, and this one is 256 × 34.
//
// The wheel changes the volume while it is open. That is the gesture people
// already make at a volume control, and having to aim at a 4 px track with a
// pointer instead is the reason on-screen volume sliders go unused.
import QtQuick
import QtQuick.Layouts
import "../../../theme"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

RowLayout {
    id: root

    // Read by NotchContent. See the comment there for what it changes.
    property bool compact: true

    spacing: Theme.space3
    implicitWidth: Theme.space6 * 8

    // One place, so the wheel and any future gesture agree about step size.
    // 5 % matches the hardware keys in the niri bindings — the same press
    // should not mean two different amounts depending on how you made it.
    function nudge(steps) {
        if (!Services.Audio.available)
            return
        var v = Math.max(0, Math.min(1, Services.Audio.volume + steps * 0.05))
        Services.Audio.setVolume(v)
        // Keep the page up while the wheel is turning: it closes itself after a
        // moment, and having it vanish mid-gesture is what makes an OSD feel
        // like it is fighting you.
        Ipc.show("volume")
    }

    WheelHandler {
        // The whole page, not just the track. Aiming is the thing being
        // removed here, so a hit area the size of a slider would be pointless.
        target: null
        onWheel: function (ev) {
            root.nudge(ev.angleDelta.y > 0 ? 1 : -1)
            ev.accepted = true
        }
    }

    Icon {
        text: Services.Audio.muted ? "volume_off"
            : Services.Audio.volume > 0.5 ? "volume_up" : "volume_down"
        size: Theme.fontSizeLg
        color: Services.Audio.muted ? Theme.fgDim : Theme.fg
    }

    Rectangle {
        id: track
        Layout.fillWidth: true
        // Thin on purpose: it reports a value, it is not a control to grab.
        implicitHeight: Theme.space1
        radius: Theme.radiusPill
        color: Theme.surfaceHigh

        Rectangle {
            width: track.width * (Services.Audio.muted ? 0 : Services.Audio.volume)
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

        // Dragging still works for anyone who reaches for it.
        TapHandler {
            onTapped: function (p) {
                if (Services.Audio.available)
                    Services.Audio.setVolume(p.position.x / track.width)
            }
        }
        DragHandler {
            target: null
            onCentroidChanged: if (active && Services.Audio.available)
                Services.Audio.setVolume(centroid.position.x / track.width)
        }
    }

    BarText {
        text: Math.round(Services.Audio.volume * 100) + "%"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        // Fixed width, or the track jumps sideways every time the number goes
        // from two digits to three.
        Layout.minimumWidth: Theme.space6 + Theme.space2
        horizontalAlignment: Text.AlignRight
    }
}
