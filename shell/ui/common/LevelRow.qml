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
            onTapped: function (p) { root.moved(p.position.x / track.width) }
        }
        DragHandler {
            target: null
            onCentroidChanged: if (active) root.moved(centroid.position.x / track.width)
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
