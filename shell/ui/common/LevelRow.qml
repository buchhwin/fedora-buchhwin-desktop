// A value between nothing and everything: icon, track, percentage.
//
// Volume and brightness are the same object with different words, and writing
// them twice is how two things that should move identically start to drift —
// one gets a thinner track, the other keeps the old step size, and nobody
// notices until they are side by side in the quick settings.
//
// Small on purpose. This is a readout, not a control to grab: it lives on a
// page you GLANCE at, and the wheel is the way it is meant to be used.
import QtQuick
import QtQuick.Layouts
import "../../theme"

RowLayout {
    id: root

    property string icon: ""
    property real value: 0            // 0..1
    property bool live: true          // false = muted, or no hardware
    property int steps: 20            // 20 → 5 % a notch, as the hardware keys use

    signal moved(real fraction)       // absolute, from a tap or drag
    signal nudged(int direction)      // +1 / -1, from the wheel

    // The end of a drag, with the value it ended on. Volume and the laptop
    // panel have no use for it — they are fast enough to follow the finger —
    // but an external monitor over DDC/CI is not, and a caller that can only
    // afford to send once needs to know WHEN once is. Emitted after the last
    // `moved`, and after a tap too: a tap is a drag with no middle.
    signal released(real fraction)

    spacing: Theme.space3

    WheelHandler {
        // The whole row, not just the track. Aiming is the thing being removed
        // here; a hit area the size of a 4 px slider would defeat the point.
        target: null
        onWheel: function (ev) {
            root.nudged(ev.angleDelta.y > 0 ? 1 : -1)
            ev.accepted = true
        }
    }

    Icon {
        text: root.icon
        size: Theme.fontSizeLg
        color: root.live ? Theme.fg : Theme.fgDim
    }

    Rectangle {
        id: track
        Layout.fillWidth: true
        implicitHeight: Theme.space1
        radius: Theme.radiusPill
        color: Theme.surfaceHigh

        Rectangle {
            width: track.width * Math.max(0, Math.min(1, root.live ? root.value : 0))
            height: parent.height
            radius: parent.radius
            color: Theme.accent

            // The fill follows the value rather than jumping to it, which is
            // what makes a key held down feel continuous instead of stepped.
            Behavior on width {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }
        }

        TapHandler {
            onTapped: function (p) {
                var f = p.position.x / track.width
                root.moved(f)
                root.released(f)
            }
        }
        DragHandler {
            id: drag
            target: null
            property real last: 0
            onCentroidChanged: if (active) {
                last = centroid.position.x / track.width
                root.moved(last)
            }
            // ⚠️ `onActiveChanged`, not a handler on the release itself. A
            // DragHandler has no "let go" signal; it has an `active` that goes
            // false — and it also goes false when the drag is CANCELLED, which
            // is the same thing for our purposes: the finger is gone and the
            // last value it named is the one that counts.
            onActiveChanged: if (!active) root.released(last)
        }
    }

    BarText {
        text: Math.round(root.value * 100) + "%"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        // Fixed width, or the track jumps sideways every time the number goes
        // from two digits to three.
        Layout.minimumWidth: Theme.space6 + Theme.space2
        horizontalAlignment: Text.AlignRight
    }
}
