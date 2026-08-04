// The wallpaper picker: every image at a glance, pick one.
//
// A window rather than a page of the island: a grid of covers needs room, and
// the island is for glances, not for browsing. It is still the same palette,
// the same radii and the same motion — the design does not change because the
// surface does.
//
// Keyboard first: arrows move, Enter chooses, Escape closes. A picker you have
// to aim at with a mouse is a picker you avoid.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../ipc"
import "../../services" as Services
import "../common"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "buchhwin-wallpaper-picker"
    WlrLayershell.layer: WlrLayer.Overlay
    // Exclusive: arrows and Enter must reach the grid, not the window below.
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    anchors { top: true; bottom: true; left: true; right: true }
    exclusionMode: ExclusionMode.Ignore
    color: Theme.scrim

    Component.onCompleted: grid.forceActiveFocus()

    // Clicking the backdrop closes, like the island.
    TapHandler { onTapped: Ipc.collapse() }

    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - Theme.space6 * 2, Theme.space6 * 30)
        height: Math.min(parent.height - Theme.space6 * 2, Theme.space6 * 20)
        radius: Theme.radiusLg
        color: Theme.panelBg

        // Swallow clicks so the backdrop handler does not fire through here.
        TapHandler {}

        BarText {
            id: title
            anchors { top: parent.top; left: parent.left; margins: Theme.space4 }
            text: Services.Wallpaper.available
                  ? "Hintergrund wählen"
                  : "Kein Ordner eingestellt"
            font.pixelSize: Theme.fontSizeLg
            font.weight: Theme.weightSemibold
        }

        BarText {
            anchors { top: title.bottom; left: parent.left; right: parent.right
                      margins: Theme.space4; topMargin: Theme.space2 }
            visible: !Services.Wallpaper.available
            wrapMode: Text.WordWrap
            color: Theme.fgMuted
            // An empty state is one sentence, and it says what to do about it.
            text: Config.wallpaper.folder.length === 0
                  ? "Trage einen Ordner unter wallpaper.folder in shell.json ein."
                  : "In diesem Ordner liegen keine unterstützten Bilder."
        }

        GridView {
            id: grid
            anchors { top: title.bottom; left: parent.left; right: parent.right
                      bottom: parent.bottom; margins: Theme.space4 }
            visible: Services.Wallpaper.available
            clip: true
            focus: true

            cellWidth: Theme.space6 * 7
            cellHeight: Theme.space6 * 5
            model: Services.Wallpaper.model

            Keys.onEscapePressed: Ipc.collapse()
            Keys.onReturnPressed: grid.choose(grid.currentIndex)
            Keys.onEnterPressed: grid.choose(grid.currentIndex)

            function choose(i) {
                if (i < 0 || i >= Services.Wallpaper.count) return
                Services.Wallpaper.choose(Services.Wallpaper.pathAt(i))
                Ipc.collapse()
            }

            delegate: Item {
                id: cell
                required property int index
                required property url fileURL
                required property string fileName

                width: grid.cellWidth
                height: grid.cellHeight

                Rectangle {
                    anchors.fill: parent
                    anchors.margins: Theme.space1
                    radius: Theme.radiusMd
                    color: Theme.surface
                    clip: true

                    // The keyboard cursor, marked with the accent — the one thing
                    // accent is for.
                    border.width: cell.index === grid.currentIndex ? Theme.space1 / 2 : 0
                    border.color: Theme.accent

                    Image {
                        anchors.fill: parent
                        source: cell.fileURL
                        fillMode: Image.PreserveAspectCrop
                        // Decoded small. Without this a folder of 4K images
                        // decodes hundreds of megabytes to draw thumbnails.
                        sourceSize.width: grid.cellWidth
                        sourceSize.height: grid.cellHeight
                        asynchronous: true
                        cache: true
                    }

                    // The current wallpaper is marked, not merely highlighted:
                    // "which one am I using" is a different question from
                    // "which one is under the cursor".
                    Pill {
                        anchors { bottom: parent.bottom; right: parent.right
                                  margins: Theme.space1 }
                        visible: String(cell.fileURL) === Services.Wallpaper.current
                        active: true
                        Icon { text: "check"; size: Theme.fontSize; color: Theme.accentFg }
                    }

                    TapHandler {
                        onTapped: {
                            grid.currentIndex = cell.index
                            grid.choose(cell.index)
                        }
                    }
                }
            }
        }
    }
}
