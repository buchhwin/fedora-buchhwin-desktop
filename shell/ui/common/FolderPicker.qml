// Choose a directory, without GTK.
//
// ⚠️ A4, AND IT IS THE LAST TEXT BOX THAT NEEDED A CONTROL RATHER THAN A LIST.
// `wallpaper.folder` is a path; there is no set of candidates to offer, so the
// answer is not suggestions but a way to look. Everything else about it was
// already decided: no GTK anywhere in this shell, which rules out the portal
// and every file chooser that comes with one.
//
// ⚠️ NO PROCESS PER STEP, AND THAT WAS WORTH LOOKING UP RATHER THAN ASSUMING.
// The first plan here was one `find -maxdepth 1 -type d` per navigation step —
// user-driven, so never in the idle path, but still a process per click. Qt
// ships `Qt.labs.folderlistmodel`, it is inside qt6-qtdeclarative, and that is
// already in packages/dnf-desktop.txt as quickshell's own runtime. Checked on
// the machine: nine entries under $HOME, directories first. No new dependency,
// no process, and it re-reads by itself when the folder changes.
//
// ⚠️ ITS OWN WINDOW, for the reason the dropdown learned the hard way twice: a
// group card sets `clip: true` so it can fold, and `z` only orders siblings. A
// chooser drawn inside a row would be cut off at the card's edge. `PopupWindow`
// is a real popup surface — nothing in the layout can reach it — and `grabFocus`
// makes Esc an answer rather than a key that closes the settings window behind
// it.
import QtQuick
import QtQuick.Layouts
import Quickshell
import Qt.labs.folderlistmodel
import "../../theme"

