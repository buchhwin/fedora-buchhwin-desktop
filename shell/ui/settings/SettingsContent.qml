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
// ⚠️ NO `import "pages"`. The pages are reached by URL now, not by type name,
// so importing the folder would be importing something for nothing — and an
// import that is there for no reason is the one nobody dares remove later.
import "../common"
import "../../ipc"
import "../../services" as Services
import "../../theme"

FocusScope {
    id: root

    // ⚠️ ONE PROCESS, THE FIRST TIME THIS WINDOW OPENS, AND NEVER AT STARTUP.
    // Services.Gpu answers a question that changes at most twice in a machine's
    // life — is Secure Boot standing in the way of the NVIDIA module — so
    // asking on every login would be a fork on the start path for nothing, and
    // `bhctl doctor` measures that path. The service guards itself against a
    // second run, so opening the window ten times still costs one.
    //
    // The other two routes to the same answer already exist: the installer says
    // it on the terminal, and `bhctl doctor` says it over SSH.
    Component.onCompleted: Services.Gpu.probe()

    // ⚠️ ONE ENTRY IS THE WHOLE REGISTRATION, and it used to be three. A page
    // needed a line here, a `Component { id: fooPage; FooPage {} }` further
    // down, AND a branch in a ten-way ternary on `currentId`. Forgetting the
    // third produced a page that drew nothing, which is why there was a
    // hand-written placeholder explaining that exact mistake.
    //
    // `source` is a relative URL, which quickshell resolves through its virtual
    // filesystem — proven by shell.qml, which boots the entire shell that way
    // (`source: "ui/Shell.qml"`). A wrong path is now loud: Loader.status goes
    // to Error and says so on screen, instead of drawing an empty page.
    //
    // It also buys the row search: a page's rows only exist once it is built,
    // and a URL is something the search can build off-screen and throw away.
    // A Component id could not have been handed around like that.
    //
    // ⚠️ Every icon name goes through tests/icons.sh. "Material Icons Round" is
    // missing more names than anyone expects — the quick panel ended up on
    // `dashboard` because `grid_view` and `space_dashboard` are both absent.
    readonly property var pages: [
        { id: "bar",      icon: "view_agenda",   title: "Bar & Island",
          source: "pages/BarIslandPage.qml",
          blurb: "Shape and size of the island, the notch, and the bar." },
        { id: "media",    icon: "music_note",    title: "Media",
          source: "pages/MediaPage.qml",
          blurb: "Which player the island follows, and where the track is shown." },
        { id: "clock",    icon: "schedule",      title: "Clock & Date",
          source: "pages/ClockPage.qml",
          blurb: "How the time and the date are written, everywhere they are." },
        { id: "look",     icon: "palette",       title: "Appearance",
          source: "pages/AppearancePage.qml",
          blurb: "Colours, the wallpaper, shape, transparency, effects, type, and one state per themed program." },
        // ⚠️ `speed`, and the obvious name was wrong: "Material Icons Round"
        // has no `animation` at all. tests/icons.sh caught it by measuring the
        // glyph — 800 px wide where a real one is about 70, which is the
        // fallback box. Asked the font for sixteen candidates rather than
        // guessing a second time.
        { id: "motion",   icon: "speed",         title: "Motion",
          source: "pages/MotionPage.qml",
          blurb: "Whether things move, and how much else is drawn." },
        { id: "launcher", icon: "apps",          title: "Launcher",
          source: "pages/LauncherPage.qml",
          blurb: "The program list and how it opens." },
        { id: "notify",   icon: "notifications", title: "Notifications",
          source: "pages/NotifyPage.qml",
          blurb: "Arriving messages, how long they stay, and where." },
        { id: "control",  icon: "tune",          title: "Control Center",
          source: "pages/ControlCenterPage.qml",
          blurb: "Brightness, night light, the work timer and the clipboard." },
        { id: "lock",     icon: "lock",          title: "Lock Screen",
          source: "pages/LockPage.qml",
          blurb: "What the screen shows while the session is locked." },
        // ⚠️ `battery_full`, which NotchWide already draws — so it is a name
        // this font is known to have. tests/icons.sh measures the glyph rather
        // than trusting the name, and a missing one comes out as an 800 px
        // fallback box.
        { id: "power",    icon: "battery_full",  title: "Power",
          source: "pages/PowerPage.qml",
          blurb: "When the screen goes off, when the session locks, when it sleeps, and what the lid does." },
        { id: "system",   icon: "computer",      title: "System",
          source: "pages/SystemPage.qml",
          blurb: "Keyboard, touchpad, graphics, windows, programs, the session and the key bindings." }
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
        //
        // ⚠️ PINNED, AND MEASURED BEFORE IT WAS. `Layout.preferredWidth` alone
        // is only a WISH: the content beside it has `fillWidth`, so a wide page
        // took room from the sidebar and a narrow one gave it back. The active
        // row was 312 px on Bar & Island, 282 on Clock & Date, 243 on System and
        // 208 on Appearance — the sidebar breathed with whichever page was open,
        // which is what he reported as wasted space.
        //
        // Pinned on all three, so the layout has nothing to negotiate. And the
        // number comes from the LONGEST ENTRY rather than from an invented
        // multiple of the grid: "Control Center" decides how wide this is, not
        // me. The floor only covers the case where the search field is the
        // widest thing in here.
        ColumnLayout {
            id: sidebar

            readonly property int pinned:
                Math.max(rail.implicitWidth, Theme.space6 * 5)

            Layout.fillHeight: true
            Layout.preferredWidth: sidebar.pinned
            Layout.minimumWidth: sidebar.pinned
            Layout.maximumWidth: sidebar.pinned
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
                id: rail
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

                    // ⚠️ Not decoration. Putting the offending setting back does
                    // not move the fingerprint, so nothing regenerates and this
                    // banner would keep reporting a failure that is already
                    // repaired. This is the door out.
                    Pill {
                        interactive: !Services.Theming.busy
                        opacity: Services.Theming.busy ? Theme.dimmed : 1
                        BarText {
                            text: Services.Theming.busy ? "Trying…" : "Try again"
                            color: Theme.fg
                        }
                        onClicked: Services.Theming.retry()
                    }
                }
            }

            // ⚠️ THE ONE HARDWARE STATE THE DESKTOP CAN SEE AND THE USER CANNOT.
            // Four conditions at once, deliberately: an NVIDIA card is here, its
            // module has been built, Secure Boot is on, and the module is not
            // loaded. That combination has exactly one cause — the akmods
            // signing key was never enrolled, because the blue firmware screen
            // at the next boot has a short timeout and is easy to miss.
            //
            // ⚠️ AND THE FIRST LINE OF THE TEXT IS THAT IT DOES NOT MATTER MUCH.
            // A warning that reads like a broken machine, on a machine that is
            // working perfectly, is how people learn to click warnings away.
            // niri draws on the integrated GPU; this costs the second card.
            //
            // Same shape as the banner above rather than a new one: same
            // rounded pill background, same `warning` glyph — which tests/
            // icons.sh has already proven exists in the font.
            Rectangle {
                Layout.fillWidth: true
                visible: Services.Gpu.needsEnrolment
                implicitHeight: mok.implicitHeight + Theme.space3 * 2
                radius: Theme.radiusSm
                color: Theme.pillBg

                ColumnLayout {
                    id: mok
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.leftMargin: Theme.space3
                    anchors.rightMargin: Theme.space3
                    spacing: Theme.space1

                    // Local state, not an IPC verb: nothing outside this card
                    // needs to know whether the steps are open, and a verb
                    // nobody calls is a verb that rots.
                    property bool stepsOpen: false

                    RowLayout {
                        Layout.fillWidth: true
                        spacing: Theme.space2
                        Icon { text: "warning"; size: Theme.fontSize; color: Theme.warn }
                        BarText {
                            Layout.fillWidth: true
                            text: "Secure Boot is blocking the NVIDIA driver"
                            color: Theme.warn
                            font.weight: Theme.weightMedium
                        }
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: "Nothing on this desktop depends on it: niri draws with the built-in "
                            + "graphics. Only offloading and any monitor wired to the second card "
                            + "are affected."
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                    }
                    BarText {
                        Layout.fillWidth: true
                        visible: mok.stepsOpen
                        // ⚠️ TWO DIFFERENT ANSWERS, because the useful one
                        // depends on whether an enrolment is already waiting.
                        // Telling somebody to run a command they ran an hour ago
                        // is how a correct message becomes a useless one.
                        text: Services.Gpu.enrolmentPending
                            ? "An enrolment is already scheduled.\n\n"
                              + "1. Reboot.\n"
                              + "2. A blue screen appears: choose Enroll MOK, Continue, Yes.\n"
                              + "3. Type the one-time password you chose during installation.\n\n"
                              + "The screen times out, so answer it when it appears."
                            : "In a terminal:\n\n"
                              // The trailing marker sits on the string's own line because
                              // tests/english.sh reads line by line. Safe here: the next
                              // line begins with `+`, so no semicolon can be inferred.
                              + "    sudo mokutil --import /etc/pki/akmods/certs/public_key.der\n\n"   // english-ok: .der is the certificate encoding
                              + "It asks for a one-time password twice. Then reboot: a blue screen "
                              + "appears, choose Enroll MOK, Continue, Yes, and type that password.\n\n"
                              + "The screen times out, so answer it when it appears."
                        font.pixelSize: Theme.fontSizeSm
                        font.family: Theme.fontMono
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                    }
                    Pill {
                        interactive: true
                        BarText {
                            text: mok.stepsOpen ? "Hide steps" : "Show steps"
                            color: Theme.fg
                        }
                        onClicked: mok.stepsOpen = !mok.stepsOpen
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
                contentHeight: pageLoader.status === Loader.Error
                             ? broken.implicitHeight : pageLoader.implicitHeight
                boundsBehavior: Flickable.StopAtBounds

                // ⚠️ A NEW PAGE STARTS AT THE TOP. The Flickable lives OUTSIDE
                // the Loader, so its scroll position survived the page change:
                // opening System from a scrolled Appearance dropped you into the
                // middle of the touchpad settings, with the group heading above
                // the fold. Both references reset — and so does every browser.
                Connections {
                    target: root
                    function onCurrentIdChanged() { scroller.contentY = 0 }
                }

                Loader {
                    id: pageLoader
                    // Room for the scrollbar, so a row's right edge and the bar
                    // are not fighting over the same pixels.
                    width: scroller.width - Theme.space3
                    height: implicitHeight

                    source: root.currentPage.source
                }

                // ⚠️ NOT DEAD CODE, though every entry above names a file that
                // exists. This is what a mistyped or deleted page looks like now
                // — and it is the same fault the old placeholder was for, caught
                // one step earlier: a Loader whose source will not load reports
                // Error, where a Loader with a null component simply drew
                // nothing and read as a page that happened to be empty.
                ColumnLayout {
                    id: broken
                    width: pageLoader.width
                    visible: pageLoader.status === Loader.Error
                    spacing: Theme.space2

                    BarText {
                        Layout.fillWidth: true
                        text: root.currentPage.title + " did not load."
                        color: Theme.error
                        wrapMode: Text.WordWrap
                    }
                    BarText {
                        Layout.fillWidth: true
                        text: "Its file is " + root.currentPage.source
                            + " — check the path in the page list, and the log "
                            + "for what QML made of it."
                        font.pixelSize: Theme.fontSizeSm
                        color: Theme.fgMuted
                        wrapMode: Text.WordWrap
                    }
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

}
