// What the lock screen shows: a large clock, the date, a round avatar, and
// nothing else until you touch a key.
//
// The brief asks for exactly that: "große Uhr, Datum, runder Avatar, beliebige Taste".  // english-ok: the specification, quoted in the words it was given in
// The reason it works is that a lock screen is looked at far more
// often than it is used. Most of the time you want the time.
//
// ⚠️ EVERY FAILURE HAS TO BE VISIBLE. A lock screen that silently does nothing
// when PAM is misconfigured is indistinguishable from a wrong password, and you
// would sit there retyping a password that was never going to be checked. So
// the PAM state is on screen: what it asked, what went wrong, and whether it is
// busy.
import QtQuick
import QtQuick.Layouts
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Pam    // services-ok: authentication is not a device, and there is nothing sensible to wrap it in
import "../../theme"
import "../common"

Item {
    id: root

    signal unlocked()

    readonly property string user: Quickshell.env("USER") || ""

    // Nothing but the clock until a key is pressed — which is also the "press
    // any key" the brief asks for, rather than an instruction printed under a
    // password box that is already there.
    property bool asking: false

    function ask() {
        if (!root.asking) {
            root.asking = true
            pam.start()
        }
    }

    focus: true
    Keys.onPressed: function (event) {
        root.ask()
        // The first keystroke wakes the field; it must not also be swallowed,
        // or typing your password starts one character short.
        if (!event.text.length || event.key === Qt.Key_Escape)
            return
        // ⚠️ `input`, NOT `field`. There is no `field` in this file and never
        // was — the id on the TextInput is `input`. Every keystroke therefore
        // threw a ReferenceError, the character was dropped and focus never
        // moved to the box: THE LOCK SCREEN COULD NOT BE TYPED INTO AT ALL.
        //
        // Measured on the VM, which is the only way this was ever going to be
        // found: PAM started, relayed "Password: ", received four submissions
        // and refused every one, while `su buchhwin` accepted the very same
        // password (rc 0). So the whole authentication chain was correct and
        // the box was simply never filled.
        //
        // It survived because nothing builds this file: tests/smoke.sh runs the
        // SHELL, and the lock screen is a separate process
        // (`BUCHHWIN_MODE=lock`). tests/lock.sh now builds it.
        input.text += event.text
        input.forceActiveFocus()
        event.accepted = true
    }

    TapHandler { onTapped: root.ask() }

    SystemClock {
        id: clock
        // ⚠️ Minutes, not seconds. A lock screen is on for hours; a
        // second-precision clock is a redraw every second for a digit nobody
        // reads, on battery, with the lid possibly shut.
        precision: SystemClock.Minutes
    }

    ColumnLayout {
        anchors.centerIn: parent
        spacing: Theme.space5

        // ------------------------------------------------------------- clock
        BarText {
            Layout.alignment: Qt.AlignHCenter
            text: {
                function p(n) { return n < 10 ? "0" + n : "" + n }
                return p(clock.hours) + ":" + p(clock.minutes)
            }
            font.pixelSize: Theme.fontSizeDisplay
            font.weight: Theme.weightNormal
        }

        BarText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: -Theme.space4
            // Qt's own formatter, not JS. Quickshell's JS engine has no `Intl`,
            // so anything going through toLocaleDateString comes back in a
            // format nobody asked for — Qt.formatDate is Qt's, and it takes the
            // day and month names from the system locale. An explicit pattern
            // rather than a format enum, because those were renamed between Qt
            // 5 and 6 and a wrong one fails silently to an empty string.
            text: Qt.formatDate(clock.date, "dddd, d MMMM")
            color: Theme.fgMuted
            font.pixelSize: Theme.fontSizeLg
        }

        // ------------------------------------------------------------ avatar
        Item {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space5
            implicitWidth: Theme.space6 * 3
            implicitHeight: Theme.space6 * 3

            Rectangle {
                id: avatarRing
                anchors.fill: parent
                radius: width / 2
                color: Theme.surface
                border.width: Theme.hairline
                // ⚠️ `outline`, not `glassRimTop`. That token was deleted when
                // the panes lost their rim, and this was its last reader — QML
                // answered with "Unable to assign [undefined] to QColor" in the
                // lock screen's own log and drew the ring in whatever the
                // default is. A dangling token reference is invisible until
                // somebody reads a log, which for a separate process means
                // never.
                border.color: Theme.outline
            }

            // The initial, shown when there is no picture. A blank circle looks
            // like an image that failed to load.
            BarText {
                anchors.centerIn: parent
                visible: avatar.status !== Image.Ready
                text: root.user.length ? root.user.charAt(0).toUpperCase() : "?"
                font.pixelSize: Theme.fontSizeXl
                color: Theme.fgMuted
            }

            Image {
                id: avatar
                anchors.fill: parent
                anchors.margins: Theme.hairline
                fillMode: Image.PreserveAspectCrop
                // Read at the size it is drawn at, not at whatever the file
                // happens to be — a 4000 px portrait decoded for a 96 px circle
                // is megabytes of nothing.
                sourceSize.width: width
                sourceSize.height: height
                // Drawn only through the mask below, never directly: showing
                // both would put a square photo behind a round one.
                visible: false
                layer.enabled: true

                // Two places a face can live, tried in order, because neither is
                // guaranteed: AccountsService is where GNOME and SDDM put it,
                // `~/.face` is the older convention that still works everywhere.
                //
                // ⚠️ Assigned, not bound. A binding `source: candidates[i]`
                // that `onStatusChanged` advances is a property feeding itself:
                // QML logs "Binding loop detected" and from then on the order in
                // which the two are evaluated is not ours to rely on. Walking
                // the list by hand is one line longer and has one outcome.
                property int candidate: 0
                readonly property var candidates: [
                    "/var/lib/AccountsService/icons/" + root.user,
                    Quickshell.env("HOME") + "/.face"
                ]
                function tryNext() {
                    if (candidate >= candidates.length) {
                        source = ""       // out of places to look: show the initial
                        return
                    }
                    source = "file://" + candidates[candidate]
                    candidate++
                }
                Component.onCompleted: tryNext()
                onStatusChanged: if (status === Image.Error) tryNext()
            }

            // The round frame. A rectangular photo in a round hole is the single
            // most obvious way to look unfinished.
            //
            // ⚠️ `layer.enabled` is a per-item texture, which this project
            // warns about on the notch — but the warning is about a shape that
            // ANIMATES. This one is a still picture that changes when the file
            // changes, so it is rasterised once and then reused.
            Item {
                id: avatarMask
                anchors.fill: parent
                visible: false
                layer.enabled: true
                Rectangle {
                    anchors.fill: parent
                    radius: width / 2
                    color: Theme.fg          // the mask reads alpha, not hue
                }
            }

            MultiEffect {
                anchors.fill: parent
                source: avatar
                maskEnabled: true
                maskSource: avatarMask
                visible: avatar.status === Image.Ready
            }
        }

        // ------------------------------------------------------------ prompt
        BarText {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space5
            visible: !root.asking
            text: "Press any key"
            color: Theme.fgDim
        }

        GlassPane {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: Theme.space5
            visible: root.asking
            implicitWidth: Theme.space6 * 9
            implicitHeight: input.implicitHeight + Theme.space3 * 2
            radius: Theme.radiusPill
            fill: Theme.pillBg

            TextInput {
                id: input
                anchors.fill: parent
                anchors.margins: Theme.space3
                horizontalAlignment: TextInput.AlignHCenter
                verticalAlignment: TextInput.AlignVCenter
                echoMode: TextInput.Password
                enabled: !pam.active || pam.responseRequired
                color: Theme.fg
                font.family: Theme.fontUi
                font.pixelSize: Theme.fontSize
                onAccepted: root.submit()
            }
        }

        // What PAM is doing, in its own words. Its messages are the only honest
        // account of why a password was refused — "Authentication failure" and
        // "Account expired" need different reactions from you.
        BarText {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: Theme.space6 * 12
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            visible: root.status.length > 0
            text: root.status
            color: root.statusIsError ? Theme.error : Theme.fgDim
            font.pixelSize: Theme.fontSizeSm
        }
    }

    // Kept as our own state rather than read straight off PamContext: the
    // context clears its message when it finishes, and "wrong password" has to
    // survive long enough to be read.
    property string status: ""
    property bool statusIsError: false

    // Alias so the field can be reached from the key handler above without
    // knowing where it sits in the layout.
    property alias field: input

    function submit() {
        if (!pam.active) {
            root.status = "Authentication is not running"
            root.statusIsError = true
            return
        }
        if (!pam.responseRequired)
            return
        root.status = ""
        pam.respond(input.text)
        input.text = ""
    }

    PamContext {
        id: pam
        // Our own service file, placed by the installer, following the shape
        // Fedora's own `vlock` uses. Borrowing another program's service name
        // means breaking when that program is not installed.
        config: "buchhwin-lock"
        user: root.user

        onPamMessage: {
            // A prompt that wants an answer is the password question; anything
            // else is PAM talking, and worth showing rather than swallowing.
            if (!pam.responseRequired && pam.message.length > 0) {
                root.status = pam.message
                root.statusIsError = pam.messageIsError
            }
        }

        onCompleted: function (result) {
            if (result === PamResult.Success) {
                root.unlocked()
                return
            }
            root.statusIsError = true
            root.status = result === PamResult.Failed
                          ? "Wrong password" : "Authentication failed"
            // PAM is finished either way, so a second attempt needs a second
            // conversation. Without this the next Return does nothing at all
            // and the screen looks frozen.
            pam.start()
        }

        onError: function (error) {
            root.statusIsError = true
            // Naming the service, because the overwhelmingly likely cause is
            // that /etc/pam.d/buchhwin-lock is missing — and "authentication
            // error" alone sends you looking at your password instead.
            root.status = "PAM error (" + error + ") — is /etc/pam.d/buchhwin-lock installed?"
        }
    }
}
