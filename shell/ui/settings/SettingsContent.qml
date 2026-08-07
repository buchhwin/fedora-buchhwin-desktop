pragma ComponentBehavior: Bound

// The inside of the settings window, laid out from his reference.
//
// Left: a search field over ten named rows. Right: back and forward, then the
// page's symbol, heading and one explaining line, then the settings themselves
// as rows separated by space rather than by lines.
//
// ⚠️ THE TEN PAGES AND THEIR ORDER ARE THE SPECIFICATION, not a starting point.
// They are named in the reference, in this order, and they are the same ten the
// brief lists. All ten exist, and between them every one of the 135 settings in
// shell.json has exactly one row — which is what tests/setting-rows.sh counts,
// so "everything is settable" is a number rather than a belief.
import QtQuick
import QtQuick.Layouts
import "pages"
import "../common"
import "../../ipc"
import "../../services" as Services
import "../../theme"

FocusScope {
    id: root

    // ⚠️ Every icon name goes through tests/icons.sh. "Material Icons Round" is
    // missing more names than anyone expects — the quick panel ended up on
    // `dashboard` because `grid_view` and `space_dashboard` are both absent.
    readonly property var pages: [
        { id: "bar",      icon: "view_agenda",   title: "Bar & Island",
          blurb: "Shape and size of the island, the notch, and the bar." },
        { id: "media",    icon: "music_note",    title: "Media",
          blurb: "Which player the island follows, and where the track is shown." },
        { id: "clock",    icon: "schedule",      title: "Clock & Date",
          blurb: "How the time and the date are written, everywhere they are." },
        { id: "look",     icon: "palette",       title: "Appearance",
          blurb: "Colours, the wallpaper, shape, transparency, effects, type, and one state per themed program." },
        // ⚠️ `speed`, and the obvious name was wrong: "Material Icons Round"
        // has no `animation` at all. tests/icons.sh caught it by measuring the
        // glyph — 800 px wide where a real one is about 70, which is the
        // fallback box. Asked the font for sixteen candidates rather than
        // guessing a second time.
        { id: "motion",   icon: "speed",         title: "Motion",
          blurb: "Whether things move, and how much else is drawn." },
        { id: "launcher", icon: "apps",          title: "Launcher",
          blurb: "The program list and how it opens." },
        { id: "notify",   icon: "notifications", title: "Notifications",
          blurb: "Arriving messages, how long they stay, and where." },
        { id: "control",  icon: "tune",          title: "Control Center",
          blurb: "Brightness, night light, the work timer and the clipboard." },
        { id: "lock",     icon: "lock",          title: "Lock Screen",
          blurb: "What the screen shows while the session is locked." },
        { id: "system",   icon: "computer",      title: "System",
          blurb: "Keyboard, touchpad, windows, programs, the session and the key bindings." }
    ]

    // ---------------------------------------------------------------- history
    // Back and forward, which the reference puts at the top of the content.
    // A plain stack: everything after the current position is dropped when you
    // go somewhere new, which is what makes forward mean "where I came back
    // from" rather than "somewhere I have been at some point".
    property var history: ["bar"]
    property int historyIndex: 0

    readonly property string currentId: root.history[root.historyIndex]
    readonly property var currentPage: {
        for (var i = 0; i < root.pages.length; i++)
            if (root.pages[i].id === root.currentId)
                return root.pages[i]
        return root.pages[0]
    }

    function navigate(id) {
        if (id === root.currentId)
            return
        var h = root.history.slice(0, root.historyIndex + 1)
        h.push(id)
        root.history = h
        root.historyIndex = h.length - 1
    }

    function back() { if (root.historyIndex > 0) root.historyIndex-- }
    function forward() { if (root.historyIndex < root.history.length - 1) root.historyIndex++ }

    // ----------------------------------------------------------------- search
    // ⚠️ TITLES AND THE EXPLAINING LINES, NOT ROW LABELS — and with 135 rows
    // that is now a real limit rather than a note. Typing "blur" finds nothing,
    // because the word is on a row inside Appearance and not in any page's own
    // description. Searching rows means every page building its list without
    // being open, which is a change to how a page is declared; saying what the
    // box does beats a box that quietly finds a tenth of what you asked for.
    readonly property var shown: {
        var q = search.text.trim().toLowerCase()
        if (q.length === 0)
            return root.pages
        var out = []
        for (var i = 0; i < root.pages.length; i++) {
            var p = root.pages[i]
            if (p.title.toLowerCase().indexOf(q) >= 0 || p.blurb.toLowerCase().indexOf(q) >= 0)
                out.push(p)
        }
        return out
    }

    Keys.onEscapePressed: Ipc.hideSettings()

    RowLayout {
        anchors.fill: parent
        anchors.margins: Theme.space4
        spacing: Theme.space4

        // ------------------------------------------------------------ sidebar
        ColumnLayout {
            Layout.fillHeight: true
            Layout.preferredWidth: Theme.space6 * 7
            spacing: Theme.space3

            TextField {
                id: search
                Layout.fillWidth: true
                placeholder: "Search Settings"
                onCancelled: {
                    if (search.text.length > 0)
                        search.text = ""
                    else
                        Ipc.hideSettings()
                }
                // The first match, so typing three letters and pressing Return
                // is a way to get somewhere rather than only a way to filter.
                onAccepted: if (root.shown.length > 0) root.navigate(root.shown[0].id)
            }

            SettingsRail {
                Layout.fillWidth: true
                entries: root.shown
                currentIndex: {
                    for (var i = 0; i < root.shown.length; i++)
                        if (root.shown[i].id === root.currentId)
                            return i
                    return -1
                }
                onActivated: function (i) { root.navigate(root.shown[i].id) }
            }

            // Nothing matched. One sentence, per the brief — not an empty box
            // and not a spinner.
            BarText {
                Layout.fillWidth: true
                visible: root.shown.length === 0
                text: "No page by that name"
                color: Theme.fgMuted
                wrapMode: Text.WordWrap
            }

            Item { Layout.fillHeight: true }
        }

        // ------------------------------------------------------------ content
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: Theme.space4

            // ⚠️ THE ONE PLACE A REFUSED SETTING BECOMES VISIBLE, and it is
            // here because this is where the setting was made. The generator
            // will not install a config.kdl that niri rejects — an invalid one
            // means niri does not start at all — so a bad value leaves the
            // desktop working and the change simply not applied. Without this
            // banner that is indistinguishable from a control that does
            // nothing, which is the exact failure this whole window exists to
            // stop. It was also `Theming.lastError`'s first reader: the
            // property had none.
            Rectangle {
                Layout.fillWidth: true
                visible: Services.Theming.lastError.length > 0
                implicitHeight: refusal.implicitHeight + Theme.space3 * 2
                radius: Theme.radiusSm
                color: Theme.pillBg

                ColumnLayout {
                    id: refusal
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space1

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space2
                        Icon { text: "warning"; size: Theme.fontSize; color: Theme.warn }
                        BarText {
                            Layout.fillWidth: true
                            text: "The last change was not applied"
                            color: Theme.warn
                            font.weight: Theme.weightMedium
                        }
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: Services.Theming.lastError
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                        elide: Text.ElideNone
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: "The desktop still boots — the previous configuration was kept. "
                            + "Details in /tmp/buchhwin-niri.log."
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                    }
                }
            }

            RowLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Pill {
                    interactive: root.historyIndex > 0
                    opacity: root.historyIndex > 0 ? 1 : Theme.dimmed
                    Icon { text: "arrow_back"; size: Theme.fontSize; color: Theme.fg }
                    onClicked: root.back()
                }
                Pill {
                    interactive: root.historyIndex < root.history.length - 1
                    opacity: root.historyIndex < root.history.length - 1 ? 1 : Theme.dimmed
                    Icon { text: "arrow_forward"; size: Theme.fontSize; color: Theme.fg }
                    onClicked: root.forward()
                }
                Item { Layout.fillWidth: true }
            }

            // The page's own head: symbol in a rounded square, heading, and one
            // muted line under it. Centred, as the reference has it.
            ColumnLayout {
                Layout.fillWidth: true
                spacing: Theme.space2

                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: Theme.space6 + Theme.space3
                    implicitHeight: Theme.space6 + Theme.space3
                    radius: Theme.radiusMd
                    color: Theme.surfaceHigh

                    Icon {
                        anchors.centerIn: parent
                        text: root.currentPage.icon
                        size: Theme.fontSizeXl
                        color: Theme.accent
                    }
                }

                BarText {
                    Layout.alignment: Qt.AlignHCenter
                    text: root.currentPage.title
                    font.pixelSize: Theme.fontSizeLg
                    font.weight: Theme.weightSemibold
                }

                BarText {
                    Layout.fillWidth: true
                    text: root.currentPage.blurb
                    font.pixelSize: Theme.fontSizeSm
                    color: Theme.fgMuted
                    horizontalAlignment: Text.AlignHCenter
                    wrapMode: Text.WordWrap
                    elide: Text.ElideNone
                }
            }

            // ------------------------------------------------------- the rows
            Flickable {
                id: scroller
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                contentWidth: width
                contentHeight: pageLoader.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                Loader {
                    id: pageLoader
                    // Room for the scrollbar, so a row's right edge and the bar
                    // are not fighting over the same pixels.
                    width: scroller.width - Theme.space3
                    height: implicitHeight

                    // ⚠️ `sourceComponent` needs a Component, never an instance.
                    // QML accepts an instance without a word of complaint and
                    // then never builds the thing.
                    sourceComponent: root.currentId === "bar" ? barPage
                                   : root.currentId === "media" ? mediaPage
                                   : root.currentId === "clock" ? clockPage
                                   : root.currentId === "lock" ? lockPage
                                   : root.currentId === "look" ? appearancePage
                                   : root.currentId === "motion" ? motionPage
                                   : root.currentId === "launcher" ? launcherPage
                                   : root.currentId === "notify" ? notifyPage
                                   : root.currentId === "control" ? controlPage
                                   : root.currentId === "system" ? systemPage
                                   : missingPage
                }

                // The narrow scrollbar the reference draws down the right-hand
                // side. Hidden when everything fits: a bar that is always the
                // full height of its track says nothing and takes up room.
                Rectangle {
                    id: scrollbar
                    anchors.right: parent.right
                    width: Theme.space1
                    radius: Theme.radiusPill
                    color: Theme.outlineStrong

                    visible: scroller.contentHeight > scroller.height
                    height: scroller.height
                          * (scroller.height / Math.max(1, scroller.contentHeight))
                    y: scroller.contentY
                     * (scroller.height / Math.max(1, scroller.contentHeight))
                }
            }
        }
    }

    Component { id: barPage; BarIslandPage {} }
    Component { id: appearancePage; AppearancePage {} }
    Component { id: motionPage; MotionPage {} }
    Component { id: launcherPage; LauncherPage {} }
    Component { id: notifyPage; NotifyPage {} }
    Component { id: controlPage; ControlCenterPage {} }
    Component { id: systemPage; SystemPage {} }
    Component { id: mediaPage; MediaPage {} }
    Component { id: clockPage; ClockPage {} }
    Component { id: lockPage; LockPage {} }

    // ⚠️ NOT DEAD CODE, THOUGH EVERY ID ABOVE MAPS TO A PAGE. This is what
    // appears if an entry is added to `pages` and its Component is forgotten —
    // a real mistake with an otherwise silent symptom, because a Loader with a
    // null component draws nothing at all and reads as a page that is simply
    // empty.
    Component {
        id: missingPage

        ColumnLayout {
            spacing: Theme.space2

            BarText {
                Layout.fillWidth: true
                text: root.currentPage.title + " has no page behind it."
                color: Theme.error
                wrapMode: Text.WordWrap
            }
            BarText {
                Layout.fillWidth: true
                text: "The entry is in the list but its Component is missing — add "
                    + "one beside the others in SettingsContent.qml."
                font.pixelSize: Theme.fontSizeSm
                color: Theme.fgMuted
                wrapMode: Text.WordWrap
            }
        }
    }
}
