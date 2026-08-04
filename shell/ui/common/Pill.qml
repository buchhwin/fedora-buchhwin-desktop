// The one rounded container everything in the shell sits in.
//
// It exists so that "a thing on the bar" has exactly one definition of its
// corner radius, padding and hover behaviour. Every value comes from Theme; a
// literal here would be caught by tests/no-literals.sh, which is the point —
// the tripwire is not bureaucracy, it is what keeps a palette switch total.
import QtQuick
import "../../theme"

Rectangle {
    id: root

    property bool interactive: false
    property bool active: false
    default property alias content: inner.data

    implicitWidth: inner.implicitWidth + Theme.space3 * 2
    implicitHeight: inner.implicitHeight + Theme.space1 * 2

    radius: Theme.radiusPill
    color: root.active ? Theme.accent
         : hover.hovered && root.interactive ? Theme.pillHover
         : Theme.pillBg

    Behavior on color {
        enabled: Theme.animate
        ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
    }

    HoverHandler { id: hover; enabled: root.interactive }

    Item {
        id: inner
        anchors.centerIn: parent
        implicitWidth: childrenRect.width
        implicitHeight: childrenRect.height
    }
}
