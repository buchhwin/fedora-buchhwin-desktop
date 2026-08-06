// The pill that slides out beside the notch while the pointer is on it.
//
// The notch shows the clock and nothing else — one line has room for one
// meaning. But a running timer still has to be findable without opening the
// page it lives on, so it gets its own place: hover the notch, it slides out;
// move away, it goes.
//
// ⚠️ IT ONLY EXISTS WHEN THERE IS SOMETHING TO SAY. Nothing running means no
// surface at all, not an empty one — "leere Zustände sind ein Satz Text, kein
// leerer Kasten" (english-ok: the brief, in the words it was given in), and here
// even the sentence would be noise. The LazyLoader in Shell.qml carries that
// condition, so the window is not merely hidden: it is never created.
//
// ⚠️ NO INPUT REGION, ON PURPOSE. `mask: Region {}` leaves it click-through, so
// it can never take a click meant for a window behind it and can never take
// focus. The honest cost: moving the pointer ONTO the pill ends the hover on the
// notch and the pill goes away. It sits one gap from the notch and is read at a
// glance, so that is the right trade — but it is a trade, and the alternative
// (a grace period before it closes) is one timer away if it annoys in use.
//
// ⚠️ NOT IN THE FULLSCREEN STRIP. Hovering there already means something — it
// brings the whole notch back — and one gesture may not mean two things. That
// condition lives in ShellSurface, where `mode` is.
import QtQuick
import Quickshell
import Quickshell.Wayland
import "../../theme"
import "../../config"
import "../../services" as Services
import "../common"

PanelWindow {
    id: root

    required property var modelData
    screen: modelData

    // Its own namespace so config.kdl can give it the same corner radius and
    // shadow as everything else. ⚠️ Public interface — renaming it here without
    // renaming it in tools/niri.qml loses both, silently.
    WlrLayershell.namespace: "buchhwin-aside"
    // Above the notch for the same reason the pages are: `Top` would leave the
    // order to whichever surface happened to be created first.
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None

    // Anchored left rather than centred, because it sits beside a shape whose
    // width is a setting; centring it and nudging would compute the same number
    // twice and let the two drift.
    anchors { top: true; left: true }
    margins.left: root.screen
        ? Math.round(root.screen.width / 2
                     + Config.notch.collapsedWidth / 2 + Theme.space2)
        : 0

    exclusionMode: ExclusionMode.Ignore
    color: "transparent"                 // literal-ok: absence of colour

    // Room for the slide as well as for the pill: a Translate that runs outside
    // the window is a Translate nobody sees.
    implicitWidth: Math.max(1, pill.implicitWidth + Theme.space4)
    implicitHeight: Math.max(1, Config.notch.collapsedHeight)

    // Nothing here is clickable, so nothing here takes input.
    mask: Region {}

    // Set one tick after the window exists, so the first frame is the "before"
    // of the animation rather than its end. Without it the pill is simply there.
    property bool shown: false
    Component.onCompleted: appear.start()
    Timer { id: appear; interval: 1; onTriggered: root.shown = true }

    Pill {
        id: pill
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter

        Row {
            spacing: Theme.space2

            Icon {
                anchors.verticalCenter: parent.verticalCenter
                text: "timer"
                size: Theme.fontSize
                color: Services.Countdown.rang ? Theme.warn : Theme.accent
            }

            BarText {
                anchors.verticalCenter: parent.verticalCenter
                // Monospaced, or the pill changes width as the digits change
                // shape and the whole thing twitches once a second.
                font.family: Theme.fontMono
                text: Services.Countdown.label
                color: Services.Countdown.rang ? Theme.warn : Theme.fg
            }
        }

        // Slides out from behind the notch rather than appearing: it starts to
        // the left, where the notch is, and settles. No overshoot.
        opacity: root.shown ? 1 : 0
        transform: Translate {
            x: root.shown ? 0 : -Theme.space4
            Behavior on x {
                enabled: Theme.animate
                NumberAnimation { duration: Theme.durBase; easing.type: Theme.easing }
            }
        }

        Behavior on opacity {
            enabled: Theme.animate
            NumberAnimation { duration: Theme.durFast; easing.type: Theme.easing }
        }
    }
}
