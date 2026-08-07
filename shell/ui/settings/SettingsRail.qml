pragma ComponentBehavior: Bound

// The sidebar of the settings window: ten named rows, each with its symbol in a
// rounded square.
//
// ⚠️ IT IS NOT `IconRail`, AND THAT NEEDS SAYING, because IconRail's own header
// says the settings window would take it. Held against his reference, it cannot:
// IconRail is a strip of SYMBOLS with a tooltip, and its whole design turns on
// the tooltip standing in for the word that is not there. The reference for this
// window draws named rows — "Bar & Island" spelled out, its symbol in a rounded
// square beside it, the active one a filled rounded row. A tooltip explaining a
// label is nothing, and a full-width row with centred contents is what IconRail
// would give (its `inner` is centred in the pill, which is right for a symbol
// and wrong for a list).
//
// So they are two controls that happen to both be vertical. What the warning in
// IconRail is actually about — "two sidebars that drifted apart" — was the
// pill-and-tooltip mechanics, and this file does not reinvent those: it follows
// the delegate convention the launcher's program list already uses, a
// full-width Rectangle with its own hover and tap. tests/tap-targets.sh forbids
// a TapHandler inside a `Pill` for a reason that does not apply to a Rectangle
// sized by its parent.
import QtQuick
import QtQuick.Layouts
import "../common"
import "../../theme"

ColumnLayout {
    id: root

    // [{ icon: "view_agenda", title: "Bar & Island" }, …]
    property var entries: []
    property int currentIndex: 0
    signal activated(int index)

    spacing: Theme.space1

    Repeater {
        model: root.entries

        Rectangle {
            id: row
            required property int index
            required property var modelData

            readonly property bool current: root.currentIndex === row.index

            Layout.fillWidth: true
            // ⚠️ THE NATURAL WIDTH IS REPORTED, and that is what pins the
            // sidebar. `line` is anchored to both sides so its WIDTH follows
            // the row, but its implicitWidth is still the sum of what is in it —
            // so the column can ask "how wide does the longest entry need to
            // be" and stop being a number somebody guessed.
            implicitWidth: line.implicitWidth + Theme.space2 + Theme.space3
            implicitHeight: line.implicitHeight + Theme.space2

            radius: Theme.radiusSm
            color: row.current ? Theme.accent
                 : hover.hovered ? Theme.pillHover
                 : "transparent"                 // literal-ok: absence of colour

            // ⚠️ IT USED TO DIM A `ready: false` ENTRY, and that is gone with
            // the last unfinished page. A property whose every writer says the
            // same thing is not a property; it is a constant with somewhere to
            // hide. If a page ever ships unfinished again, this comes back with
            // it rather than sitting here being always true.

            Behavior on color {
                enabled: Theme.animate
                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            HoverHandler { id: hover }
            TapHandler { onTapped: root.activated(row.index) }

            RowLayout {
                id: line
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                anchors.leftMargin: Theme.space2
                anchors.rightMargin: Theme.space3
                spacing: Theme.space3

                // The symbol in its rounded square, as the reference draws it.
                Rectangle {
                    implicitWidth: Theme.space5
                    implicitHeight: Theme.space5
                    radius: Theme.radiusXs
                    color: row.current ? Theme.accentFg : Theme.surfaceHigh

                    Icon {
                        anchors.centerIn: parent
                        text: row.modelData.icon
                        size: Theme.fontSize
                        color: row.current ? Theme.accent : Theme.fgMuted
                    }
                }

                BarText {
                    Layout.fillWidth: true
                    text: row.modelData.title
                    color: row.current ? Theme.accentFg : Theme.fg
                    font.weight: row.current ? Theme.weightMedium : Theme.weightNormal
                }
            }
        }
    }
}