Item {
    id: root

    // The directory the picker opens on, as a plain path.
    property string current: ""
    // Anchored under this, the same way the dropdown anchors under its field.
    property Item anchorItem: null
    property bool open: false

    signal chosen(string path)

    // ⚠️ TWO SPELLINGS OF THE SAME PLACE, and keeping them apart is most of the
    // fiddliness here. FolderListModel speaks file: URLs; the setting holds a
    // plain path. Everything inside this file works in `where` (a path) and
    // converts at the two edges only, so a "file://" can never end up in
    // shell.json — which would be a folder the wallpaper service cannot open.
    property string where: ""

    function toUrl(p) { return "file://" + p }
    function toPath(u) {
        var s = String(u)
        return s.indexOf("file://") === 0 ? s.substring(7) : s
    }
    function parentOf(p) {
        if (p === "/" || p.length === 0)
            return "/"
        var cut = p.replace(/\/+$/, "")
        var i = cut.lastIndexOf("/")
        return i <= 0 ? "/" : cut.substring(0, i)
    }

    function show() {
        // Open where the setting points, or at home when it points nowhere —
        // opening at "/" would be technically correct and useless.
        var start = root.current.length > 0 ? root.current : Quickshell.env("HOME")
        root.where = start
        root.open = true
    }

    // ⚠️⚠️ BEHIND A LOADER, AND THE JOURNAL IS WHY. Written as a plain
    // FolderListModel it exists from the moment the settings window is built,
    // with `where` still empty — so its folder is "file://", and Qt says so:
    //
    //   WARN: QFileSystemWatcher::removePath: path is empty
    //
    // Measured with a control rather than guessed at: restarting the shell
    // without opening the window gives 0 of those, opening the window gives 1.
    //
    // The warning is the small half. The real one is that a model built at
    // window time READS A DIRECTORY AND WATCHES IT for a chooser nobody has
    // opened — on a page with a wallpaper folder of several thousand files,
    // that is a scan and an inotify watch for nothing. Nothing in this shell may
    // work while it is idle, and this was doing it in the quietest possible way.
    Loader {
        id: dirsLoader
        active: root.open
        sourceComponent: FolderListModel {
            folder: root.toUrl(root.where)
            // Directories only: this chooses a folder, and a list of 4000
            // wallpapers would bury the four folders among them.
            showFiles: false
            showDirs: true
            showDotAndDotDot: false
            showHidden: false
            sortField: FolderListModel.Name
        }
    }
    readonly property int entryCount: dirsLoader.item ? dirsLoader.item.count : 0

    PopupWindow {
        id: popup

        visible: root.open
        color: "transparent"            // literal-ok: absence of colour

        anchor.item: root.anchorItem
        anchor.rect.y: root.anchorItem ? root.anchorItem.height + Theme.space1 : 0
        anchor.edges: Edges.Bottom | Edges.Left
        anchor.gravity: Edges.Bottom | Edges.Right
        anchor.adjustment: PopupAdjustment.All

        grabFocus: true

        implicitWidth: Math.max(root.anchorItem ? root.anchorItem.width : 0, Theme.space6 * 12)
        implicitHeight: Theme.space6 * 10

        onVisibleChanged: if (!popup.visible) root.open = false

        Rectangle {
            anchors.fill: parent
            radius: Theme.radiusMd
            color: Theme.menuBg

            focus: true
            Keys.onEscapePressed: root.open = false

            ColumnLayout {
                anchors.fill: parent
                anchors.margins: Theme.space2
                spacing: Theme.space2

                // ------------------------------------------------ where we are
                RowLayout {
                    Layout.fillWidth: true
                    spacing: Theme.space2

                    Pill {
                        interactive: root.where !== "/"
                        Icon {
                            text: "arrow_upward"
                            size: Theme.fontSizeSm
                            color: root.where !== "/" ? Theme.fg : Theme.fgMuted
                        }
                        onClicked: root.where = root.parentOf(root.where)
                    }

                    // ⚠️ ELIDED FROM THE LEFT. A path is identified by its END —
                    // ".../Pictures/Wallpapers" — and cutting the right-hand
                    // side would leave "/home/buchhwin/Pict…" on every deep
                    // folder, which is the half that says nothing.
                    BarText {
                        Layout.fillWidth: true
                        text: root.where
                        color: Theme.fgMuted
                        elide: Text.ElideLeft
                        maximumLineCount: 1
                    }
                }

                // ------------------------------------------------- what is here
                Flickable {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    contentWidth: width
                    contentHeight: entries.implicitHeight
                    boundsBehavior: Flickable.StopAtBounds
                    clip: true

                    ColumnLayout {
                        id: entries
                        width: parent.width
                        spacing: 0      // literal-ok: rows meet, separated by their own padding

                        // An empty folder is a real answer and says so, rather
                        // than looking like a chooser that failed to load.
                        BarText {
                            Layout.fillWidth: true
                            Layout.margins: Theme.space3
                            visible: root.entryCount === 0
                            text: "No folders in here"
                            color: Theme.fgMuted
                            font.pixelSize: Theme.fontSizeSm
                        }

                        Repeater {
                            model: dirsLoader.item

                            Rectangle {
                                id: entry
                                required property int index
                                required property string fileName

                                Layout.fillWidth: true
                                implicitHeight: name.implicitHeight + Theme.space2 * 2
                                radius: Theme.radiusSm
                                color: entryHover.hovered ? Theme.pillHover
                                                          : "transparent"   // literal-ok: absence of colour

                                Behavior on color {
                                    enabled: Theme.animate
                                    ColorAnimation { duration: Theme.durFast; easing.type: Theme.easing }
                                }

                                HoverHandler { id: entryHover }
                                // ⚠️ ONE CLICK GOES IN, IT DOES NOT CHOOSE. Both
                                // on one gesture would mean you cannot walk
                                // through a folder without picking it; "Choose
                                // this folder" below is the deliberate act, and
                                // it names the folder it will pick.
                                TapHandler {
                                    onTapped: root.where =
                                        root.where.replace(/\/+$/, "") + "/" + entry.fileName
                                }

                                RowLayout {
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.leftMargin: Theme.space3
                                    anchors.rightMargin: Theme.space3
                                    spacing: Theme.space2

                                    Icon {
                                        text: "folder"
                                        size: Theme.fontSizeSm
                                        color: Theme.fgMuted
                                    }
                                    BarText {
                                        id: name
                                        Layout.fillWidth: true
                                        text: entry.fileName
                                        color: Theme.fg
                                        elide: Text.ElideRight
                                    }
                                }
                            }
                        }
                    }
                }

                // ------------------------------------------------- the decision
                Pill {
                    Layout.fillWidth: true
                    interactive: true
                    active: true
                    BarText {
                        text: "Choose this folder"
                        color: Theme.accentFg
                    }
                    onClicked: {
                        root.chosen(root.where)
                        root.open = false
                    }
                }
            }
        }
    }
}
