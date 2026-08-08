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
    // ⚠️ A CHILD OF THE ROW, NOT A POPUP WINDOW. A layer surface for a list of
    // fourteen strings would be a second window with its own focus, its own
    // stacking and its own way of failing to close. Inside the page it is drawn
    // by the same scene and cannot outlive the row that owns it.
    //
    // The cost is honest: it is clipped by the Flickable, so a menu opened at
    // the very bottom of a page scrolls into view rather than hanging over the
    // edge. That is a fair trade for not owning a window.
    Rectangle {
        id: menu
        anchors.top: field.bottom
        anchors.topMargin: Theme.space1
        anchors.right: field.right
        width: Math.max(field.width, list.implicitWidth + Theme.space2 * 2)

        // Grows out of the field rather than appearing at full size.
        height: menu.visible ? Math.min(list.implicitHeight + Theme.space2 * 2,
                                        Theme.space6 * 8) : 0
        clip: true
        visible: false
        opacity: menu.visible ? 1 : 0

        radius: Theme.radiusMd
        color: Theme.menuBg
        z: 10

        Behavior on height {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }

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
                    model: root.options

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

    // Anywhere else closes it. ⚠️ Enabled only while it is open, because a
    // full-page invisible tap catcher that is always there is the kind of bug
    // nobody suspects — the same reasoning ClickCatcher carries.
    Item {
        parent: root.parent
        anchors.fill: parent
        z: 9
        enabled: menu.visible
        visible: menu.visible
        TapHandler { onTapped: menu.visible = false }
    }

    function close() { menu.visible = false }
}
