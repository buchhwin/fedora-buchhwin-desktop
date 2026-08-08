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
// ⚠️ Quickshell, not QtQuick.Window. The old version needed the `Window`
// attached property to find something to reparent into; PopupWindow needs no
// parent of its own, only an anchor.
import Quickshell
import "../../theme"

Item {
    id: root

    // [{ value: "24h", label: "24 hour" }, …]
    property var options: []
    property string current: ""
    property bool usable: true

    signal picked(var value)

    readonly property bool open: root.menuOpen

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
            onTapped: root.menuOpen = !root.menuOpen
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
                rotation: root.menuOpen ? 180 : 0
                Behavior on rotation {
                    enabled: Theme.animate
                    NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                }
            }
        }
    }

    // -------------------------------------------------------------- the menu
    // ⚠️⚠️ ITS OWN WINDOW, AND THE TWO ATTEMPTS BEFORE THIS ONE BOTH FAILED IN
    // HIS HANDS. Reported the first time as "das dropdown menu ist unter dem     // english-ok: quoted brief
    // rest, man kann nichts auswählen und es lässt sich nicht schließen", and    // english-ok: quoted brief
    // the second time, after a fix that was reported as done, as still broken.
    //
    // Attempt one was a child of the row. That could never work: the group card
    // sets `clip: true` so it can fold, which cuts the menu off at the card's
    // edge, and `z` only orders SIBLINGS, so a menu in row three is painted
    // before rows four and five whatever its z says.
    //
    // Attempt two reparented it to `root.Window.contentItem`. That was a guess
    // dressed as a fix — the construct appears exactly ONCE in this whole
    // project, it was never proven anywhere, and the settings window is a
    // `FloatingWindow` rather than the `PanelWindow` everything else here uses.
    // It was reported as still broken, which is the only evidence that counts.
    //
    // ⚠️ AND QUICKSHELL HAD THE RIGHT PART ALL ALONG. `PopupWindow` is a real
    // popup surface — the compositor places it, so no `clip`, no z-order and no
    // layout anywhere in the shell can reach it, and there is nothing to
    // reparent and no coordinates to map. Verified in the type description
    // shipped with quickshell rather than assumed: `ProxyPopupWindow`, exported
    // as `Quickshell._Window/PopupWindow`, with `anchor` (a `PopupAnchor`
    // carrying `item`, `rect`, `edges`, `gravity`, `adjustment`) and
    // `grabFocus`.
    //
    // `grabFocus` is what makes Esc an answer rather than a detour: the popup
    // takes the keyboard while it is up, so the key reaches the menu instead of
    // closing the settings window underneath it.
    property bool menuOpen: false

    PopupWindow {
        id: popup

        visible: root.menuOpen
        color: "transparent"            // literal-ok: absence of colour

        // Under the field, aligned with its left edge. `adjustment` is what
        // keeps it on screen for a row near the bottom without any of the
        // min/max arithmetic the previous version needed.
        anchor.item: field
        anchor.rect.y: field.height + Theme.space1
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.All

        grabFocus: true

        implicitWidth: Math.max(root.width, list.implicitWidth + Theme.space2 * 2)
        implicitHeight: Math.min(list.implicitHeight + Theme.space2 * 2,
                                 Theme.space6 * 8)

        // ⚠️ CLOSED WHEN IT LOSES THE KEYBOARD, which is also "you clicked
        // somewhere else". The old version needed a full-window invisible
        // catcher for that, and a permanent invisible catcher is the bug nobody
        // suspects — it ate clicks meant for the tabs behind it.
        onVisibleChanged: if (!popup.visible) root.menuOpen = false

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: Theme.menuBg

            focus: true
            Keys.onEscapePressed: root.menuOpen = false

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
                        model: root.menuOpen ? root.options : []

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
                                    root.menuOpen = false
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

    function close() { root.menuOpen = false }
}
