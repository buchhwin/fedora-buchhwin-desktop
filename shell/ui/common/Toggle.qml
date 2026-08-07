// A switch: two states, said by position rather than by a word.
//
// The shell had none. What stood in for one was `Tile` — a whole card that
// happens to light up — which is right for the quick panel, where a setting IS
// the tile, and wrong for a settings page, where a row is a label with its
// control at the far end. His reference draws exactly that: "Notch mode" on the
// left, a switch hard against the right edge.
//
// ⚠️ IT IS NOT BUILT ON `Pill`, and that is deliberate rather than an
// oversight. Pill carries its own hit area sized to the whole shape, which is
// what makes it safe — but a switch's shape IS its value, so the thing you
// press and the thing that changes have to be the same rectangle. Putting a
// TapHandler inside a Pill would land it in Pill's `inner`, which is only as
// big as its contents: the "every pill was half dead" bug, measured at 68x29
// lit and 44x21 answering. tests/tap-targets.sh refuses that statically, and
// this component owns its handler instead of borrowing one.
import QtQuick
import "../../theme"

Rectangle {
    id: root

    property bool checked: false

    // ⚠️ `usable`, NOT `enabled` — Item already has `enabled` and shadowing it
    // makes the whole subtree stop accepting input for reasons that look like a
    // layout bug. Same name as Tile.qml uses, for the same reason.
    property bool usable: true

    // Carries the value it is asking for, so a caller never has to read
    // `checked` back out of the thing it is in the middle of changing. The
    // switch does not move itself: the row writes the setting and the setting
    // moves the switch, which is what keeps a refused write visible instead of
    // leaving the control saying something the file does not.
    signal toggled(bool value)

    implicitWidth: Theme.space6 + Theme.space3
    implicitHeight: Theme.space5
    radius: Theme.radiusPill

    color: root.checked ? Theme.accent : Theme.surfaceHigh
    opacity: root.usable ? 1 : Theme.dimmed

    Behavior on color {
        enabled: Theme.animate
        ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
    }

    HoverHandler {
        id: hover
        enabled: root.usable
        cursorShape: Qt.PointingHandCursor
    }

    TapHandler {
        enabled: root.usable
        onTapped: root.toggled(!root.checked)
    }

    Rectangle {
        id: knob
        // The inset is half a grid step. A knob flush with the track reads as a
        // filled pill rather than as something that travels.
        readonly property int inset: Theme.space1 / 2

        width: parent.height - inset * 2
        height: width
        radius: width / 2      // literal-ok: a circle is half its width
        y: inset
        x: root.checked ? parent.width - width - inset : inset

        color: root.checked ? Theme.accentFg : Theme.fgMuted

        // The one piece of motion here, and it is the whole point: the state
        // change is a journey between two ends, so seeing it travel is what
        // says which way it went. No overshoot — a switch that bounces reads as
        // uncertain about where it landed.
        Behavior on x {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        Behavior on color {
            enabled: Theme.animate
            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }
}
