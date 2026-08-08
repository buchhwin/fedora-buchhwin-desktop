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
                // ⚠️ Was fontSizeSm and muted — a heading quieter than the rows
                // it heads, which is why the long pages read as one undivided
                // list. One UI puts real weight on the section name; the colour
                // stays calm so it groups rather than shouts.
                font.pixelSize: Theme.fontSize
                font.weight: Theme.weightSemibold
                color: headHover.hovered ? Theme.fg : Theme.fgMuted

                Behavior on color {
                    enabled: Theme.animate
                    ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
            }
        }
    }

    // --------------------------------------------------------------- the card
    // ⚠️ IT USED TO VANISH RATHER THAN CLOSE. `visible: !collapsed` is a card
    // that is simply not there on the next frame, and everything below it jumps
    // up the page — which reads as a glitch rather than as a group closing, and
    // loses you the place you were reading.
    //
    // Height and opacity, clipped, so the rows slide out of a shrinking card
    // instead of being cut off mid-air. This is the standing rule for everything
    // in this shell now: nothing appears or disappears without moving.
    Rectangle {
        id: card
        Layout.fillWidth: true
        clip: true

        readonly property int full: holder.implicitHeight + Theme.space5 * 2
        implicitHeight: root.collapsed ? 0 : card.full
        opacity: root.collapsed ? 0 : 1

        // One UI's cards are large-radius, flat and opaque. `radiusLg` existed
        // and nothing used it.
        radius: Theme.radiusLg
        color: Theme.cardBg

        // ⚠️ NOT UNTIL THE CARD HAS LAID OUT ONCE. `full` is derived from
        // `holder.implicitHeight`, which starts at 0 and grows as the rows
        // arrive — so this Behavior animated every BUILD, not just the
        // collapse. Every page change showed all its cards unfolding from
        // nothing, which is what "die settings buggen oft" was.               // english-ok: quoted brief
        //
        // A Behavior on a layout size animates every change to it, including
        // the ones that are not the gesture you meant. Gating it on "has this
        // ever been laid out" is the difference between a card that closes and
        // a page that assembles itself in front of you.
        property bool settled: false
        Component.onCompleted: Qt.callLater(function () { card.settled = true })

        Behavior on implicitHeight {
            enabled: Theme.animate && card.settled
            NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
        }
        Behavior on opacity {
            enabled: Theme.animate && card.settled
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        ColumnLayout {
            id: holder
            anchors.left: parent.left
            anchors.right: parent.right
            // ⚠️ TOP, NOT verticalCenter. Centring is invisible at full height
            // and wrong at every height in between: while the card animates
            // shut, centred content crawls upward at half the speed of the card
            // and the rows appear to slide out of the wrong edge.
            anchors.top: parent.top
            anchors.topMargin: Theme.space5
            anchors.leftMargin: Theme.space5
            anchors.rightMargin: Theme.space5
            // Wider than the gap inside a row, so a row reads as one thing and
            // the gap between two rows reads as the join.
            spacing: Theme.space4
        }
    }
}
