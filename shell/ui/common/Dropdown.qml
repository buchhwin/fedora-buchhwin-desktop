// A closed list that opens: the current value, and a menu of the rest.
//
// ⚠️ IT EXISTS BECAUSE PILLS DO NOT SCALE. Every `choice` row drew one pill per
// option in a Flow, which is right for two and unreadable for fourteen — his
// words: "überall wo es ne auswahl wie bei color auswahl gibt, da sind ganz    // english-ok: quoted brief
// viele bubble, das ist unübersichtlich". Fourteen palettes wrapped over three  // english-ok: quoted brief
// lines and the chosen one had to be hunted for.
//
// The rule the row applies is by COUNT, not by taste: two or three options stay
// pills (one click beats opening a menu to pick between two), four or more come
// here. Colours are the deliberate exception and stay visible as swatches,
// because a menu entry reading "Mauve" does not tell you what Mauve looks like.
//
// ⚠️ IT OPENS, IT DOES NOT APPEAR. The standing rule for this shell is that
// nothing arrives without moving, and a menu that blinks into place is the
// clearest possible violation of it.
import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import "../../theme"

Item {
    id: root

    // [{ value: "24h", label: "24 hour" }, …]
    property var options: []
    property string current: ""
    property bool usable: true

    signal picked(var value)

    readonly property bool open: menu.visible

    function labelFor(v) {
        for (var i = 0; i < root.options.length; i++)
            if (String(root.options[i].value) === String(v))
                return root.options[i].label !== undefined
                     ? String(root.options[i].label) : String(v)
        return String(v)
    }

    implicitWidth: field.implicitWidth
    implicitHeight: field.implicitHeight

    // ------------------------------------------------------------- the field
    Rectangle {
        id: field
        anchors.fill: parent
        implicitWidth: line.implicitWidth + Theme.space3 * 2
        implicitHeight: line.implicitHeight + Theme.space2 * 2
        radius: Theme.radiusSm
        color: hover.hovered && root.usable ? Theme.cardHover : Theme.surfaceHigh
        opacity: root.usable ? 1 : Theme.dimmed

        Behavior on color {
            enabled: Theme.animate
            ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

        HoverHandler { id: hover; enabled: root.usable }
        TapHandler {
            enabled: root.usable
            onTapped: menu.visible = !menu.visible
        }

        RowLayout {
            id: line
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.leftMargin: Theme.space3
            anchors.rightMargin: Theme.space3
            spacing: Theme.space2

            BarText {
                Layout.fillWidth: true
                text: root.labelFor(root.current)
                color: Theme.fg
                elide: Text.ElideRight
            }
            Icon {
                text: "expand_more"
                size: Theme.fontSizeSm
                color: Theme.fgMuted
                rotation: menu.visible ? 180 : 0
                Behavior on rotation {
                    enabled: Theme.animate
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
            }
        }
    }

    // -------------------------------------------------------------- the menu
    // ⚠️ IT LIVES IN THE WINDOW, NOT IN THE ROW, and the first version did not —
    // reported as "das dropdown menu ist unter dem rest, man kann nichts        // english-ok: quoted brief
    // auswählen und es lässt sich nicht schließen".                             // english-ok: quoted brief
    //
    // Two reasons it could never have worked as a child of the row. The group
    // card sets `clip: true` so it can animate shut, which cuts the menu off at
    // the card's edge. And `z` only orders SIBLINGS, so a menu inside row three
    // is still painted before rows four and five whatever its z says.
    //
    // Reparenting to the window's contentItem takes it out of both problems: it
    // is a sibling of everything else in the window, and nothing clips it. The
    // position has to be mapped across, because the coordinates it was written
    // in are no longer the ones it lives in.
    Item {
        id: overlay
        parent: root.Window.contentItem
        anchors.fill: parent
        z: 1000                      // literal-ok: above the window's own content, not a theme value
        visible: menu.visible
        enabled: menu.visible

        // Anywhere else closes it. Full-window, and only while open — a
        // permanent invisible catcher is the bug nobody suspects.
        TapHandler { onTapped: menu.visible = false }

        // Esc closes it before the window does. Without this the settings window
        // would close underneath an open menu, which is two steps in one key.
        focus: menu.visible
        Keys.onEscapePressed: menu.visible = false

        Rectangle {
            id: menu

            // Where the field is, expressed in the window's coordinates.
            readonly property point anchor:
                root.mapToItem(overlay, 0, field.height + Theme.space1)

            x: Math.max(Theme.space2,
                        Math.min(menu.anchor.x, overlay.width - menu.width - Theme.space2))
            y: Math.min(menu.anchor.y,
                        Math.max(Theme.space2, overlay.height - menu.height - Theme.space2))
            width: Math.max(root.width, list.implicitWidth + Theme.space2 * 2)

            // Grows out of the field rather than appearing at full size.
            height: menu.visible ? Math.min(list.implicitHeight + Theme.space2 * 2,
                                            Theme.space6 * 8) : 0
            clip: true
            visible: false
            opacity: menu.visible ? 1 : 0

            radius: Theme.radiusMd
            color: Theme.menuBg

            // motion-ok: the menu unrolling IS a height change, and it is
            // reparented to the window's contentItem (see the note above), so it
            // sits in no layout and nothing is laid out around it. `clip: true`
            // is what turns the height into a reveal rather than a squash.
            Behavior on height {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }
            Behavior on opacity {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
            }

            // The menu itself must not close when it is clicked ON — the catcher
            // above covers the whole window, and without this every pick would
            // be swallowed by it before reaching an entry.
            TapHandler { onTapped: {} }

            Flickable {
                anchors.fill: parent
                anchors.margins: Theme.space2
                contentWidth: width
                contentHeight: list.implicitHeight
                boundsBehavior: Flickable.StopAtBounds
                clip: true

                ColumnLayout {
                    id: list
                    width: parent.width
                    spacing: 0      // literal-ok: rows meet, separated by their own padding

                    Repeater {
                        model: menu.visible ? root.options : []

                        Rectangle {
                            id: entry
                            required property var modelData

                            readonly property bool chosen:
                                String(root.current) === String(entry.modelData.value)

                            Layout.fillWidth: true
                            implicitHeight: label.implicitHeight + Theme.space2 * 2
                            radius: Theme.radiusSm
                            color: entry.chosen ? Theme.accent
                                 : entryHover.hovered ? Theme.pillHover
                                 : "transparent"       // literal-ok: absence of colour

                            Behavior on color {
                                enabled: Theme.animate
                                ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                            }

                            HoverHandler { id: entryHover }
                            TapHandler {
                                onTapped: {
                                    root.picked(entry.modelData.value)
                                    menu.visible = false
                                }
                            }

                            BarText {
                                id: label
                                anchors.left: parent.left
                                anchors.right: parent.right
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.leftMargin: Theme.space3
                                anchors.rightMargin: Theme.space3
                                text: entry.modelData.label !== undefined
                                    ? entry.modelData.label : entry.modelData.value
                                color: entry.chosen ? Theme.accentFg : Theme.fg
                                elide: Text.ElideRight
                            }
                        }
                    }
                }
            }
        }
    }

    function close() { menu.visible = false }
}
