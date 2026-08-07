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

    // ⚠️ TWO SHAPES, ONE COMPONENT. The reference
    // (2026-08-06/vorlage-control-center.png) draws the control-centre levels
    // as tall rounded bars with the symbol INSIDE them and no percentage at
    // all; the thin track with the icon beside it is still right where a level
    // is a readout rather than a control — the media page, the small pages the
    // volume keys raise. Building the fat one separately is how volume and
    // brightness drift apart, which is the thing the head of this file exists
    // to prevent, so it is a property instead.
    property bool fat: false

    // Whether the percentage is written at the end. Off for the track position
    // in the media card, where two clocks say it better — and off implicitly on
    // the fat shape, which the reference draws without one.
    property bool showValue: true

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

    // Beside the track when thin, inside it when fat — so it is the same Icon
    // either way rather than one of two that could drift.
    Icon {
        // An empty name would still reserve a glyph's width, so the check is on
        // the content rather than only on the shape.
        visible: !root.fat && root.icon.length > 0
        text: root.icon
        size: Theme.fontSizeLg
        color: root.live ? Theme.fg : Theme.fgDim
    }

    Rectangle {
        id: track
        Layout.fillWidth: true
        implicitHeight: root.fat ? Theme.space6 : Theme.space1
        radius: Theme.radiusPill
        color: Theme.surfaceHigh

        Rectangle {
            id: fill
            width: Math.max(root.fat ? track.height : 0,
                            track.width * Math.max(0, Math.min(1, root.live ? root.value : 0)))
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

        // ⚠️ SITS ON THE TRACK, NOT ON THE FILL, and it is the fill that moves
        // under it. Anchored into the fill it would slide off the left end as
        // the level dropped; anchored here it stays where the symbol belongs
        // and simply stops being on the accent when the fill retreats past it.
        // That is why the fill has a minimum width of one track height in fat
        // mode — at zero the symbol would sit on bare grey and read as broken.
        Icon {
            visible: root.fat
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.leftMargin: Theme.space3
            text: root.icon
            size: Theme.fontSizeLg
            color: root.live ? Theme.accentFg : Theme.fgDim
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

    // No number on the fat one — the reference has none, and it is right: a bar
    // that fills most of the panel already says how far along it is, and "62 %"
    // is a precision nobody sets a volume to.
    BarText {
        visible: !root.fat && root.showValue
        text: Math.round(root.value * 100) + "%"
        font.pixelSize: Theme.fontSizeSm
        color: Theme.fgMuted
        // Fixed width, or the track jumps sideways every time the number goes
        // from two digits to three.
        Layout.minimumWidth: Theme.space6 + Theme.space2
        horizontalAlignment: Text.AlignRight
    }
}
