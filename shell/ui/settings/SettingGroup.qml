// A titled block of rows — a CARD, since today.
//
// ⚠️ THIS CHANGED HIS OWN REFERENCE, ON HIS INSTRUCTION. The screenshot from
// 04.08. draws rows floating free on the panel, and that is what shipped. After
// using it he said the window was hard to scan and told me to look at how macOS
// and Windows lay theirs out. Both do the same thing, and it is the one thing
// this was missing: rows live INSIDE a rounded surface, and the surfaces are
// separated by space. Fifty-five rows on one flat background give the eye no
// edges to hold on to.
//
// It stays inside the brief rather than breaking it. The rule there is
// "separation by space and SURFACE, never by lines" — a card is surface. No
// dividing line is added anywhere, and the rows inside are still separated by
// space alone.
//
// ⚠️ AND IT FOLDS. Appearance is eight groups; folded, it is eight lines and you
// can see the whole page at once. The state is not written to shell.json on
// purpose: it is where you are looking, not what you have set, and a settings
// file that records which drawer you left open is a settings file with opinions
// about your afternoon.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

ColumnLayout {
    id: root

    property string title: ""
    property bool collapsed: false

    // ⚠️ `.data`, not `.children`. Anything that is not an Item — a Connections,
    // a Timer a group might one day carry — has no place in `children` and
    // would be dropped without a word.
    default property alias content: holder.data

    spacing: Theme.space2

    // ------------------------------------------------------------- the header
    // Outside the card, as both references do it: the heading labels the card
    // rather than sitting in it.
    Item {
        Layout.fillWidth: true
        implicitHeight: head.implicitHeight
        visible: root.title.length > 0

        HoverHandler { id: headHover }
        TapHandler { onTapped: root.collapsed = !root.collapsed }

        RowLayout {
            id: head
            anchors.left: parent.left
            anchors.right: parent.right
            spacing: Theme.space1

            Icon {
                text: root.collapsed ? "chevron_right" : "expand_more"
                size: Theme.fontSizeSm
                color: headHover.hovered ? Theme.fg : Theme.fgMuted
            }
            BarText {
                Layout.fillWidth: true
                text: root.title
                font.pixelSize: Theme.fontSizeSm
                font.weight: Theme.weightSemibold
                color: headHover.hovered ? Theme.fg : Theme.fgMuted
            }
        }
    }

    // --------------------------------------------------------------- the card
    Rectangle {
        Layout.fillWidth: true
        visible: !root.collapsed
        implicitHeight: holder.implicitHeight + Theme.space4 * 2
        radius: Theme.radiusMd
        color: Theme.cardBg

        ColumnLayout {
            id: holder
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.space4
            anchors.rightMargin: Theme.space4
            // Wider than the gap inside a row, so a row reads as one thing and
            // the gap between two rows reads as the join.
            spacing: Theme.space4
        }
    }
}
