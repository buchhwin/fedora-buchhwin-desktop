pragma ComponentBehavior: Bound

// The vertical strip of symbols down the left of a panel.
//
// His choice, in his words: "symbolleiste links statt tab-pillen, nur symbole   english-ok: the request, quoted
// mit tooltip". The tooltip is not decoration — a symbol on its own explains     english-ok: the request, quoted
// less than the word it replaced, and "übersichtlicher" has to mean easier to    english-ok: quoted brief
// read, not merely emptier.
//
// ⚠️ BUILT ONCE AND USED TWICE. The quick panel takes it now; the settings
// window (M8) has the same strip down its left side, and building that
// separately is how the predecessor ended up with two sidebars that drifted
// apart. Anything that belongs to one caller — which entries, which is current
// — comes in from outside.
//
// ⚠️ IT SITS ON `Pill`, not on a bare Rectangle with a TapHandler. Pill carries
// its own hit area sized to the whole shape; a handler added at the call site
// lands in Pill's inner Item, which is only as big as its contents. That was
// the "every pill was half dead" bug — 68x29 lit, 44x21 answering — and reusing
// Pill is what keeps it closed.

import QtQuick
import QtQuick.Layouts
import "../../theme"

// ⚠️ AN `Item`, NOT A `RowLayout`, AND THAT IS A BUG FIX. As a layout the
// tooltip was a layout CHILD, so the layout wrote its `x` while the tooltip's
// own binding wrote it too. The two took turns, the pane jumped under the
// pointer, and the hover flickered — measured in the log as
// `true 1 … false 1 … true 1 … false 1` several times a second, which is why
// the tooltip never stayed up long enough to be seen.
//
// The rail is laid out; the tooltip floats over it. Those are two different
// jobs and they do not belong in one layout.
Item {
    id: root

    // One entry per row: { icon: "dashboard", tooltip: "Overview" }.
    // ⚠️ Every icon name goes through tests/icons.sh first. "Material Icons
    // Round" is missing more names than anyone expects — `grid_view` and
    // `space_dashboard` are both absent, which is how `dashboard` was chosen.
    property var entries: []
    property int currentIndex: 0
    signal activated(int index)

    // ⚠️ TWO WAYS TO SIT, AND THE COMPONENT OWNS BOTH.
    //
    // ⚠️ AND THE FIRST ATTEMPT AT THE SECOND ONE WAS THE WRONG SHAPE. It shared
    // the whole height out as gaps, so the four symbols stood far apart down the
    // full length of a tall panel. He looked at it and said no: "evtl mach alles  english-ok: the request, quoted
    // 4 mittig das wäre besser also nicht über die ganze höhe aber gleiche       english-ok: the request, quoted
    // größe alles schon mittig auf der linken seite". So the group keeps its     english-ok: the request, quoted
    // natural spacing and sits CENTRED in whatever height it is given.
    //
    // It is a property rather than a second component because the settings
    // window (M8) has the same strip and wants the plain top-aligned form — a
    // sidebar of ten pages fills its height on its own. Building that separately
    // is how the predecessor grew two sidebars that drifted apart.
    property bool centred: false

    implicitWidth: rail.implicitWidth
    // ⚠️ Only the NATURAL height is declared. A centred rail takes the height
    // its parent gives it, and asking for that height back as an implicit size
    // is a layout that sizes itself from itself.
    implicitHeight: rail.implicitHeight

    // ⚠️ STACKED ABOVE ITS SIBLINGS, and that belongs to the component rather
    // than to the caller. `z: 100` inside the rail only orders the tooltip
    // against the pills; between SIBLINGS the later one wins, and the rail is
    // the first child of every panel that uses it. Measured on screen: the
    // tooltip drew opaque and correct, and the calendar's "Mon"/"Tue" drew on
    // top of the word anyway.
    z: 1

    ColumnLayout {
        id: rail
        anchors.left: parent.left
        // Top-aligned by default; centred when asked. Never both — anchoring a
        // layout to top AND verticalCenter is a fight QML resolves silently.
        anchors.top: root.centred ? undefined : parent.top
        anchors.verticalCenter: root.centred ? parent.verticalCenter : undefined
        spacing: Theme.space2

        Repeater {
            model: root.entries

            Pill {
                id: railPill
                required property int index
                required property var modelData

                Layout.alignment: Qt.AlignHCenter
                interactive: true
                active: root.currentIndex === railPill.index

                Icon {
                    text: railPill.modelData.icon
                    size: Theme.fontSizeLg
                    color: railPill.active ? Theme.accentFg : Theme.fgMuted
                }

                onClicked: root.activated(railPill.index)

                // Handing the hovered pill up rather than each row owning a
                // tooltip: one tooltip for the whole rail cannot end up with two
                // on screen at once, which is what a per-row one does the moment
                // the pointer crosses between them.
                onHoveredChanged: {
                    if (hovered) {
                        root.hoveredPill = railPill
                        root.hoveredIndex = railPill.index
                    } else if (root.hoveredPill === railPill) {
                        root.hoveredPill = null
                        root.hoveredIndex = -1
                    }
                }
            }
        }
    }

    // ⚠️ TWO PROPERTIES, NOT ONE, AND THE TYPE IS WHY. `hoveredPill` has to be
    // an `Item` because the tooltip positions itself against it — but a property
    // declared as `Item` exposes only Item's own members, so `hoveredPill.index`
    // came back UNDEFINED and the tooltip appeared with no text in it. Measured
    // on screen: the pane was there, the word was not. The index therefore
    // travels on its own rather than being read back off a narrowed type.
    property Item hoveredPill: null
    property int hoveredIndex: -1

    Tooltip {
        target: root.hoveredPill
        // Never an empty box. A pane with no word in it looks like something
        // that failed rather than like a tooltip.
        active: root.hoveredPill !== null && text.length > 0
        text: {
            var e = root.hoveredIndex >= 0 ? root.entries[root.hoveredIndex] : null
            return e ? String(e.tooltip) : ""
        }
    }
}
