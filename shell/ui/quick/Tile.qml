// One switch in the quick settings, with the state it is in written on it.
//
// ⚠️ WIDE, NOT A SMALL SQUARE. The first sketch was a row of icon-sized squares
// with a word under each. Two things were wrong with that: the state was not on
// it — a wifi tile that does not say which network is not answering the question
// anybody opens the panel to ask — and the target was the size of a glyph, which
// is the mistake that had already been found and fixed once in common/Pill.
//
// So: an icon, a name, the current state under the name, and, where there is a
// list behind it, a chevron with a target of its own. Two of these fit side by
// side inside the island's reference width.
import QtQuick
import QtQuick.Layouts
import "../../theme"
import "../common"

Rectangle {
    id: root

    property string icon: ""
    property string title: ""
    // What it is doing right now. Empty is allowed and simply leaves the line
    // out rather than reserving a blank one.
    property string subtitle: ""
    property bool active: false
    // ⚠️ NOT `enabled`. Item already has one, and shadowing it made Qt warn
    // that "Member enabled of the object Tile overrides a member of the base
    // object" — the same trap as naming a function `state`. The inherited
    // `enabled` governs input delivery, so overriding it would have changed
    // whether the handlers below fire, quietly and by accident.
    property bool usable: true
    // Does anything open when the chevron is pressed?
    property bool expandable: false
    property bool expanded: false

    signal clicked
    signal expandClicked

    implicitHeight: body.implicitHeight + Theme.space3 * 2
    radius: Theme.radiusMd

    color: !root.usable ? Theme.surface
         : root.active ? Theme.accent
         : hover.hovered ? Theme.pillHover
         : Theme.pillBg

    Behavior on color {
        enabled: Theme.animate
        ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
    }

    readonly property color content: !root.usable ? Theme.fgDisabled
                                   : root.active ? Theme.accentFg : Theme.fg

    HoverHandler { id: hover; enabled: root.usable }
    TapHandler {
        enabled: root.usable
        onTapped: root.clicked()
    }

    RowLayout {
        id: body
        anchors.fill: parent
        anchors.margins: Theme.space3
        spacing: Theme.space3

        Icon {
            text: root.icon
            size: Theme.fontSizeXl
            color: root.content
        }

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 0   // literal-ok: absence of a gap — name and state are one
                         // label on two lines, not two separate things

            BarText {
                Layout.fillWidth: true
                text: root.title
                color: root.content
                font.weight: Theme.weightMedium
                elide: Text.ElideRight
            }

            BarText {
                Layout.fillWidth: true
                visible: root.subtitle.length > 0
                text: root.subtitle
                font.pixelSize: Theme.fontSizeSm
                // Dimmed against whatever the tile is: on an accent tile the
                // muted grey would vanish, so it follows the content colour and
                // loses opacity instead.
                color: root.content
                opacity: Theme.dimmed
                elide: Text.ElideRight
            }
        }

        // Its own target rather than a corner of the tile — the whole reason
        // Pill grew a `clicked` signal was a target smaller than the thing that
        // lit up under the pointer.
        Rectangle {
            visible: root.expandable
            implicitWidth: Theme.space5
            implicitHeight: Theme.space5
            radius: Theme.radiusSm
            color: chevHover.hovered ? Theme.pillHover : "transparent"  // literal-ok: absence of colour

            Icon {
                anchors.centerIn: parent
                text: root.expanded ? "expand_less" : "expand_more"
                size: Theme.fontSizeLg
                color: root.content
            }

            HoverHandler { id: chevHover; enabled: root.usable }
            TapHandler {
                enabled: root.usable
                onTapped: root.expandClicked()
            }
        }
    }
}
