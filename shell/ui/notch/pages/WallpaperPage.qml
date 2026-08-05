pragma ComponentBehavior: Bound

// Choosing a wallpaper, as a page of the island.
//
// It was a full-screen window first. It is not one any more, and the reason is
// the rule the whole shell is built on: the island does not summon a second
// window, it BECOMES the thing you asked for. A grid that darkens the screen
// and floats in the middle is a different program wearing our colours.
//
// So this is a row, not a grid: the island is wide and short, and a shape that
// grows sideways from a shape that is already wide reads as one movement.
// Scrolling sideways through covers is also how you actually look at pictures.
//
// Keyboard first — arrows move, Enter chooses, Escape closes — because a picker
// you have to aim at is a picker you stop using.
import QtQuick
import "../../../theme"
import "../../../config"
import "../../../ipc"
import "../../../services" as Services
import "../../common"

Item {
    id: root

    // Sized so the island keeps its reference height rather than growing: this
    // page has nothing that needs more room, and the shape you know is worth
    // more than slightly larger thumbnails.
    //
    // ⚠️ It reads the CONFIGURED height, never the island's current one. The
    // island's height follows the page; a page that followed the island back
    // would be a binding loop.
    // The island's own padding is space5 top and bottom, so this is what is
    // left. Covers are 16:9 because wallpapers are.
    //
    // There is deliberately no file name under the covers. A row of names would
    // cost a third of the height and answer a question the picture already
    // answers; the tick marks the one in use and the accent marks the cursor.
    readonly property int coverH:
        Math.max(Theme.space6, Config.notch.expandedHeight - Theme.space5 * 2)
    readonly property int coverW: Math.round(coverH * 16 / 9)

    implicitWidth: Math.max(1, Math.min(Services.Wallpaper.count, 4))
                   * (coverW + Theme.space2)
    implicitHeight: coverH

    // The page is created when the island opens, so this is the right moment.
    Component.onCompleted: {
        row.currentIndex = Services.Wallpaper.indexOf(Services.Wallpaper.current)
        row.positionViewAtIndex(row.currentIndex, ListView.Contain)
        row.forceActiveFocus()
    }

    // An empty state is one sentence that says what to do about it, never an
    // empty box or a spinner.
    BarText {
        anchors.centerIn: parent
        visible: !Services.Wallpaper.available
        color: Theme.fgMuted
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.WordWrap
        width: parent.width
        text: Config.wallpaper.folder.length === 0
              ? "No picture folder set — wallpaper.folder in shell.json"
              : "No supported images in that folder"
    }

    ListView {
        id: row
        anchors.fill: parent
        visible: Services.Wallpaper.available
        orientation: ListView.Horizontal
        spacing: Theme.space2
        clip: true
        focus: true
        // The island is not a document view; a cover always lands whole.
        snapMode: ListView.SnapToItem
        highlightMoveDuration: Theme.durFast
        model: Services.Wallpaper.model

        Keys.onEscapePressed: Ipc.collapse()
        Keys.onReturnPressed: row.choose(row.currentIndex)
        Keys.onEnterPressed: row.choose(row.currentIndex)

        function choose(i) {
            if (i < 0 || i >= Services.Wallpaper.count)
                return
            // Writes one key in shell.json. Everything else — the image on
            // screen, the derived palette, GTK, Qt, kitty, niri — follows from
            // that, and follows again after a restart. See theme/Scheme.qml.
            Services.Wallpaper.choose(Services.Wallpaper.pathAt(i))
        }

        delegate: Item {
            id: cell
            required property int index
            required property url fileUrl

            width: root.coverW
            height: row.height

            Rectangle {
                anchors.fill: parent
                radius: Theme.radiusMd
                color: Theme.surface
                clip: true

                // The cursor, marked with the accent — the one thing accent is
                // for. Kept separate from the tick below on purpose: "which one
                // is under the cursor" and "which one am I using" are different
                // questions and must not share a mark.
                border.width: cell.index === row.currentIndex ? Theme.space1 / 2 : 0
                border.color: Theme.accent

                Image {
                    anchors.fill: parent
                    anchors.margins: parent.border.width
                    source: cell.fileUrl
                    fillMode: Image.PreserveAspectCrop
                    // ⚠️ Without sourceSize a folder of 6000x3750 PNGs decodes
                    // hundreds of megabytes to draw thumbnails. This is the
                    // difference between a page that opens and one that stalls
                    // the compositor.
                    sourceSize.width: root.coverW
                    sourceSize.height: root.coverH
                    asynchronous: true
                    cache: true
                }

                Pill {
                    anchors { bottom: parent.bottom; right: parent.right
                              margins: Theme.space1 }
                    visible: String(cell.fileUrl) === Services.Wallpaper.current
                    active: true
                    Icon { text: "check"; size: Theme.fontSize; color: Theme.accentFg }
                }

                TapHandler {
                    onTapped: {
                        row.currentIndex = cell.index
                        row.choose(cell.index)
                    }
                }
            }
        }
    }
}
